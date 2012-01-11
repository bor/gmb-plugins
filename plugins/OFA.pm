# Copyright (C) 2011 Sergiy Borodych
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin OFA
name	OFA
title	OFA plugin
desc	Retrieves metadata for unknown audio files
req     perl(Audio::Ofa::Util)
=cut

package GMB::Plugin::OFA;

use strict;
use warnings;

#use Audio::Ofa::Util;
use File::Spec ();
use Glib qw( TRUE FALSE );

our $VERSION = 0.1;

my $opt_prefix = 'PLUGIN_OFA_';

require $::HTTP_module;    ## no critic (Variables::ProhibitPackageVars)

# TODO
die "Not ready yet!\n";

my $song_menu_entry = {
    label   => _ 'Retrieve info for this song',
    code    => \&show_info,
    onlyone => 'IDs',
};

my $widget = {
    class        => __PACKAGE__,
    tabtitle     => _ 'OFA',
    group        => 'Play',
    autoadd_type => 'context page',
};

sub Start {
    update_menu(1);
    #Layout::RegisterWidget( Plugin_OFA => $widget );
    return 1;
}

sub Stop {
    update_menu(0);
    #Layout::RegisterWidget( Plugin_OFA => undef );
    return 1;
}

sub prefbox {
    my $vbox = Gtk2::VBox->new( FALSE, 2 );
    my $check =
      ::NewPrefCheckButton( $opt_prefix . 'song_menu_entry', _ 'Add entry to Song Menu', cb => \&update_menu );
    $vbox->pack_start( $check, FALSE, FALSE, 2 );
    return $vbox;
}

# get plugin option
sub option {
    return $::Options{ $opt_prefix . shift };    ## no critic (Variables::ProhibitPackageVars)
}

sub get_info {
    my $path = shift;
    my $info = {};
    my $util = Audio::Ofa::Util->new( filename => $path );
    $util->musicdns_lookup() or die $util->error;
    warn Data::Dumper::Dumper($util);
    foreach (qw( artist title album )) {
        $info->{$_} = $util->$_;
    }
    require Data::Dumper;
    warn Data::Dumper::Dumper($info);
    return $info;
}

# save song info (artist/title/etc) to file
sub save_to_file {
    my ( $id, $info ) = @_;
    Songs::Set( $id, $info );
    return 1;
}

sub show_info {
    my $obj       = shift;
    my $song_id   = $obj->{IDs}[0];
    my $song_path = File::Spec->catfile( Songs::Get( $song_id, 'path', 'file' ) );

    my $info = get_info($song_path);

    my $dialog = Gtk2::Dialog->new( _ 'Song Info provided by OFA', undef, [] );
    $dialog->set_border_width(4);
    my $table = Gtk2::Table->new( 3, 2 );

    my $row = 0;
    foreach (qw( artist title album )) {
        my $label = Gtk2::Label->new( Songs::FieldName($_) );
        my $entry = Gtk2::Entry->new();
        $entry->set_text( $info->{$_} ) if $info->{$_};
        $entry->set_editable(FALSE);
        $table->attach_defaults( $label, 0, 1, $row, $row + 1 );
        $table->attach_defaults( $entry, 1, 2, $row, $row + 1 );
        $row++;
    }

    my $button = Gtk2::Button->new('Save to file(tag)');
    $button->signal_connect( clicked => sub { save_to_file( $song_id, $info ) } );

    $dialog->vbox->pack_start( $_, FALSE, FALSE, 2 ) foreach $table, $button;
    ::SetWSize( $dialog, 'SongInfo_by_OFA' );
    $dialog->show_all();

    return $dialog;
}

sub update_menu {
    my $state = shift;

    my $song_menu = \@::SongCMenu;    ## no critic (Variables::ProhibitPackageVars)
    if ( $state and option('song_menu_entry') ) {
        push @$song_menu, $song_menu_entry unless ( grep { $_ == $song_menu_entry } @$song_menu );
    }
    else {
        @$song_menu = grep { $_ != $song_menu_entry } @$song_menu;
    }
    return 1;
}

1;

__END__

=head1 NAME

OFA plugin

=head1 DESCRIPTION

Retrieves metadata for unknown audio files.

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Acoustic_fingerprint>,
L<https://metacpan.org/module/Audio::Ofa>,
L<https://metacpan.org/module/Audio::Ofa::Util>

=head1 AUTHOR

Sergiy Borodych

