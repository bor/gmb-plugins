# Copyright (C) 2011 Sergiy Borodych
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin LastFM_Import
name    LastFM Import
title   LastFM Import plugin
desc    Import (sync) playcount, lastplay and rating from last.fm.
req     perl(XML::Simple)
=cut

package GMB::Plugin::LastFM_Import;

use strict;
use warnings;

use File::Spec ();
use Storable qw( store retrieve );
use XML::Simple;

use base 'Gtk2::Box';

our $VERSION = 0.1;

require $::HTTP_module;    ## no critic (Variables::ProhibitPackageVars)

my $opt_prefix = 'PLUGIN_LastFM_Import_';
my $msg_prefix = 'plugin LastFM Import :';
my %opt;

# TODO & FIXME
# convert from lastfm2gmb
die "Not ready yet!\n";

::SetDefaultOptions(
    $opt_prefix,
    api_uri      => 'http://ws.audioscrobbler.com/2.0/',
    api_key      => '4d4019927a5f30dc7d515ede3b3e7f79',
    mode         => 'a',
    rating_loved => '100',
    tmp_dir      => File::Spec->catdir( File::Spec->tmpdir(), 'gmb-lastfm-import' ),
    user         => '',
);

my $self = bless {}, __PACKAGE__;

my @jobs;
my $lastfm_library = {};
my $lastfm_plays   = 0;
my $library        = {};
my $xs;

sub Start {
}

sub Stop {
}

sub prefbox {
    my $vbox = Gtk2::VBox->new( 0, 2 );

  #my $api_uri = ::NewPrefEntry(
  #    $opt_prefix . 'api_uri' => _ 'API URI:',
  #    width                   => 50,
  #    tip                     => _ 'lastFM API request URL'
  #);
  #my $api_key = ::NewPrefEntry( $opt_prefix . 'api_key' => _ 'User API Key:', width => 50, tip => _ 'lastfm api key' );
    my $mode = ::NewPrefEntry(
        $opt_prefix . 'mode' => _ 'Import mode:',
        width                => 2,
        tip                  => _ 'Available modes: a - all, p - playcount & lastplay, l - loved'
    );
    my $rating_loved = ::NewPrefEntry(
        $opt_prefix . 'rating_loved' => _ 'Loved tracks rating:',
        width                        => 3,
        tip                          => _ 'rating for loved tracks (1..100)'
    );
    #my $tmp_dir = ::NewPrefEntry(
    #    $opt_prefix . 'tmp_dir' => _ 'Temp dir:',
    #    width                   => 50,
    #    tip                     => _ 'tmp dir for cache store, etc'
    #);
    my $user = ::NewPrefEntry( $opt_prefix . 'user' => _ 'LastFM user:', width => 50, tip => _ 'lastfm username' );

    my $button = Gtk2::Button->new( _ 'Sync now!' );
    $button->signal_connect( clicked => \&run );

    $vbox->pack_start( $_, 0, 0, 1 ) for $user, $mode, $rating_loved, $button;

    $self->{log_box} = Gtk2::ListStore->new('Glib::String');
    $vbox->add( ::LogView( $self->{log_box} ) );

    # TODO
    #$self->{progress_bar} = Gtk2::ProgressBar->new();
    #$vbox->add( $self->{progress_bar} );

    return $vbox;
}

# do main work here
sub run {
    _init_opt() or return;

    # $::Library is a SongArray object (array_ref of all song's ids)
    my $library_raw = $::Library;    ## no critic (Variables::ProhibitPackageVars)

    my %stats = ( tracks => 0, skiped => 0 );

    # convert gmb library
    to_log('Looking up library');
    foreach my $id ( @{$library_raw} ) {
        my ( $artist, $title ) = Songs::Get( $id, qw/ artist title / );
        next unless $artist or $title;
        $artist = lc($artist);
        $title  = lc($title);
        my $out = '';
        # if multiple song's with same names when skip it now # TODO
        if ( $library->{$artist}{$title} ) {
            $out .= "[$id] $artist - $title : found dup - skiped\n" if $opt{debug} >= 2;
            $library->{$artist}{$title} = { skip => 1 };
            $stats{skiped}++;
        }
        else {
            $out .= "[$id] $artist - $title : " if $opt{debug} >= 2;
            $library->{$artist}{$title}{id} = $id;
            if ( $opt{mode} =~ m/p/o ) {
                $library->{$artist}{$title}{playcount} = Songs::Get( $id, 'playcount' ) || 0;
                $library->{$artist}{$title}{lastplay}  = Songs::Get( $id, 'lastplay' )  || 0;
                $out .=
                  "playcount: $library->{$artist}{$title}{playcount} lastplay: $library->{$artist}{$title}{lastplay} "
                  if $opt{debug} >= 2;
            }
            if ( $opt{mode} =~ m/l/o ) {
                $library->{$artist}{$title}{rating} = Songs::Get( $id, 'rating' ) || 0;
                $out .= "rating: $library->{$artist}{$title}{rating}" if $opt{debug} >= 2;
            }
            $out .= "\n" if $opt{debug} >= 2;
        }
        $stats{tracks}++;
        warn "$msg_prefix $out\n" if $opt{debug} >= 2;
    }
    to_log("  found $stats{tracks} tracks ($stats{skiped} skipped as dup)");

    $xs = XML::Simple->new( ForceArray => ['track'] );

    run_mode_playcounts();
    #run_mode_loved_tracks();

    # wait for all jobs done
    while (@jobs) {
        #$_->progress();
        #$self->{progress}->set_fraction( $self->{count}{loaded} / $self->{count}{all} );
    }
    delete $self->{count};

    run_import();

    return 1;
}

# playcount & lastplay
sub run_mode_playcounts {
    if ( $opt{mode} =~ m/p/ ) {
        to_log("Request 'WeeklyChartList'");
        my $http_obj = _lastfm_request( \&_process_charts, { method => 'user.getWeeklyChartList' } );
    }
    return 1;
}

# loved tracks (rating)
sub run_mode_loved_tracks {
    if ( $opt{mode} =~ m/l/ ) {
        # TODO
    }
    return 1;
}

# import info to gmb
sub run_import {
    my %stats = ( imported_playcount => 0, imported_lastplay => 0, imported_loved => 0 );

    # wait for all jobs done
    #while ( ) {}

    to_log('Import to gmb');
    foreach my $artist ( sort keys %{$lastfm_library} ) {
        warn "$artist\n" if $opt{debug} >= 2;
        foreach my $title ( keys %{ $lastfm_library->{$artist} } ) {
            my $e;
            warn " $title - $lastfm_library->{$artist}{$title}{playcount} <=> $library->{$artist}{$title}{playcount}\n"
              if $opt{debug} >= 2;
            # playcount    # wait for all jobs done
            #while ( ) {}

            if (    $lastfm_library->{$artist}{$title}{playcount}
                and $lastfm_library->{$artist}{$title}{playcount} > $library->{$artist}{$title}{playcount} )
            {
                to_log( "$artist - $title : playcount : "
                      . "$library->{$artist}{$title}{playcount} -> $lastfm_library->{$artist}{$title}{playcount}" );
                #$gmb_obj->Set(
                #    [ $library->{$artist}{$title}{id}, 'playcount', $lastfm_library->{$artist}{$title}{playcount} ]
                #) or $e++ and warn " error setting 'playcount' for track ID $library->{$artist}{$title}{id}\n";
                $e ? $stats{errors}++ : $stats{imported_playcount}++;
            }
            # lastplay
            if (    $lastfm_library->{$artist}{$title}{lastplay}
                and $lastfm_library->{$artist}{$title}{lastplay} > $library->{$artist}{$title}{lastplay} )
            {
                to_log( "$artist - $title : lastplay : "
                      . "$library->{$artist}{$title}{lastplay} -> $lastfm_library->{$artist}{$title}{lastplay}" );
                #$gmb_obj->Set(
                #    [ $library->{$artist}{$title}{id}, 'lastplay', $lastfm_library->{$artist}{$title}{lastplay} ] )
                #  or $e++ and warn " error setting 'lastplay' for track ID $library->{$artist}{$title}{id}\n";
                $e ? $stats{errors}++ : $stats{imported_lastplay}++;
            }
            # loved
            if (    $lastfm_library->{$artist}{$title}{rating}
                and $lastfm_library->{$artist}{$title}{rating} > $library->{$artist}{$title}{rating} )
            {    # wait for all jobs done
                    #while ( ) {}

                to_log("$artist - $title : loved : rating -> $lastfm_library->{$artist}{$title}{rating}");
                #$gmb_obj->Set(
                #    [ $library->{$artist}{$title}{id}, 'rating', $lastfm_library->{$artist}{$title}{rating} ] )
                #  or $e++ and warn " error setting 'rating' for track ID $library->{$artist}{$title}{id}\n";
                $e ? $stats{errors}++ : $stats{imported_loved}++;
            }
        }
    }

    to_log( 'Imported : '
          . "playcount - $stats{imported_playcount}, lastplay - $stats{imported_lastplay}, loved - $stats{imported_loved}. "
          . ( $stats{errors} ? $stats{errors} : 'No' )
          . " errors detected." );

    undef $lastfm_library;
    undef $lastfm_plays;
    undef $library;

    return 1;
}

# get plugin option
sub option {
    return $::Options{ $opt_prefix . shift };    ## no critic (Variables::ProhibitPackageVars)
}

# sent message to log_box
sub to_log {
    my $msg = shift;
    $self->{log_box}->set( $self->{log_box}->append(), 0, $msg );
    #warn "$msg_prefix $msg\n" if $::debug;
    if ( my $iter = $self->{log_box}->iter_nth_child( undef, 50 ) ) {
        $self->{log_box}->remove($iter);
    }

    return 1;
}

sub _error {
    my $msg = shift;
    warn "ERR: $msg_prefix $msg\n";
    to_log( 'ERROR: ' . $msg );
    return;
}

sub _init_opt {
    %opt = map { $_ => option($_) } qw( api_key api_uri cache mode rating_loved tmp_dir user );

    # FIXME remove stub
    $opt{debug} = 1 || $::debug;    ## no critic (Variables::ProhibitPackageVars)
    $opt{quiet} = 0;
    $opt{cache} = 1;

    $opt{mode} = 'pl' if $opt{mode} eq 'a';
    $opt{rating_loved} ||= 100;
    $opt{tmp_dir} ||= File::Spec->catdir( File::Spec->tmpdir(), 'gmb-lastfm-import' );
    $opt{user} or return _error('Need username!');

    if ( $opt{cache} and not -d $opt{tmp_dir} ) {
        mkdir( $opt{tmp_dir} ) or return _error("Can't create tmp dir $opt{tmp_dir}: $!");
    }
    return _error("Unknown mode '$opt{mode}' !") unless $opt{mode} =~ /[pl]/;

    return 1;
}

# lastfm request
# params: $callback, $additional_params
# return: Simple_http object
sub _lastfm_request {
    my ( $cb, $params ) = @_;

    my $url = "$opt{api_uri}?api_key=$opt{api_key}&user=$opt{user}";
    if ($params) {
        $url .= '&' . join( '&', map { "$_=$params->{$_}" } keys %{$params} );
    }

    # pre-process xml -> hashref
    my $cb_wrap = sub {
        # @_ = data, type, url
        my $xml  = shift;
        my $data = $xs->XMLin($xml);
        $cb->( $data, @_ );
    };

    return Simple_http::get_with_cb( cb => $cb_wrap, url => $url );
}

# get weekly track chart list
sub _lastfm_get_weeklytrackchart {
    my ( $cb, $params ) = @_;
    my $filename =
      File::Spec->catfile( $opt{tmp_dir}, "WeeklyTrackChart-$opt{user}-$params->{from}-$params->{to}.data" );
    if ( $opt{cache} and -e $filename ) {
        my $data = retrieve($filename);
        $cb->($data);
    }
    else {
        my $cb_wrap = sub {
            # @_ = data, type, url
            my $data = shift;
            # TODO : strip some data, for left only need info like: artist, name, playcount
            store( $data, $filename ) if $opt{cache};
            $cb->( $data, @_ );
        };

        my $http_obj = _lastfm_request( $cb_wrap, { method => 'user.getWeeklyTrackChart', %{$params} } );
    }
    return 1;
}

sub _process_charts {
    my $charts = shift;

    # add current (last) week to chart list
    my $last_week_from = $charts->{weeklychartlist}{chart}[ $#{ $charts->{weeklychartlist}{chart} } ]{to};
    my $last_week_to   = time() - 1;
    push @{ $charts->{weeklychartlist}{chart} }, { from => $last_week_from, to => $last_week_to }
      if $last_week_from < $last_week_to;
    to_log( "  found " . scalar( @{ $charts->{weeklychartlist}{chart} } ) . " pages" );

    # get weekly track charts
    to_log("LastFM request 'WeeklyTrackChart' pages");
    my $out = '';
    foreach my $date ( @{ $charts->{weeklychartlist}{chart} } ) {
        $out .= "$date->{from}-$date->{to}.." if $opt{debug};
        _lastfm_get_weeklytrackchart( \&_process_playcounts, { from => $date->{from}, to => $date->{to} } );
    }
    warn "$msg_prefix $out\n" if $opt{debug};
    to_log("  total $lastfm_plays plays");

    # clean 'last week' pages workaround
    unlink( glob( File::Spec->catfile( $opt{tmp_dir}, "WeeklyTrackChart-$opt{user}-$last_week_from-*" ) ) )
      if $opt{debug} <= 2;

    return 1;
}

sub _process_playcounts {
    my ( $data, $params ) = @_;

    foreach my $title ( keys %{ $data->{weeklytrackchart}{track} } ) {
        my $artist = $data->{weeklytrackchart}{track}{$title}{artist}{name}
          || $data->{weeklytrackchart}{track}{$title}{artist}{content};
        $artist = lc($artist);
        my $playcount = $data->{weeklytrackchart}{track}{$title}{playcount};
        $title = lc($title);
        warn "$artist - $title - $playcount\n" if $opt{debug} >= 2;
        if ( $library->{$artist}{$title} and $library->{$artist}{$title}{id} ) {
            $lastfm_library->{$artist}{$title}{playcount} += $playcount;
            $lastfm_library->{$artist}{$title}{lastplay} = $params->{from}
              if ( not $lastfm_library->{$artist}{$title}{lastplay}
                or $lastfm_library->{$artist}{$title}{lastplay} < $params->{from} );
        }
        $lastfm_plays += $playcount;
    }
    return 1;
}

1;

__END__

=head1 NAME

LastFM Import plugin

=head1 DESCRIPTION

Import (sync) playcount, lastplay and rating from last.fm.

=head1 SEE ALSO

L<https://github.com/bor/lastfm2gmb>

=head1 AUTHOR

Sergiy Borodych

