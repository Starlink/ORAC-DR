package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut

use 5.006;
use strict;
use warnings;

# These are the UKIRT generic lookup tables
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "DECBASE",
            DETECTOR_READ_TYPE  => "MODE",
            EQUINOX             => "EQUINOX",
            FILTER              => "FILTER",
	    INSTRUMENT          => "INSTRUME",
            NUMBER_OF_OFFSETS   => "NOFFSETS",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSERVATION_TYPE    => "OBSTYPE",
            RA_BASE             => "RABASE",
	    RECIPE              => "RECIPE",
            ROTATION            => "CROTA2",
            SPEED_GAIN          => "SPD_GAIN",
            STANDARD            => "STANDARD",
            WAVEPLATE_ANGLE     => "WPLANGLE",
            X_LOWER_BOUND       => "RDOUT_X1",
            X_UPPER_BOUND       => "RDOUT_X2",
            Y_LOWER_BOUND       => "RDOUT_Y1",
            Y_UPPER_BOUND       => "RDOUT_Y2"
        );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Frame::UKIRT->_generate_orac_lookup_methods( \%hdr );


# A package to describe a UKIRT group object for the
# ORAC pipeline

use vars qw/$VERSION/;
use ORAC::Frame::NDF;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# standard error module and turn on strict
use Carp;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

The $obsnum is zero padded to 5 digits.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Zero pad the number
  $obsnum = sprintf("%05d", $obsnum);

  # UKIRT form is FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This generic UKIRT version returns back the observation filename (from
file_from_bits) , adds a leading "." and replaces the .sdf with .ok

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # flag files for UKIRT of the type .xYYYYMMDD_NNNNN.ok
  my $raw = $self->file_from_bits($prefix, $obsnum);

  # raw includes the .sdf so we have to strip it
  $raw = $self->stripfname($raw);

  my $flag = ".".$raw.".ok";

}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
