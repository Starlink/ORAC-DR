package ORAC::Group::NIRI;

=head1 NAME

ORAC::Group::NIRI - class for dealing with NIRI observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::NIRI;

  $Grp = new ORAC::Group::NIRI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to NIRI. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::NIRI> objects.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UKIRT;
use ORAC::General;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

 '$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for NIRI should go here
my %hdr = (
            DETECTOR_READ_TYPE   => "MODE",
            RA_TELESCOPE_OFFSET  => "RAOFFSET",
            X_REFERENCE_PIXEL    => "CRPIX1",
            Y_REFERENCE_PIXEL    => "CRPIX2"
	  );

# Take this lookup table and generate methods.
ORAC::Group::NIRI->_generate_orac_lookup_methods( \%hdr );

# Note use list context as there are multiple CD matrices in
# the header.  We want scalar context.
sub _to_DEC_SCALE {
   my $self = shift;
   my $cd11 = $self->hdr("CD1_1");
   my $cd12 = $self->hdr("CD1_2");
   my $cd21 = $self->hdr("CD2_1");
   my $cd22 = $self->hdr("CD2_2");
   my $sgn;
   if ( ( $cd11 * $cd22 - $cd12 * $cd21 ) < 0 ) { $sgn = -1; } else { $sgn = 1; }
   abs( sqrt( $cd11**2 + $cd21**2 ) * 3600 );
}

# Have to fudge this for some reason for the long focal-ratio camera.
sub _to_DEC_TELESCOPE_OFFSET {
    my $self = shift;
    my $offset = $self->hdr( "DECOFFSE" );
    if ( defined( $self->hdr( "INPORT" ) ) &&
         $self->hdr( "INPORT" ) == 3 ) {
       $offset = -1.0 * $self->hdr( "DECOFFSE" );
    }
    return $offset;
}

sub _from_DEC_TELESCOPE_OFFSET {
   "DECOFFSE",  $_[0]->uhdr( "ORAC_DEC_TELESCOPE_OFFSET" );
}

sub _to_EXPOSURE_TIME {
   my $self = shift;
   my $et = $self->hdr->{EXPTIME};
   my $co = $self->hdr->{COADDS};
   $et *= $co;
}

sub _to_FILTER {
   my $self = shift;
   my $filter = "";
   my $filter1 = $self->hdr( "FILTER1" );
   my $filter2 = $self->hdr( "FILTER2" );
   my $filter3 = $self->hdr( "FILTER3" );

   if ( $filter1 =~ "open" ) {
      $filter = $filter2;
   }

   if ( $filter2 =~ "open" ) {
      $filter = $filter1;
   }

   if ( ( $filter1 =~ "blank" ) ||
        ( $filter2 =~ "blank" ) || 
        ( $filter3 =~ "blank" ) ) {
      $filter = "blank";
   }
   return $filter;
}

sub _to_GAIN {
  12.3; # hardwire in gain for now
}

sub _to_OBSERVATION_MODE {
   "imaging";
}

sub _to_OBSERVATION_NUMBER {
   my $self = shift;
   my $obsnum = 0;
   if ( exists ( $self->hdr->{FRMNAME} ) ) {
      my $fname = $self->hdr->{FRMNAME};
      $obsnum = substr( $fname, index( $fname, ":" ) - 4, 4 );
   }
   return $obsnum;
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr( "OBSTYPE" );
   if ( $type eq "SCI" ) {
      $type = "OBJECT";
   }
   return $type;
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   if ( exists ( $self->hdr->{CRPIX1} ) ) {
      $ra = $self->hdr->{CRPIX1};
   }
   $ra = defined( $ra ) ? $ra: 0.0;
   return $ra / 15.0;
}

sub _to_RA_SCALE {
   my $self = shift;
   my $cd12 = $self->hdr("CD1_2");
   my $cd22 = $self->hdr("CD2_2");
   sqrt( $cd12**2 + $cd22**2 ) * 3600;
}

# ROTATION, DEC_SCALE and RA_SCALE transformations courtesy Micah Johnson, from
# the cdelrot.pl script supplied for use with XIMAGE.  Extended here to the
# FITS-WCS Paper II Section 6.2 prescription, averaging the rotation.

sub _to_ROTATION {
   my $self = shift;
   my $cd11 = $self->hdr("CD1_1");
   my $cd12 = $self->hdr("CD1_2");
   my $cd21 = $self->hdr("CD2_1");
   my $cd22 = $self->hdr("CD2_2");

# Obtain the plate scales CDELT1 and CDELT2 equivalents as if we hasd a PCi_i matrix.
   my $sgn;
   if ( ( $cd11 * $cd22 - $cd12 * $cd21 ) < 0 ) { $sgn = -1; } else { $sgn = 1; }
   my $cdelt1 = $sgn * sqrt( $cd11**2 + $cd21**2 );
   my $cdelt2 = $sgn * sqrt( $cd22**2 + $cd12**2 );

# Determine the sense of the scales.
   my $sgn2;
   if ( $cd12 < 0 ) { $sgn2 = -1; } else { $sgn2 = 1; }
   my $sgn3;
   if ( $cd21 < 0 ) { $sgn3 = -1; } else { $sgn3 = 1; }
   my $rtod = 45 / atan2( 1, 1 );

# Average the estimates of the rotation.
   my $rotation = $rtod * 0.5 * ( atan2( $sgn2 * $cd21 / $rtod, $sgn2 * $cd11 / $rtod ) +
                                  atan2( $sgn3 * $cd12 / $rtod, -$sgn3 * $cd22 / $rtod ) );

# Plus 90 is a fudge because the CD matrix appears is wrong by 90 degrees for port 3,
# the f/32 camera, judging by the telescope offsets, CTYPEn, and the support astronomer.
   $rotation += 90  if ( defined( $self->hdr( "INPORT" ) ) && $self->hdr( "INPORT" ) ) == 3;

   return $rotation;
}

sub _to_SPEED_GAIN {
   "NA";
}

sub _to_STANDARD {
   0; # hardwire for now as all objects not a standard.
}

sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;

# Obtain the UT start time and convert to decimal hours.
   my $utstring = $self->hdr( "UTEND" );
   my $utend = $utstring;
   if ( ! is_numeric( $utstring ) ) {
      $utend = hmstodec( $utstring );
   }
   return $utend;
}

sub _from_UTEND {
    my @hms = dectodms( $_[0]->uhdr( "ORAC_UTEND" ) );
    my $utstring = '0'x(2-length( $hms[ 0 ] ) ) . "$hms[ 0 ]" .
                   '0'x(2-length( $hms[ 1 ] ) ) . "$hms[ 1 ]" .
                   sprintf( "%4.1f", $hms[ 2 ] );
   "UTEND", $utstring;
}

sub _to_UTSTART {
   my $self = shift;
 
# Obtain the UT start time and convert to decimal hours.
   my $utstring = $self->hdr( "UT" );
   my $ut = 0.0;
   if ( defined( $utstring ) && $utstring !~ /\s+/ ) {
      $ut = hmstodec( $utstring );
   }
   return $ut;
}

sub _to_WAVEPLATE_ANGLE {
   0; # hardwire angle for now
}

# Shift the bounds to GRID co-ordinates.
sub _to_X_LOWER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{LOWCOL} + 1 );
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{LOWROW} + 1 );
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{HICOL} + 1 );
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{HIROW} + 1 );
}

# Supplementary methods for the translations
# ------------------------------------------

# Returns the UT date in YYYYMMDD format.
sub get_UT_date {
   my $self = shift;

# This is UT start and time.
   my $dateobs = $self->hdr->{"DATE-OBS"};

# Extract out the data in yyyymmdd format.
   return substr( $dateobs, 0, 4 ) . substr( $dateobs, 5, 2 ) . substr( $dateobs, 8, 2 );
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::NIRI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::NIRI;
   $Grp = new ORAC::Group::NIRI("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gN');
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

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME
  # For NIRI the keyword is simply UTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('UT');
  $time=hmstodec($time);
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # Calc ORACUT:
  my $ut = $self->hdr('DATE');
  $ut = 0 unless defined $ut;
  $ut =~ s/-//g;  #  Remove the intervening minus sign

  $self->hdr('ORACUT', $ut);
  $new{ORACUT} = $ut;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
