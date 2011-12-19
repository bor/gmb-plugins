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

our $VERSION = 0.1;

use constant { OPT => 'PLUGIN_OFA_' };

require $::HTTP_module;

# TODO
die "Not ready yet!\n";

my $widget = {
    class    => __PACKAGE__,
    tabicon  => 'plugin-ofa',
    tabtitle => _ "OFA",
};

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

OFA plugin

=head1 DESCRIPTION

Retrieves metadata for unknown audio files.

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Acoustic_fingerprint>,
L<https://metacpan.org/module/Audio::Ofa>,
L<https://metacpan.org/module/Audio::Ofa::Util>

=head1 AUTHOR

Sergiy Borodych

