package MT::Plugin::WOVN;
use strict;
use warnings;
use base qw( MT::Plugin );

use Plack::Middleware::WOVN::Lang;

use MT::Plugin::WOVN::Callbacks;

my $plugin = __PACKAGE__->new(
    {   id      => 'WOVN',
        name    => 'WOVN',
        version => '0.01',

        description => '<__trans phrase="Translate pages by WOVN.io.">',
        plugin_link => 'https://github.com/masiuchi/mt-plugin-wovn',

        author_name => 'Masahiro Iuchi',
        author_link => 'https://github.com/masiuchi',

        settings => MT::PluginSettings->new(
            [   [ 'user_token', +{ Default => undef,    Scope => 'system' } ],
                [ 'secret_key', +{ Default => 'secret', Scope => 'system' } ],
                [ 'url_pattern',  +{ Default => 'path', Scope => 'system' } ],
                [ 'default_lang', +{ Default => 'ja',   Scope => 'system' } ],
                [   'supported_langs',
                    +{ Default => ['ja'], Scope => 'system' }
                ],
            ]
        ),

        system_config_template => 'system_config.tmpl',

        registry => {
            callbacks => {
                init_request =>
                    '$WOVN::MT::Plugin::WOVN::Callbacks::init_request',
                build_page =>
                    '$WOVN::MT::Plugin::WOVN::Callbacks::build_callback',
                build_file =>
                    '$WOVN::MT::Plugin::WOVN::Callbacks::build_callback',
            },
        },
    }
);
MT->add_plugin($plugin);

sub load_config {
    my ( $self, $param, $scope ) = @_;
    $self->SUPER::load_config( $param, $scope );

    my %supported_langs
        = map { $_->{code} => +{ code => $_->{code}, label => $_->{en} } }
        values %$Plack::Middleware::WOVN::Lang::LANG;

    if ( $param->{supported_langs}
        && ref $param->{supported_langs} eq 'ARRAY' )
    {
        for my $lang ( @{ $param->{supported_langs} } ) {
            $supported_langs{$lang}{enabled} = 1;
        }
    }

    $param->{supported_langs} = [ sort { $a->{label} cmp $b->{label} }
            ( values %supported_langs ) ];
}

sub save_config {
    my ( $self, $param, $scope ) = @_;

    if ( $param->{supported_langs}
        && ref $param->{supported_langs} ne 'ARRAY' )
    {
        $param->{supported_langs} = [ $param->{supported_langs} ];
    }

    $self->SUPER::save_config( $param, $scope );
}

1;

