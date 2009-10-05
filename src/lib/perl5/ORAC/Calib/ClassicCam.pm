package ORAC::Calib::ClassicCam;

=head1 NAME

ORAC::Calib::ClassicCam;

=head1 SYNOPSIS

  use ORAC::Calib::ClassicCam;

  $Cal = new ORAC::Calib::ClassicCam;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying ClassicCam-specific
calibration objects.  It provides a class derived from ORAC::Calib.
All the methods available to ORAC::Calib::Imaging objects are available to
ORAC::Calib::ClassicCam objects.

=cut

use 5.006;

# standard modules
use Carp;
use strict;
use warnings;

use base qw/ ORAC::Calib::Imaging /;

use vars qw/ $VERSION /;
$VERSION = '1.0';

=head1 AUTHORS

Malcolm J. Currie (mjc@star.rl.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
