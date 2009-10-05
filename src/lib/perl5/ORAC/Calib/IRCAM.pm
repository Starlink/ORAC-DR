package ORAC::Calib::IRCAM;

=head1 NAME

ORAC::Calib::IRCAM;

=head1 SYNOPSIS

  use ORAC::Calib::IRCAM;

  $Cal = new ORAC::Calib::IRCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying IRCAM-specific calibration
objects. It provides a class derived from ORAC::Calib::Imaging.  All the
methods available to ORAC::Calib::Imaging objects are available to
ORAC::Calib::IRCAM objects.

=cut

use 5.006;

# standard modules
use Carp;
use strict;
use warnings;

use base qw/ ORAC::Calib::Imaging /;

use File::Spec;

use vars qw/ $VERSION/;
$VERSION = '1.0';

=head1 METHODS

=over 4

=item B<default_rotation_file>

Returns the name of the default rotation transformation matric file.

Returns "ircam3_rotate2eq.sdf" by default.

=cut

sub default_rotation_file {
  my $self = shift;
  return "ircam3_rotate2eq.sdf";
}

=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
