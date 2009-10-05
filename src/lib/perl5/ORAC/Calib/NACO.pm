package ORAC::Calib::NACO;

=head1 NAME

ORAC::Calib::NACO;

=head1 SYNOPSIS

  use ORAC::Calib::NACO;

  $Cal = new ORAC::Calib::NACO;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying NACO-specific calibration
objects.  It provides a class derived from ORAC::Calib::ImagSpec.  All the
methods available to ORAC::Calib::ImageSpec objects are available to
ORAC::Calib::NACO objects.

=cut

use Carp;
use warnings;
use strict;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.01';

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
