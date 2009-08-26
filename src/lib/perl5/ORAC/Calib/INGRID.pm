package ORAC::Calib::INGRID;

=head1 NAME

ORAC::Calib::INGRID;

=head1 SYNOPSIS

  use ORAC::Calib::INGRID;

  $Cal = new ORAC::Calib::INGRID;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying INGRID-specific calibration
objects. It provides a class derived from ORAC::Calib::Imaging.  All the
methods available to ORAC::Calib::Imaging objects are available to
ORAC::Calib::INGRID objects.

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

=head1 AUTHORS

Malcolm Currie (Starlink) (mjc@star.rl.ac.uk)
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
