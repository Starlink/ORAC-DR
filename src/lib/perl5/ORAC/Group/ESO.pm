package ORAC::Group::ESO;

=head1 NAME

ORAC::Group::ESO - ESO class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::ESO("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to ESO. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::ESO> objects. 

=cut

# A package to describe a ESO group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;

use Math::Trig;
use ORAC::Group::UKIRT;
use ORAC::Print;
use ORAC::General;

# Set inheritance
use base qw/ORAC::Group::UKIRT/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for ESO should go here.
# First the imaging...
my %hdr = (
            DEC_SCALE            => "CDELT1",
            RA_SCALE             => "CDELT2",

# then the spectroscopy...
            SLIT_NAME            => "HIERARCH.ESO.INS.OPTI1.ID",
            X_DIM                => "HIERARCH.ESO.DET.WIN.NX",
            Y_DIM                => "HIERARCH.ESO.DET.WIN.NY",

# then the general.
            CHOP_ANGLE           => "HIERARCH.ESO.SEQ.CHOP.POSANGLE",
            CHOP_THROW           => "HIERARCH.ESO.SEQ.CHOP.THROW",
            EXPOSURE_TIME        => "EXPTIME",
            NUMBER_OF_EXPOSURES  => "HIERARCH.ESO.DET.NDIT",
            NUMBER_OF_READS      => "HIERARCH.ESO.DET.NCORRS",
            OBSERVATION_NUMBER   => "OBSNUM",
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::ESO->_generate_orac_lookup_methods( \%hdr );

sub _to_AIRMASS_END {
   my $self = shift;
   my $end_airmass = 1.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.TEL.AIRM.END"} ) {
      $end_airmass = $self->hdr->{"HIERARCH.ESO.TEL.AIRM.END"};
   } elsif ( exists $self->hdr->{AIRMASS} ) {
      $end_airmass = $self->hdr->{AIRMASS};
   }
   return $end_airmass;
}

sub _from_AIRMASS_END {
   "HIERARCH.ESO.TEL.AIRM.END", $_[0]->uhdr( "ORAC_AIRMASS_END" );
}

sub _to_AIRMASS_START {
   my $self = shift;
   my $start_airmass = 1.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.TEL.AIRM.START"} ) {
      $start_airmass = $self->hdr->{"HIERARCH.ESO.TEL.AIRM.START"};
   } elsif ( exists $self->hdr->{AIRMASS} ) {
      $start_airmass = $self->hdr->{AIRMASS};
   }
   return $start_airmass;
}

sub _from_AIRMASS_START {
   "HIERARCH.ESO.TEL.AIRM.START", $_[0]->uhdr( "ORAC_AIRMASS_START" );
}

sub _to_CONFIGURATION_INDEX {
    my $self = shift;
    my $instindex = 0;
    if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.ENC"} ) {
       $instindex = $self->hdr->{"HIERARCH.ESO.INS.GRAT.ENC"};
    }
    return $instindex;
}

sub _to_DEC_BASE {
   my $self = shift;
   my $dec = 0.0;
   if ( exists ( $self->hdr->{DEC} ) ) {
      $dec = $self->hdr->{DEC};
   }
   $dec = defined( $dec ) ? $dec: 0.0; 
   return $dec;
}

# This is guesswork at present.  It's rather tied to the UKIRT names
# and we need generic names or use instrument-specific values in
# instrument-specific primitives, and pass the actual value for the
# night log.  Could do with separate ORAC_CHOPPING, ORAC_BIAS booleans
# to indicate whether or not chopping is enabled and whether or not the
# detector mode needs a bias removed, like UKIRT's STARE mode.
sub _to_DETECTOR_READ_TYPE {
   my $self = shift;
   my $read_type;
   my $chop = $self->hdr->{"HIERARCH.ESO.TEL.CHOP.ST"};
   $chop = defined( $chop ) ? $chop : 0;
   my $detector_mode = exists( $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} ) ?
                       $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} : "NDSTARE";
   if ( $detector_mode =~ /Uncorr/ ) {
      if ( $chop ) {
         $read_type = "CHOP";
      } else {
         $read_type = "STARE";
      }
   } else {
      if ( $chop ) {
         $read_type = "NDCHOP";
      } else {
         $read_type = "NDSTARE";
      }
   }
   return $read_type;
}

# Equinox may be absent for calibrations such as darks.
sub _to_EQUINOX {
   my $self = shift;
   my $equinox = 0;
   if ( exists $self->hdr->{EQUINOX} ) {
      $equinox = $self->hdr->{EQUINOX};
   }
   return $equinox;
}

sub _to_GRATING_NAME{
   my $self = shift;
   my $name = "UNKNOWN";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} ) {
      $name = $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"};
   }
   return $name;
}

sub _to_GRATING_ORDER{
   my $self = shift;
   my $order = 1;
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"} ) {
      $order = $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"};
   }
   return $order;
}

sub _to_GRATING_WAVELENGTH{
   my $self = shift;
   my $wavelength = 0;
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.WLEN"} ) {
      $wavelength = $self->hdr->{"HIERARCH.ESO.INS.GRAT.WLEN"};
   }
   return $wavelength;
}

# Sampling is always 1x1, and therefore there are no headers with
# these values.
sub _to_NSCAN_POSITIONS {
   1;
}

sub _from_NSCAN_POSITIONS {
   "DETNINCR", 1;
}

sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;
   return $self->hdr->{"HIERARCH.ESO.TPL.NEXP"} + 1;
}
            
sub _from_NUMBER_OF_OFFSETS {
   "HIERARCH.ESO.TPL.NEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
}

sub _to_OBSERVATION_MODE {
   my $self = shift;
   return $self->get_instrument_mode();
}

sub _from_OBSERVATION_MODE {
   "HIERARCH.ESO.DPR.TECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
}

# OBJECT, SKY, and DARK need no change.
sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   $type = exists( $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} ) ? $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} : "OBJECT";
   if ( uc( $type ) eq "STD" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" || uc( $type ) eq "FLAT,SKY" ) {
      $type = "SKY";
   } elsif ( uc( $type ) eq "LAMP,FLAT" || uc( $type ) eq "FLAT,LAMP" ) {
      $type = "LAMP";
   } elsif ( uc( $type ) eq "LAMP" ) {
      $type = "ARC";
   }
   return $type;
}

sub _from_OBSERVATION_TYPE {
   "HIERARCH.ESO.DPR.TYPE",  $_[0]->uhdr( "ORAC_OBSERVATION_TYPE" );
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   if ( exists ( $self->hdr->{RA} ) ) {
      $ra = $self->hdr->{RA};
   }
   $ra = defined( $ra ) ? $ra: 0.0; 
   return $ra / 15.0;
}

sub _to_ROTATION {
   my $self = shift;
   return $self->rotation();
}

sub _to_SCAN_INCREMENT {
   1;
}

sub _from_SCAN_INCREMENT {
   "DETINCR", 1;
}

sub _to_SLIT_ANGLE {
   my $self = shift;
   my $slitangle = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.ADA.POSANG"} ) {
      $slitangle =  $self->hdr->{"HIERARCH.ESO.ADA.POSANG"};
   }
   return $slitangle;
}

sub _from_SLIT_ANGLE {
   "HIERARCH.ESO.ADA.POSANG",  $_[0]->uhdr( "ORAC_SLIT_ANGLE" );
}

sub _to_STANDARD {
   my $self = shift;
   my $standard = 0;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   if ( uc( $type ) =~ /STD/ ) {
      $standard = 1;
   }
   return $standard;
}

sub _from_STANDARD {
   "STANDARD",  $_[0]->uhdr( "ORAC_STANDARD" );
}

sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;

# Obtain the start time in seconds.
   my $startsec = 3600.0 * $self->get_UT_hours();

# This is approximate end UT in seconds.
   my $endsec = $startsec + $self->hdr->{EXPTIME};

# Convert from seconds to decimal hours.
   return $endsec / 3600.0;
}

sub _to_UTSTART {
   my $self = shift;

# Obtain the start time in seconds.
   return $self->get_UT_hours();
}

sub _to_WAVEPLATE_ANGLE {
    my $self = shift;
    my $polangle = 0.0;
    if ( exists $self->hdr->{"HIERARCH.ESO.ADA.POSANG"} ) {
       $polangle = $self->hdr->{"HIERARCH.ESO.ADA.POSANG"};
    } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.ROT.OFFANGLE"} ) {
       $polangle = $self->hdr->{"HIERARCH.ESO.SEQ.ROT.OFFANGLE"};
    } elsif ( exists $self->hdr->{CROTA1} ) {
       $polangle = abs( $self->hdr->{CROTA1} );
    }
    return $polangle;
}

sub _from_WAVEPLATE_ANGLE {
   "HIERARCH.ESO.ADA.POSANG",  $_[0]->uhdr( "ORAC_WAVEPLATE_ANGLE" );
}

# Use the nominal reference pixel if correctly supplied, failing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_X_REFERENCE_PIXEL{
   my $self = shift;
   my $xref;
   if ( exists $self->hdr->{CRPIX1} ) {
      $xref = $self->hdr->{CRPIX1};
   } elsif ( exists $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTX"} && exists $self->hdr->{"HIERARCH.ESO.DET.WIN.NX"} ) {
      my $xl = $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTX"};
      my $xu = $self->hdr->{"HIERARCH.ESO.DET.WIN.NX"};
      $xref = nint( ( $xl + $xu ) / 2 );
   } else {
      $xref = 504;
   }
   return $xref;
}

sub _from_X_REFERENCE_PIXEL {
   "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

# Use the nominal reference pixel if correctly supplied, failing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_Y_REFERENCE_PIXEL{
   my $self = shift;
   my $yref;
   if ( exists $self->hdr->{CRPIX2} ) {
      $yref = $self->hdr->{CRPIX2};
   } elsif ( exists $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTY"} && exists $self->hdr->{"HIERARCH.ESO.DET.WIN.NY"} ) {
      my $yl = $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTY"};
      my $yu = $self->hdr->{"HIERARCH.ESO.DET.WIN.NY"};
      $yref = nint( ( $yl + $yu ) / 2 );
   } else {
      $yref = 491;
   }
   return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
   "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

sub _to_X_LOWER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTX"} );
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   return nint( $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTY"} );
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   return $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTX"} - 1 + $self->hdr->{"HIERARCH.ESO.DET.WIN.NX"};
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   return $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTY"} - 1 + $self->hdr->{"HIERARCH.ESO.DET.WIN.NY"};
}


# Supplementary methods for the translations
# ------------------------------------------

# Get the observation mode.
sub get_instrument_mode {
   my $self = shift;
   my $mode = uc( $self->hdr->{"HIERARCH.ESO.DPR.TECH"} );
   if ( $mode eq "IMAGE" || $mode eq "POLARIMETRY" ) {
      $mode = "imaging";
   } elsif ( $mode eq "SPECTRUM" ) {
      $mode = "spectroscopy";
   }
   return $mode;
}

# Returns the UT date in YYYYMMDD format.
sub get_UT_date {
   my $self = shift;

# This is UT start and time.
   my $dateobs = $self->hdr->{"DATE-OBS"};

# Extract out the data in yyyymmdd format.
   return substr( $dateobs, 0, 4 ) . substr( $dateobs, 5, 2 ) . substr( $dateobs, 8, 2 )
}

# Returns the UT time of observation in decimal hours.
sub get_UT_hours {
   my $self = shift;

# This is approximate.  UTC is time in seconds.
   my $startsec = 0.0;
   if ( exists ( $self->hdr->{UTC} ) ) {
      $startsec  = $self->hdr->{UTC};

# Use the backup of the observation start header, which is encoded in
# FITS data format, i.e. yyyy-mm-ddThh:mm:ss.  So convert ot seconds.
   } elsif ( exists( $self->hdr->{"HIERARCH.ESO.OBS.START"} ) ) {
      my $t = $self->hdr->{"HIERARCH.ESO.OBS.START"};
      $startsec = substr( $t, 11, 2 ) * 3600.0 +
                  substr( $t, 14, 2 ) * 60.0 + substr( $t, 17, 2  );
   }

# Convert from seconds to decimal hours.
   return $startsec / 3600.0;
}

# Derives the rotation angle from the rotation matrix.
sub rotation{
   my $self = shift;
   my $rotangle;

# Define degrees to radians conversion.
   my $dtor = atan2( 1, 1 ) / 45.0;

# Tey PC matrix first.
   if ( exists $self->hdr->{PC001001} ) {
      my $pc11 = $self->hdr->{PC001001};
      my $pc21 = $self->hdr->{PC002001};
      $rotangle = $dtor * atan2( -$pc21 / $dtor, $pc11 / $dtor );

# Instead try CD matrix.  Testing for existence of first column should
# be adequate.
   } elsif ( exists $self->hdr->{CD1_1} && exists $self->hdr->{CD2_1}) {

      my $cd11 = $self->hdr->{CD1_1};
      my $cd12 = $self->hdr->{CD1_2};
      my $cd21 = $self->hdr->{CD2_1};
      my $cd22 = $self->hdr->{CD2_2};
      my $sgn;
      if ( ( $cd11 * $cd22 - $cd12 * $cd21 ) < 0 ) { $sgn = -1; } else { $sgn = 1; }
      my $cdelt1 = $sgn * sqrt( $cd11**2 + $cd21**2 );
      my $sgn2;
      if( $cdelt1 < 0 ) { $sgn2 = -1; } else { $sgn2 = 1; }
      my $rad = 57.2957795131;
      $rotangle = atan2( -$cd21 * $dtor, $sgn2 * $cd11 * $dtor ) / $dtor;

# Orientation may be encapsulated in the slit position angle for
# spectroscopy.
   } else {
      if ( uc( $self->get_instrument_mode() ) eq "SPECTROSCOPY" &&
           exists $self->hdr->{"HIERARCH.ESO.ADA.POSANG"} ) {
         $rotangle = $self->hdr->{"HIERARCH.ESO.ADA.POSANG"};
      } else {
         $rotangle = 180.0;
      }
   }
   return $rotangle;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames.  For ESO this
number is decimal hours + 12.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the group header.  It returns a hash containing the new
keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC
# headers.
   my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# --------
# For ESO this is the UTC header value converted to decimal hours
# and a 12-hour offset to avoid worrying about midnight UT.
   my $time = $self->get_UT_hours() + 12.0;

# Just return it (zero if not available).
   $time = 0 unless ( defined $time );
   $self->hdr( "ORACTIME", $time );

   $new{'ORACTIME'} = $time;

# ORACUT
# ------
# For ESO this is the UTC header value converted to decimal hours.
   my $ut = $self->get_UT_date();
   $ut = 0 unless defined $ut;
   $self->hdr( "ORACUT", $ut );
   $new{'ORACUT'} = $ut;

   return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group::UKIRT>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
