package ORAC::Calib::GMOS;

=head1 NAME

ORAC::Calib::GMOS;

=head1 SYNOPSIS

  use ORAC::Calib::GMOS;

  $Cal = new ORAC::Calib::GMOS;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying GMOS-specific calibration
objects. It provides a class derived from ORAC::Calib::Spectroscopy.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

# standard error module and turn on strict
use Carp;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::Spectroscopy/;

use vars qw/$VERSION/;
$VERSION = '1.0';

=head2 General Methods

=over 4

=item B<default_mask>

Return the default mask.

=cut

sub default_mask {
  return "fpa46_long.sdf";
}

=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
