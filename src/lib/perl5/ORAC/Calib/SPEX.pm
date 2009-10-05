package ORAC::Calib::SPEX;

=head1 NAME

ORAC::Calib::SPEX;

=head1 SYNOPSIS

  use ORAC::Calib::SPEX;

  $Cal = new ORAC::Calib::SPEX;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying SPEX-specific
calibration objects.  It provides a class derived from ORAC::Calib::Imaging.
All the methods available to ORAC::Calib::Imaging objects are available to
ORAC::Calib::SPEX objects.

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

Copyright (C) 2004-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
