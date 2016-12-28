package Post2Facebook::L10N::ja;
use strict;
use base 'Post2Facebook::L10N';
use vars qw( %Lexicon );

our %Lexicon = (
    'Post entry to Facebook.' => 'ブログ記事/ウェブページをFacebookへポストします。',
    'An error occurred while trying to post to Facebook : ([_1])[_2]' => 'Facebookへの投稿中にエラーが発生しました : ([_1])[_2]',
    'Post entry to Facebook' => 'ブログ記事をウォールへポストする',
    'Post page to Facebook' => 'ウェブページをウォールへポストする',
    'App Secret' => 'アプリの秘訣',
    'Access Taken' => 'アクセストークン',
    'Get Access Taken' => 'アクセストークンの取得',
    'Time which acquired the Token' => 'トークンの取得時刻',
    'Template for Title' => '投稿タイトル',
    'Template for Message' => 'メッセージ',
    'Template for Caption' => 'キャプション',
    'Template for Description' => 'ディスクリプション',
    'Template for Picture' => 'ピクチャ',
    'Template for Milestones' => '大切な出来事',
    'Post entry to Facebook Page' => 'ブログ記事をFacebookページへポストする',
    'Post page to Facebook Page' => 'ウェブページをFacebookページへポストする',
    'Facebook Page Name' => 'Facebookページ名',
    'Comma-delimited text' => 'カンマ区切り',
    'Expiration date of the access token of Facebook has expired.' => 'Facebookアプリケーションのアクセス・トークンが有効期限を過ぎています。',
    'Expiration date of the access token of Facebook is remaining within a week.' => 'Facebookアプリケーションのアクセス・トークンが1週間以内に無効になります。',
    'Get Facebook Access Taken' => 'Facebookのアクセス・トークンを取得',
    'Get Access Taken' => 'アクセス・トークンを取得',
    'Entry CustomField\'s basename' => 'ブログ記事投稿判別用カスタムフィールドのbasename',
    'Page CustomField\'s basename' => 'ウェブページ投稿判別用カスタムフィールドのbasename',
    'Post to Facebook Page\'s Milestones' => 'Facebookページの「大切な出来事」に投稿する',
);

1;