package MT::Session::Listing;
use strict;
use warnings;

sub list_props {
    +{  id   => { base => '__virtual.id', display => 'none', },
        data => {
            base    => '__virtual.string',
            label   => 'Username',
            display => 'force',
            raw     => sub {
                my ( $props, $obj ) = @_;
                my $author
                    = MT->model('author')->load( $obj->get('author_id') );
                return $author ? $author->name : '(none)';
            },
            order => 100,
        },
        start => {
            label   => 'Login Date',
            display => 'force',
            order   => 200,
            raw     => sub {
                my ( $prop, $obj ) = @_;
                require MT::Util;
                my $ts = MT::Util::epoch2ts( undef, $obj->start,
                    MT->config->DefaultTimezone );
                require MT::App::CMS;
                MT::Util::format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT,
                    $ts, undef, MT->app->user->preferred_language );
            },
        },
    };
}

sub list_screens {
    +{  screen_label        => 'Manage User Sessions',
        object_label        => 'User Session',
        object_label_plural => 'User Sessions',
        default_sort_key    => 'start',
        default_sort_order  => 'descend',
    };
}

sub list_actions {
    +{  delete => {
            label                   => 'Delete',
            order                   => 100,
            continue_prompt_handler => sub {
                MT->component('UserSessionManager')
                    ->translate(
                    'Are you sure you want to delete the selected user sessions?'
                    );
            },
            code => sub {
                my $app = shift;
                my @ids = $app->param('id');
                MT->model('session')->remove( { kind => 'US', id => \@ids } );

                $app->add_return_arg( saved_deleted => 1 );
                $app->call_return;
            },
            button     => 1,
            js_message => 'delete',
        },
    };
}

sub filter_list {
    my ( $cb, $app, $filter, $load_options, $cols ) = @_;
    my $terms = $load_options->{terms} ||= {};

    $terms->{kind} = 'US';

    my $user = $app->user;
    if ( !$user->is_superuser ) {
        my @ids = map { $_->id }
            grep { $_->get('author_id') == $user->id }
            MT->model('session')->load($terms);
        $terms->{id} = \@ids if @ids;
    }
}

sub filter_param {
    my ( $cb, $app, $res, $objs ) = @_;

    my $cookies = $app->cookies;
    my $cookie  = $cookies->{ $app->user_cookie }->value;
    require Encode;
    $cookie = Encode::decode( $app->charset, $cookie )
        unless Encode::is_utf8($cookie);
    my ( $user, $session_id, $remember ) = split /::/, $cookie;

    for my $obj ( @{ $res->{objects} } ) {
        if ( $obj->[0] eq $session_id ) {
            $obj->[0] = undef;
            $res->{editable_count}--;
            last;
        }
    }
}

1;

