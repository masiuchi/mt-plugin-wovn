package MT::Plugin::WOVN::Callbacks;
use strict;
use warnings;

use MT;

use File::Basename;
use Mojo::URL;
use Plack::Middleware::WOVN;
use Plack::Middleware::WOVN::Headers;
use Plack::Middleware::WOVN::Store;

sub init_request {
    $Plack::Middleware::WOVN::STORE = undef;
}

sub build_callback {
    my ( $cb, %params ) = @_;

    if ( lc $params{file_info}->url !~ /\.html?$/ ) {
        return;
    }

    my $plugin = MT->component('WOVN');
    unless ( $plugin && $plugin->get_config_value('user_token') ) {
        return;
    }

    $Plack::Middleware::WOVN::STORE ||= Plack::Middleware::WOVN::Store->new(
        {   settings => {
                user_token   => $plugin->get_config_value('user_token'),
                secret_key   => $plugin->get_config_value('secret_key'),
                url_pattern  => $plugin->get_config_value('url_pattern'),
                default_lang => $plugin->get_config_value('default_lang'),
                supported_langs =>
                    $plugin->get_config_value('supported_langs'),
            }
        }
    );

    my $blog_site_url = Mojo::URL->new( $params{blog}->site_url );
    my $page_url
        = Mojo::URL->new(
        $blog_site_url->host_port . $params{file_info}->url );

    my $headers
        = Plack::Middleware::WOVN::Headers->new( {},
        $Plack::Middleware::WOVN::STORE->settings );
    $headers->host( $page_url->host );
    $headers->protocol( $page_url->protocol );
    $headers->pathname( $page_url->path );
    $headers->url( $page_url->to_string );
    $headers->env->{REQUEST_URI} = $page_url->to_string;

    my $original_html = ${ $params{content} };

    my $values
        = ( MT->request('wovn_cache') || {} )->{ $page_url->to_string };
    if ( !$values || ( ref $values eq 'HASH' && $values->{expired} ) ) {
        for ( 1 .. 2 ) {
            $values = $Plack::Middleware::WOVN::STORE->get_values(
                $page_url->to_string );
            if ( $values && ref $values eq 'HASH' && !$values->{expired} ) {
                last;
            }
        }

        my $wovn_cache = MT->request('wovn_cache') || {};
        $wovn_cache->{ $page_url->to_string } = $values;
        MT->request( 'wovn_cache', $wovn_cache );
    }

    my @langs;
    if ( $cb->method eq 'build_page' ) {
        @langs = ( $plugin->get_config_value('default_lang') );
    }
    elsif ( $cb->method eq 'build_file' ) {
        @langs = @{ $plugin->get_config_value('supported_langs') || [] };
        @langs
            = grep { $_ ne $plugin->get_config_value('default_lang') } @langs;
    }

    for my $lang (@langs) {

        my $url = +{
            protocol => $headers->protocol,
            host     => $headers->host,
            pathname => $headers->pathname,
        };
        my $translated_html
            = Plack::Middleware::WOVN::switch_lang( $original_html, $values,
            $url, $lang, $headers );

        if ( $cb->method eq 'build_page' ) {
            ${ $params{content} } = $translated_html;
        }
        elsif ( $cb->method eq 'build_file' ) {

            my $translated_page_path = $params{file_info}->file_path;

            # host + language_code
            my $file_info_url = $params{file_info}->url;
            $translated_page_path =~ s/($file_info_url)/\/$lang$1/;

#            # site_path + langeuage_code
#            my $site_archive_path    = $params{blog}->archive_path;
#            unless ( $translated_page_path =~ s/($site_archive_path)/$1\/$lang/ )
#            {
#                my $site_path = $params{blog}->site_path;
#                $translated_page_path =~ s/($site_path)/$1\/$lang/;
#            }

            my $fmgr     = $params{blog}->file_mgr;
            my $page_dir = File::Basename::dirname($translated_page_path);
            if ( !$fmgr->exists($page_dir) ) {
                $fmgr->mkpath($page_dir) or die $fmgr->errstr;
            }
            $fmgr->put_data( $translated_html, $translated_page_path )
                or die $fmgr->errstr;

        }
    }
}

1;

