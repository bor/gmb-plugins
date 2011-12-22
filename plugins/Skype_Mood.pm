# Copyright (C) 2011 Sergiy Borodych
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

our $VERSION = 0.2;

use constant { OPT => 'PLUGIN_Skype_Mood_' };

::SetDefaultOptions( OPT, msg => _ "Listen: %a - %t" );

my $handle = {};
my $old_msg;
my $skype;
#my $sigid;

## no critic (Variables::ProhibitPackageVars)

sub Start {

    # try init session here first
    $skype = _get_skype(1);
    #$sigid = $skype->connect_to_signal( 'NameOwnerChanged', sub { $skype = _init_skype(); } ) if $skype;

    ::Watch( $handle, PlayingSong => \&song_changed );
    ::Watch( $handle, Playing     => \&song_stop );

    # run at start
    song_changed() if $::TogPlay;

    return 1;
}

sub Stop {
    return unless $skype;

    ::UnWatch( $handle, 'PlayingSong' );
    ::UnWatch( $handle, 'Playing' );

    _to_skype("SET PROFILE MOOD_TEXT $old_msg") if defined $old_msg;
    #$skype->disconnect_from_signal( 'NameOwnerChanged', $sigid ) if $sigid;
    undef $skype;
    return 1;
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
        # clear old our message
        $old_msg = '' if $old_msg =~ /^Listen: /;
    }

    my $msg_string = ::ReplaceFields( $ID, $msg );
    return _to_skype("SET PROFILE MOOD_TEXT $msg_string");
}

sub song_stop {
    return if $::TogPlay;    #TogPlay is undef when Stopped, 0 when Paused, 1 when Playing
    my $ID  = $::SongID;
    my $msg = $::Options{ OPT . 'msg' };
    return unless $msg;
    return _to_skype("SET PROFILE MOOD_TEXT $old_msg");
}

sub _error {
    my $msg = shift;
    warn "ERR: plugin skype_mood : $msg\n";
    return;
}

# get skype dbus object
sub _get_skype {
    my $init = shift;
    # TODO : undef $skype then it exit
    #$sigid = $skype->connect_to_signal( 'NameOwnerChanged', sub { $skype = _init_skype(); } ) if $skype and !$sigid;
    return $skype if $skype;
    return _init_skype($init);
}

sub _init_skype {
    my $init = shift;

    my $dbus = Net::DBus->find();

    # found skype instance
    my $dbus_objects = $dbus->get_service('org.freedesktop.DBus')->get_object('/org/freedesktop/DBus');
    my $skype_found = grep { $_ eq 'com.Skype.API' } @{ $dbus_objects->ListNames() };
    if ( !$skype_found and $init ) {
        return _error('No running DBus API-capable Skype found');
    }
    elsif ( !$skype_found ) { return; }

    my $skype_obj = $dbus->get_service('com.Skype.API')->get_object( '/com/Skype', 'com.Skype.API' );

    # init dbus session
    my $answer = _to_skype( 'NAME gmb-plugin-skype-mood', $skype_obj );
    return _error('Error communicating with Skype!') if $answer ne 'OK';
    $answer = _to_skype( 'PROTOCOL 7', $skype_obj );
    return _error('Skype client too old!') if $answer ne 'PROTOCOL 7';

    return $skype_obj;
}

sub _to_skype {
    my ( $cmd, $skype_obj ) = @_;
    $skype_obj ||= _get_skype();
    return unless $skype_obj;

    warn "plugin skype_mood : send to skype '$cmd'\n" if $::debug;
    my $answer = $skype_obj->Invoke($cmd) || '';
    warn "plugin skype_mood : skype answer = $answer\n" if $::debug;
    return $answer;
}

1;

__END__

=head1 NAME

Skype Mood plugin

=head1 DESCRIPTION

Set skype mood message based on playing a song.
You must add 'gmb-plugin-skype-mood' to 'allowed' apps in skype.

=head1 KNOWN ISSUES

Skype static builds don't have dbus support.

=head1 SEE ALSO

L<http://developer.skype.com/public-api-reference>

=head1 AUTHOR

Sergiy Borodych

