package ORAC::Calib::NIRI;

=head1 NAME

ORAC::Calib::NIRI;

=head1 SYNOPSIS

  use ORAC::Calib::NIRI;

  $Cal = new ORAC::Calib::NIRI;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying NIRI-specific calibration
objects.  It provides a class derived from ORAC::Calib::ImagingSpec.  All the
methods available to ORAC::Calib::ImagingSpec objects are available to
ORAC::Calib::NIRI objects.  Written for Michelle and adapted for NIRI.

=cut

use Carp;
use warnings;
use strict;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

For NIRI some of the rules files are keyed on the current value of
the CAMERA FITS header item.  This sub-class automatically changes the
rules file of the underlying index object.

=over 4

=item B<is_imaging_mode>

Returns true if this observation should use an imaging (_im)
calibration.

As of this writing, Astro::FITS::HdrTrans seems to force
ORAC_OBSERVATION_MODE to 'imaging'.

=cut

sub is_imaging_mode {
  my $self = shift;
  return !$self->is_spectroscopy_mode;
}

=item B<is_spectroscopy_mode>

Returns true if this observation should use an imaging (_sp)
calibration.

There is no direct keyword for the observation mode, so test for
the presence of a grism.

=cut

sub is_spectroscopy_mode {
  my $self = shift;
  return ( $self->thing->{FILTER3} =~ /[Gg]rism/ )
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
