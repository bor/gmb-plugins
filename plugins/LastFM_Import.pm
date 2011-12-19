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

#use XML::Simple;

our $VERSION = 0.1;

#use constant { OPT => 'PLUGIN_LastFM_Import_' };

# TODO
# convert from lastfm2gmb
die "Not ready yet!\n";

sub Start {
    #Layout::RegisterWidget( PluginOFA => $widget );
}

sub Stop {
    #Layout::RegisterWidget( PluginOFA => undef );
}

sub prefbox {
    my $vbox = Gtk2::VBox->new( ::FALSE, 2 );
    return $vbox;
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

