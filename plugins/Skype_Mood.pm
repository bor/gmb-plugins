# Copyright (C) 2011 Sergiy Borodych <Sergiy.Borodych@gmail.com>
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin Skype_Mood
name    Skype Mood
title   Skype Mood plugin
desc    Set skype mood message based on playing a song
req     perl(Net::DBus, libnet-dbus-perl perl-Net-DBus)
=cut

package GMB::Plugin::Skype_Mood;

use strict;
use warnings;

use Net::DBus;

our $VERSION = 0.1;

use constant { OPT => 'PLUGIN_Skype_Mood_' };

::SetDefaultOptions( OPT, msg => _ "Listen: %a - %t" );

my $dbus         = Net::DBus->find;
my $dbus_objects = $dbus->get_service("org.freedesktop.DBus")->get_object("/org/freedesktop/DBus");

# found skype instance
my $skype_found = grep $_ eq 'com.Skype.API', @{ $dbus_objects->ListNames };
die "No running DBus API-capable Skype found\n" unless $skype_found;

my $skype = $dbus->get_service('com.Skype.API')->get_object( '/com/Skype', 'com.Skype.API' );

my $handle = {};
my $old_msg;

sub Start {
    # init dbus session
    my $answer = _to_skype('NAME gmb-plugin-skype-mood');
    die 'Error communicating with Skype!' if $answer ne 'OK';
    $answer = _to_skype('PROTOCOL 7');
    die 'Skype client too old!' if $answer ne 'PROTOCOL 7';
    ::Watch( $handle, PlayingSong => \&song_changed );
    ::Watch( $handle, Playing     => \&song_stop );
}

sub Stop {
    ::UnWatch( $handle, 'PlayingSong' );
    ::UnWatch( $handle, 'Playing' );
}

sub prefbox {
    my $vbox        = Gtk2::VBox->new( ::FALSE, 2 );
    my $sg1         = Gtk2::SizeGroup->new('horizontal');
    my $replacetext = ::MakeReplaceText('talydngLfS');
    my $msg         = ::NewPrefEntry( OPT . 'msg', _ "Message:", sizeg1 => $sg1, width => 40, tip => $replacetext );
    $vbox->pack_start( $msg, ::FALSE, ::FALSE, 2 );
    return $vbox;
}

sub song_changed {
    my $ID  = $::SongID;
    my $msg = $::Options{ OPT . 'msg' };
    return unless $msg;

    unless ( defined $old_msg ) {
        # save old mood message
        $old_msg = _to_skype("GET PROFILE MOOD_TEXT") || '';
        $old_msg =~ s/^PROFILE MOOD_TEXT\s?(.*)$/$1/ if $old_msg;
    }

    my $msg_string = ::ReplaceFields( $ID, $msg );
    _to_skype("SET PROFILE MOOD_TEXT $msg_string");
}

sub song_stop {
    return if $::TogPlay;    #TogPlay is undef when Stopped, 0 when Paused, 1 when Playing
    my $ID  = $::SongID;
    my $msg = $::Options{ OPT . 'msg' };
    return unless $msg;
    _to_skype("SET PROFILE MOOD_TEXT $old_msg");
}

sub _to_skype {
    my $cmd = shift;
    warn "plugin skype_mood : send to skype '$cmd'\n" if $::debug;
    my $answer = $skype->Invoke($cmd);
    warn "plugin skype_mood : skype answer = $answer\n" if $::debug;
    return $answer || '';
}

1;

__END__

=head1 NAME

Skype Mood plugin

=head1 DESCRIPTION

Set skype mood message based on playing a song.

=head1 KNOWN ISSUES

Skype static builds don't have dbus support.

=head1 SEE ALSO

L<http://developer.skype.com/public-api-reference>

=head1 AUTHOR

Sergiy Borodych

