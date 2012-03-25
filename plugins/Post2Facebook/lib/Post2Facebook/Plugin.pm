package Post2Facebook::Plugin;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON qw/decode_json/;
use MT::Util qw( encode_url );

sub _get_facebook_oauth_access_token {
    my $app = shift;
    my $plugin = MT->component( 'Post2Facebook' );
    my $blog = $app->blog;
    return $app->trans_error( 'Permission denied.' ) unless $blog;
    my $user = $app->user;
    my $perms = __is_user_can( $blog, $user, 'administer_' . $blog->class );
    return $app->trans_error( 'Permission denied.' ) unless $perms;
    if ( my $set_plugin_data = $app->param( 'set_plugin_data' ) ) {
        if ( my $access_token = $app->param( 'access_token' ) ) {
            $plugin->set_config_value( 'FacebookPostAppToken', $access_token, 'blog:'. $blog->id );
            $plugin->set_config_value( 'FacebookGetAppToken', time, 'blog:'. $blog->id );
        }
    }
    my %param;
    $param{ error } = $app->param( 'error' ) ? 1 : 0;
    $app->{ plugin_template_path } = File::Spec->catdir( $plugin->path, 'tmpl' );
    my $tmpl = 'get_token.tmpl';
    return $app->build_page( $tmpl, \%param );
}

sub _cb_tp_param_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $blog_id = $app->blog->id;
    my $blog = $app->blog;
    my $user = $app->user;
    my $perms = __is_user_can( $blog, $user, 'administer_' . $blog->class );
    return unless $perms;
    my $plugin = MT->component( 'Post2Facebook' );
    my $post_page = $plugin->get_config_value( 'FacebookPostPage', 'blog:' . $blog_id );
    my $post_entry = $plugin->get_config_value( 'FacebookPostEntry', 'blog:' . $blog_id );
    my $post_entry4page = $plugin->get_config_value( 'FacebookPostEntry4Page', 'blog:' . $blog_id );
    my $post_page4page = $plugin->get_config_value( 'FacebookPostPage4Page', 'blog:' . $blog_id );
    my $class = $app->param( '_type' );
    if ( ( $class eq 'entry' ) && ( (! $post_entry ) && (! $post_entry4page ) ) ) {
        return 1;
    }
    if ( ( $class eq 'page' ) && ( (! $post_page ) && (! $post_page4page ) ) ) {
        return 1;
    }
    my $get_token = $plugin->get_config_value( 'FacebookGetAppToken', 'blog:' . $blog_id );
    my $experies = 53 * 60 * 60 * 24;
    my $error = $param->{ error };
    my $message;
    if ( ( time - $get_token ) > $experies ) {
        my $limit = 60 * 60 * 60 * 24;
        if ( ( time - $get_token ) > $limit ) {
            $message = $plugin->translate( 'Expiration date of the access token of Facebook has expired.' );
        } else {
            $message = $plugin->translate( 'Expiration date of the access token of Facebook is remaining within a week.' );
        }
    }
    # $message = $plugin->translate( 'Expiration date of the access token of Facebook has expired.' );
    if ( $message ) {
        my $apl_id = $plugin->get_config_value( 'FacebookPostAppID', 'blog:' . $blog_id );
        my $secret = $plugin->get_config_value( 'FacebookPostAppSecret', 'blog:' . $blog_id );
        my $redirect_uri = MT->config( 'CGIPath' ) . MT->config( 'AdminScript' ) . '?__mode=get_facebook_oauth_access_token&edit_entry=1&blog_id=' . $blog_id;
        if ( $error ) {
            $redirect_uri .= '&status_msg=facebook-error';
        } else {
            $redirect_uri .= '&status_msg=generic-error';
        }
        my $api = 'https://www.facebook.com/dialog/oauth?client_id=' . encode_url( $apl_id ) . '&redirect_uri=' . encode_url( $redirect_uri );
        $api .= '&state=' . encode_url( $secret ) . '&scope=publish_stream%2Coffline_access%2Cmanage_pages&response_type=token&display=popup';
        my $label = $plugin->translate( 'Get Facebook Access Taken' );
        my $api_link = '<a target="_blank" href="<mt:var name="__get_access_token_link__">">' . $label . '</a>';
        $param->{ __get_access_token_link__ } = $api;
        my $link_msg = $tmpl->createElement( 'for', { id => 'facebook-api-link', class => 'error',  } );
        $link_msg->innerHTML( '<div class="msg msg-error" id="facebook-api-link"><p class="msg-text">' . $api_link . '</p></div>' );
        if ( $error ) {
            my $pointer = $tmpl->getElementById( 'generic-error' );
            my $statusmsg = $tmpl->createElement( 'app:statusmsg', { id => 'facebook-error', class => 'error',  } );
            $statusmsg->innerHTML( $message );
            $tmpl->insertAfter( $statusmsg, $pointer );
            $statusmsg->innerHTML( $message );
            $tmpl->insertAfter( $statusmsg, $pointer );
            $tmpl->insertAfter( $link_msg, $statusmsg );
        } else {
            $param->{ error } = $message;
            my $pointer = $tmpl->getElementById( 'generic-error' );
            $tmpl->insertAfter( $link_msg, $pointer );
        }
    }
}

sub _cb_scheduled_post_published {
    my ( $cb, $app, $obj ) = @_;
    return _post2facebook( $cb, $app, $obj );
}

sub _post2facebook {
    my ( $cb, $app, $obj, $original ) = @_;
    return 1 unless $obj->status == MT::Entry::RELEASE();
    my $plugin = MT->component( 'Post2Facebook' );
    my $blog_id = $obj->blog_id;
    my $entry_cf = $plugin->get_config_value( 'FacebookPostEntryCustomField', 'blog:' . $blog_id );
    my $class = $obj->class;
    if ( $class eq 'page' ) {
        $entry_cf = $plugin->get_config_value( 'FacebookPostEntryCustomField', 'blog:' . $blog_id );
    }
    if (! $entry_cf ) {
        return 1 if $original && $original->status == MT::Entry::RELEASE();
    } else {
        $entry_cf = 'field.' . $entry_cf;
        if (! $obj->$entry_cf ) {
            return 1;
        }
    }
    my $access_token = $plugin->get_config_value( 'FacebookPostAppToken', 'blog:' . $blog_id );
    my $post_page = $plugin->get_config_value( 'FacebookPostPage', 'blog:' . $blog_id );
    my $post_entry = $plugin->get_config_value( 'FacebookPostEntry', 'blog:' . $blog_id );
    my $post_entry4page = $plugin->get_config_value( 'FacebookPostEntry4Page', 'blog:' . $blog_id );
    my $post_page4page = $plugin->get_config_value( 'FacebookPostPage4Page', 'blog:' . $blog_id );
    my $post_entry4page = $plugin->get_config_value( 'FacebookPostEntry4Page', 'blog:' . $blog_id );
    my $page_name = $plugin->get_config_value( 'FacebookPostPageName', 'blog:' . $blog_id );
    my $name = $plugin->get_config_value( 'FacebookPostTemplate', 'blog:' . $blog_id );
    my $message = $plugin->get_config_value( 'FacebookPostMessageTemplate', 'blog:' . $blog_id );
    my $caption = $plugin->get_config_value( 'FacebookPostCaptionTemplate', 'blog:' . $blog_id );
    my $description = $plugin->get_config_value( 'FacebookPostDescriptionTemplate', 'blog:' . $blog_id );
    my $picture = $plugin->get_config_value( 'FacebookPostPictureTemplate', 'blog:' . $blog_id );
    if ( ( $class eq 'entry' ) && ( (! $post_entry ) && (! $post_entry4page ) ) ) {
        return 1;
    }
    if ( ( $class eq 'page' ) && ( (! $post_page ) && (! $post_page4page ) ) ) {
        return 1;
    }
    if ( $post_entry || $post_page ) {
        my $name = __build_entry( $obj, $name, 'wall' );
        if ( $name ) {
            my $message = __build_entry( $obj, $message, 'wall' );
            my $caption = __build_entry( $obj, $caption, 'wall' );
            my $description = __build_entry( $obj, $description, 'wall' );
            my $picture = __build_entry( $obj, $picture, 'wall' );
            my %params = (
                name => $name,
                'link' => $obj->permalink,
                access_token => $access_token,
            );
            $params{ message } = $message if ( $message );
            $params{ caption } = $caption if ( $caption );
            $params{ description } = $description if ( $description );
            $params{ picture } = $picture if ( $picture );
            my $req = POST( 'https://graph.facebook.com/me/feed', [ %params ] );
            my $ua = LWP::UserAgent->new;
            my $res = $ua->request( $req );
            if ( $res->{ _content } =~ /error/ ) {
                $app->log( {
                    message => $plugin->translate( 
                        'An error occurred while trying to post to Facebook : ([_1])[_2]', $res->{ error }->{ type }, $res->{ error }->{ message } ),
                    blog_id => $obj->blog_id,
                    author_id => $app->user->id,
                    class => 'post2facebook',
                    level => MT::Log::ERROR(),
                } );
            }
        }
    }
    if ( ( $post_entry4page || $post_page4page ) && $page_name ) {
        if ( ( $class eq 'entry' ) && (! $post_entry4page ) ) {
            return 1;
        }
        if ( ( $class eq 'page' ) && (! $post_page4page ) ) {
            return 1;
        }
        my @page_names = split( /,/, $page_name );
        my $api = 'https://graph.facebook.com/me/accounts?access_token=' . $access_token;
        my $ua = LWP::UserAgent->new;
        my $req = HTTP::Request->new( GET => $api );
        my $res = $ua->request( $req );
        my $json = $res->{ _content };
        $json = decode_json( $json );
        my $pages = $json->{ data };
        for my $page ( @$pages ) {
            my $page_title = $page->{ name };
            if ( grep( /^$page_title$/, @page_names ) ) {
                my $access_token = $page->{ access_token };
                my $page_id = $page->{ id };
                my $name = __build_entry( $obj, $name, 'page', $page_title );
                next unless $name;
                my $message = __build_entry( $obj, $message, 'page', $page_title );
                my $caption = __build_entry( $obj, $caption, 'page', $page_title );
                my $description = __build_entry( $obj, $description, 'page', $page_title );
                my $picture = __build_entry( $obj, $picture, 'page', $page_title );
                my %params = (
                    name => $name,
                    'link' => $obj->permalink,
                    access_token => $access_token,
                );
                $params{ message } = $message if ( $message );
                $params{ caption } = $caption if ( $caption );
                $params{ description } = $description if ( $description );
                $params{ picture } = $picture if ( $picture );
                my $req = POST( 'https://graph.facebook.com/' . $page_id . '/feed', [ %params ] );
                my $ua = LWP::UserAgent->new;
                my $res = $ua->request( $req );
                if ( $res->{ _content } =~ /error/ ) {
                    $app->log( {
                        message => $plugin->translate( 
                            'An error occurred while trying to post to Facebook : ([_1])[_2]', $res->{ error }->{ type }, $res->{ error }->{ message } ),
                        blog_id => $obj->blog_id,
                        author_id => $app->user->id,
                        class => 'post2facebook',
                        level => MT::Log::ERROR(),
                    } );
                }
            }
        }
    }
    if ( $entry_cf ) {
        $obj->$entry_cf( undef );
        $obj->save or die $obj->errstr;
    }
    return 1;
}

sub __build_entry {
    my ( $obj, $text, $scope, $page_title ) = @_;
    require MT::Template;
    require MT::Template::Context;
    my $tmpl = MT::Template->new;
    $tmpl->name( 'Post2Facebook' );
    $tmpl->text( $text );
    $tmpl->blog_id( $obj->blog_id );
    my $ctx = MT::Template::Context->new;
    $ctx->stash( 'blog', $obj->blog );
    $ctx->stash( 'blog_id', $obj->blog_id );
    $ctx->stash( 'local_blog_id', $obj->blog_id );
    $ctx->stash( 'entry', $obj );
    $ctx->stash( 'category', $obj->category );
    $ctx->stash( 'author', $obj->author );
    $ctx->{ __stash }->{ vars }->{ __facebook_scope__ } = $scope;
    $ctx->{ __stash }->{ vars }->{ __facebook_page_title__ } = $page_title;
    my $res = $tmpl->build( $ctx );
    return $res;
}

sub __is_user_can {
    my ( $blog, $user, $permission ) = @_;
    return unless $user;
    unless ( $permission =~ /^can_/ ) {
        $permission = 'can_' . $permission;
    }
    my $perm = $user->is_superuser;
    unless ( $perm ) {
        if ( $blog ) {
            my $admin = 'can_administer_blog';
            $perm = $user->permissions( $blog->id )->$admin;
            $perm = $user->permissions( $blog->id )->$permission unless $perm;
        } else {
            $perm = $user->permissions()->$permission;
        }
    }
    return $perm;
}

1;