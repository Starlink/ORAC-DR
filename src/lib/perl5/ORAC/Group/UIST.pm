package ORAC::Group::UIST;

=head1 NAME

ORAC::Group::UIST - UIST class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::UIST("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to UIST. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::UIST> objects. 

=cut

# A package to describe a UIST group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ORAC::Group::UKIRT/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for UIST should go here.
# First the imaging...
my %hdr = (
            DEC_SCALE            => "CDELT1",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "CDELT2",
            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "CNFINDEX",
            GRATING_DISPERSION   => "CDELT1",
            GRATING_NAME         => "GRISM",
            GRATING_ORDER        => "GRATORD",
            GRATING_WAVELENGTH   => "CENWAVL",
            SLIT_ANGLE           => "SLIT_PA",
            SLIT_NAME            => "SLITNAME",
            UTDATE               => "UTDATE",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS",

# then the general.
            DETECTOR_READ_TYPE   => "DET_MODE",
            EXPOSURE_TIME        => "EXP_TIME",
            GAIN                 => "GAIN",
            NUMBER_OF_EXPOSURES  => "NEXP",
            NUMBER_OF_READS      => "NREADS",
            OBSERVATION_MODE     => "INSTMODE",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::UIST->_generate_orac_lookup_methods( \%hdr );

sub _to_NSCAN_POSITIONS {
  1;
}

# Sampling is always 1x1, and therefore there are no headers with
# these values.
sub _from_NSCAN_POSITIONS {
  "DETNINCR", 1;
}

# ROTATION comprises the rotation matrix with respect to flipped axes,
# i.e. x corresponds to declination and Y to right ascension.  For other
# UKIRT instruments this was not the case, the rotation being defined
# in CROTA2.  Here the effective rotation is that evaluated from the
# PC matrix with a 90-degree counter-clockwise rotation for the rotated
# axes. If there is a PC3_2 header, we assume that we're in spectroscopy
# mode and use that instead.

sub _to_ROTATION {
  my $self = shift;
  my $rotation;
  if ( exists( $self->hdr->{PC1_1} ) && exists( $self->hdr->{PC2_1}) ) {
    my $pc11;
    my $pc21;
    if ( exists ($self->hdr->{PC3_2} ) && exists( $self->hdr->{PC2_2} ) ) {

      # We're in spectroscopy mode.
      $pc11 = $self->hdr->{PC3_2};
      $pc21 = $self->hdr->{PC2_2};
    } else {
      # We're in imaging mode.
      $pc11 = $self->hdr->{PC1_1};
      $pc21 = $self->hdr->{PC2_1};
    }
    my $rad = 57.2957795131;
    $rotation = $rad * atan2( -$pc21 / $rad, $pc11 / $rad ) + 90.0;
  } elsif ( exists $self->hdr->{CROTA2} ) {
    $rotation =  $self->hdr->{CROTA2} + 90.0;
  } else {
    $rotation = 90.0;
  }
  return $rotation;
}

sub _to_SCAN_INCREMENT {
  1;
}

sub _from_SCAN_INCREMENT {
  "DETINCR", 1;
}


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::UIST> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::UIST;
   $Grp = new ORAC::Group::UIST("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'rg'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gu');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames.  For UIST this
is decimal UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

ORACDATETIME: This is the UT date in ISO8601 format: YYYY-MM-DDThh:mm:ss.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # Grab the UT datetime from the DATE-OBS header.
  my $dateobs = defined( $self->hdr->{1}->{'DATE-OBS'}) ? $self->hdr->{1}->{'DATE-OBS'} : ( defined($self->hdr->{'DATE-OBS'}) ? $self->hdr->{'DATE-OBS'} : 0 );

  # Split it into its constituent components.
  $dateobs =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = $4;
  my $minute = $5;
  my $second = $6;

  # Now set ORACTIME to be decimal UT date.
  my $date = $year . $month . $day;
  my $time = $hour / 24 + ( $minute / ( 24 * 60 ) ) + ( $second / ( 24 * 60 * 60 ) );

  $self->hdr('ORACTIME', $date + $time);

  $new{'ORACTIME'} = $date + $time;

  # ORACUT is just $date.
  $self->hdr('ORACUT', $date );
  $new{'ORACUT'} = $date;

  # And set up the ORACDATETIME header too.
  $dateobs =~ s/Z//g;
  $self->hdr( 'ORACDATETIME', $dateobs );
  $new{'ORACDATETIME'} = $dateobs;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group::Michelle>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
