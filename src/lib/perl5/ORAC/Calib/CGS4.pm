package ORAC::Calib::CGS4;

=head1 NAME

ORAC::Calib::CGS4;

=head1 SYNOPSIS

  use ORAC::Calib::CGS4;

  $Cal = new ORAC::Calib::CGS4;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying CGS4-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use strict;
use Carp;
use warnings;

use base qw/ORAC::Calib::Spectroscopy/;

use vars qw/$VERSION/;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors(
                                  engineering => {},
);

=head1 METHODS

The following methods are available:

=head2 General Methods

=over 4

=item B<default_mask>

Return the default mask.

=cut

sub default_mask {
  return "fpa46_long.sdf";
}

=back

=head2 Support Methods

Each of the methods above has a support implementation to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

This class adds an "engineering" set.

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
