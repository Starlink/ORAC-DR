package ORAC::Calib::SOFI;

=head1 NAME

ORAC::Calib::SOFI;

=head1 SYNOPSIS

  use ORAC::Calib::SOFI;

  $Cal = new ORAC::Calib::SOFI;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying SOFI-specific calibration
objects.  It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.  Written for Michelle and adapted for SOFI.

=cut

use Carp;
use warnings;
use strict;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

For SOFI some of the rules files are keyed on the current value of
the HIERARCH.ESO.DPR.TECH FITS header item.  This sub-class 
automatically changes the rules file of the underlying index object.

=over 4

=item B<is_imaging_mode>

Returns true if this observation should use an imaging (_im)
calibration.

Returns true is mode is IMAGE or POLARIMETRY.

=cut

sub is_imaging_mode {
  my $self = shift;
  my $mode = uc( $self->thing->{"HIERARCH.ESO.DPR.TECH"} );
  return ( $mode eq "IMAGE" || $mode eq "POLARIMETRY" );
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
