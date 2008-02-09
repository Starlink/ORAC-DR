package ORAC::Frame::GEMINI;

=head1 NAME

ORAC::Frame::GEMINI - class for dealing with GEMINI observation files in ORAC-DR

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to GEMINI. It provides a class derived from B<ORAC::Frame::UKIRT>.

=cut

use 5.006;
use strict;
use warnings;

use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

# standard error module and turn on strict
use Carp;

# These are maybe the Gemini generic lookup tables
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "CRVAL2",
	    EXPOSURE_TIME       => "EXPTIME",
            EQUINOX             => "EQUINOX",
	    INSTRUMENT          => "INSTRUME",
            NUMBER_OF_EXPOSURES => "NSUBEXP",
	    NUMBER_OF_EXPOSURES => "COADDS",
            OBJECT              => "OBJECT",
            X_REFERENCE_PIXEL   => "CRPIX1",
            Y_REFERENCE_PIXEL   => "CRPIX2"
        );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Frame::GEMINI->_generate_orac_lookup_methods( \%hdr );

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
   abs( sqrt( $cd11**2 + $cd21**2 ) );
}

sub _to_DEC_TELESCOPE_OFFSET {
    my $self = shift;

# It's simple when there's a header.
    my $offset = $self->hdr( "DECOFFSE" );

# Otherwise for older data have to derive an offset from the source
# position and the frame position.  This does assume that the
# reference pixel is unchanged in the group.  The other headers
# are measured in degrees, but the offsets are in arceseconds.
    if ( !defined( $offset ) ) {
       my $decbase = $self->hdr( "CRVAL2" ) ;
       my $dec = $self->hdr( "DEC" );
       if ( defined( $decbase ) && defined( $dec ) ) {
          $offset = 3600.0 * ( $dec - $decbase );
       } else {
          $offset = 0.0;
       }
    }
    return $offset;
}

sub _from_DEC_TELESCOPE_OFFSET {
   "DECOFFSE",  $_[0]->uhdr( "ORAC_DEC_TELESCOPE_OFFSET" );
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

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr( "OBSTYPE" );
   if ( $type eq "SCI" || $type eq "OBJECT-OBS" ) {
      $type = "OBJECT";
   }
   return $type;
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   if ( exists ( $self->hdr->{CRVAL1} ) ) {
      $ra = $self->hdr->{CRVAL1};
   }
   $ra = defined( $ra ) ? $ra: 0.0;
   return $ra;
}

sub _to_RA_SCALE {
   my $self = shift;
   my $cd12 = $self->hdr("CD1_2");
   my $cd22 = $self->hdr("CD2_2");
   sqrt( $cd12**2 + $cd22**2 );
}
 
sub _to_RA_TELESCOPE_OFFSET {
    my $self = shift;

# It's simple when there's a header.
    my $offset = $self->hdr( "RAOFFSET" );

# Otherwise for older data have to derive an offset from the source
# position and the frame position.  This does assume that the
# reference pixel is unchanged in the group.  The other headers
# are measured in degrees, but the offsets are in arceseconds.
    if ( !defined( $offset ) ) {
       my $rabase = $self->hdr( "CRVAL1" ) ;
       my $ra = $self->hdr( "RA" );
       my $dec = $self->hdr( "DEC" );
       if ( defined( $rabase ) && defined( $ra ) && defined( $dec ) ) {
          $offset = 3600* ( $ra - $rabase ) * cosdeg( $dec );
       } else {
          $offset = 0.0;
       }
    }
    return $offset;
}

sub _from_RA_TELESCOPE_OFFSET {
   "RAOFFSE",  $_[0]->uhdr( "ORAC_RA_TELESCOPE_OFFSET" );
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
                                  
   return $rotation;
}

sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;
   
# Obtain the UT end time and convert to decimal hours.
   my $addexp = 0;
   my $utstring = $self->hdr( "UTEND" );
   if ( !defined $utstring ) {
       $utstring = $self->hdr( "UT" );
       $addexp = 1;
   }

# Convert to decimal hours.
   my $utend = $utstring;
   if ( ! is_numeric( $utstring ) && $utstring !~ /Value/ ) {
      $utend = hmstodec( $utstring );
   }
   if ( $addexp ) {
      $utend +=  $self->hdr( "EXPTIME" );
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


=head1 AUTHORS

Paul Hirst <p.hirst@jach.hawaii.edu>
Malcolm J. Currie <mjc@star.rl.ac.uk>

=cut

 
1;
