package ORAC::Group::ISAAC;

=head1 NAME

ORAC::Group::ISAAC - ISAAC class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::ISAAC("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to ISAAC. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::ISAAC> objects. 

=cut

# A package to describe a ISAAC group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ORAC::Group::UKIRT/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for ISAAC should go here.
# First the imaging...
my %hdr = (
            DEC_SCALE            => "CDELT1",
            RA_SCALE             => "CDELT2",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "HIERARCH.ESO.INS.GRAT.ENC",
            GRATING_DISPERSION   => "CDELT1",
            GRATING_NAME         => "HIERARCH.ESO.INS.GRAT.NAME",
            GRATING_ORDER        => "HIERARCH.ESO.INS.GRAT.ORDER",
            GRATING_WAVELENGTH   => "HIERARCH.ESO.INS.GRAT.WLEN",
            SLIT_ANGLE           => "HIERARCH.ESO.ADA.POSANG",
            SLIT_NAME            => "HIERARCH.ESO.INS.SLIT",
            X_DIM                => "HIERARCH.ESO.DET.WIN.NX",
            Y_DIM                => "HIERARCH.ESO.DET.WIN.NY",

# then the general.
            AIRMASS_START        => "HIERARCH.ESO.TEL.AIRM.START",
            AIRMASS_END          => "HIERARCH.ESO.TEL.AIRM.END",
            CHOP_ANGLE           => "HIERARCH.ESO.SEQ.CHOP.POSANGLE",
            CHOP_THROW           => "HIERARCH.ESO.SEQ.CHOP.THROW",
            DEC_BASE             => "DEC",
            EXPOSURE_TIME        => "EXPTIME",
            FILTER               => "HIERARCH.ESO.INS.FILT1.ID",
            NUMBER_OF_EXPOSURES  => "HIERARCH.ESO.DET.NDIT",
            NUMBER_OF_READS      => "HIERARCH.ESO.DET.NCORRS",
            OBSERVATION_NUMBER   => "OBSNUM",
            WAVEPLATE_ANGLE      => "HIERARCH.ESO.SEQ.ROT.OFFANGLE",
            X_LOWER_BOUND        => "HIERARCH.ESO.DET.WIN.STARTX",
            Y_LOWER_BOUND        => "HIERARCH.ESO.DET.WIN.STARTY"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::ISAAC->_generate_orac_lookup_methods( \%hdr );

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoffset = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"} ) {
      $decoffset = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"};

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} &&
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

      my $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      my $x_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} * $pixscale;
      my $y_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} * $pixscale;

# Define degrees to radians conversion and obtain the rotation angle.
      my $dtor = atan2( 1, 1 ) / 45.0;

      my $rotangle = $self->rotation();
      my $cosrot = cos( $rotangle * $dtor );
      my $sinrot = sin( $rotangle * $dtor );

# Apply the rotation matrix to obtain the equatorial pixel offset.
      $decoffset = -$x_as * $sinrot + $y_as * $cosrot;
   }
              
# The sense is reversed compared with UKIRT, as these measure the
# place son the sky, not the motion of the telescope.
   return -1.0 * $decoffset;
}

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_RA_TELESCOPE_OFFSET {
   my $self = shift;
   my $raoffset = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETA"} ) {
      $raoffset = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETA"};

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} &&
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

      my $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      my $x_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} * $pixscale;
      my $y_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} * $pixscale;

# Define degrees to radians conversion and obtain the rotation angle.
      my $dtor = atan2( 1, 1 ) / 45.0;

      my $rotangle = $self->rotation();
      my $cosrot = cos( $rotangle * $dtor );
      my $sinrot = sin( $rotangle * $dtor );

# Apply the rotation matrix to obtain the equatorial pixel offset.
      $raoffset = $x_as * $cosrot + $y_as * $sinrot;
   }
              
# The sense is reversed compared with UKIRT, as these measure the
# place on the sky, not the motion of the telescope.
   return -1.0 * $raoffset;
}


sub rotation{
   my $self = shift;
   my $rotangle;

# Define degrees to radians conversion.
   my $dtor = atan2( 1, 1 ) / 45.0;

   if ( exists $self->hdr->{PC001001} ) {
      my $pc11 = $self->hdr->{PC001001};
      my $pc21 = $self->hdr->{PC002001};
      $rotangle = $dtor * atan2( -$pc21 / $dtor, $pc11 / $dtor );
   } else {
      $rotangle = 180.0;
   }
   return $rotangle;
}


# This is guesswork at present.
sub _to_DETECTOR_READ_TYPE {
   my $self = shift;
   my $read_type;
   my $chop = $self->hdr->{"HIERARCH.ESO.TEL.CHOP.ST"};
   my $readout_mode = $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"};
   if ( $readout_mode =~ /Uncorr/ ) {
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

# Fixed values for the gain depend on the camera (SW or LW), and for LW
# the readout mode.
sub _to_GAIN {
   my $self = shift;
   my $gain;
   my $mode = $self->hdr->{"HIERARCH.ESO.INS.MODE"};
   if ( $mode =~ /SW/ ) {
      $gain = 4.6;
   } else {
      my $readout_mode = $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"};
      if ( $readout_mode =~ /LowBias/ ) {
         $gain = 8.7;
      } else {
         $gain = 7.8;
      }
   }
   return $gain;
}

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
#   "HIERARCH.ESO.TPL.NEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
   "NEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
}

sub _to_OBSERVATION_MODE {
   my $self = shift;
   my $mode = $self->hdr->{"HIERARCH.ESO.DPR.TECH"};
   if ( uc( $mode ) eq "IMAGE" ) {
      $mode = "imaging";
   } else {
      $mode = "spectroscopy";
   }
   return $mode;
}

sub _from_OBSERVATION_MODE {
#   "HIERARCH.ESO.DPR.TECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
   "DPRTECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   if ( uc( $type ) eq "STD" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" ) {
      $type = "SKY";
   }
   return $type;
}

sub _from_OBSERVATION_TYPE {
#   "HIERARCH.ESO.DPR.TYPE",  $_[0]->uhdr( "ORAC_OBSERVATION_TYPE" );
   "DPRTYPE",  $_[0]->uhdr( "ORAC_OBSERVATION_TYPE" );
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = $self->hdr->{RA};
   return $ra / 15.0;
}

# Here the effective rotation is that evaluated from the PC matrix.

sub _to_RECIPE {
   my $self = shift;
   my $recipe = "QUICK_LOOK";
   my $template = $self->hdr->{"HIERARCH.ESO.TPL.ID"};

   if ( $template eq "ISAACSW_img_obs_AutoJitter" ||
        $template eq "ISAACSW_img_obs_GenericOffset" ) {
      $recipe = "JITTER_SELF_FLAT";
   } elsif ( $template eq "ISAACSW_img_cal_StandardStar" ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";
   } elsif ( $template eq "ISAACSW_img_obs_AutoJitterOffset" ) {
      $recipe = "CHOP_SKY_JITTER";
   }
   return $recipe;
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

# Fixed values for the gain depend on the camera (SW or LW), and for LW
# the readout mode.
sub _to_SPEED_GAIN {
   my $self = shift;
   my $spd_gain;
   my $mode = $self->hdr->{"HIERARCH.ESO.INS.MODE"};
   if ( $mode =~ /SW/ ) {
      $spd_gain = "Normal";
   } else {
      my $readout_mode = $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"};
      if ( $readout_mode =~ /LowBias/ ) {
         $spd_gain = "HiGain";
      } else {
         $spd_gain = "Normal";
      }
   }
   return $spd_gain;
}

sub _to_STANDARD {
   my $self = shift;
   my $standard = 0;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   if ( uc( $type ) eq "STD" ) {
      $standard = 1;
   }
   return $standard;
}

sub _from_STANDARD {
   "STANDARD",  $_[0]->uhdr( "ORAC_STANDARD" );
}

sub _to_UTDATE {
   my $self = shift;

# This is UT start and time.
   my $dateobs = $self->hdr->{"DATE-OBS"};

# Extract out the data in yyyymmdd format.
   return substr( $dateobs, 0, 4 ) . substr( $dateobs, 5, 2 ) . substr( $dateobs, 8, 2 )
}


sub _to_UTEND {
   my $self = shift;

# This is approximate UT in seconds.
   my $endsec = $self->hdr->{UTC} + $self->hdr->{EXPTIME};

# Convert from seconds to decimal hours.
   return $endsec / 3600.0;
}

sub _to_UTSTART {
   my $self = shift;

# This is approximate.
   my $startsec  = $self->hdr->{UTC};

# Convert from seconds to decimal hours.
   return $startsec / 3600.0;
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

sub _to_X_UPPER_BOUND {
   my $self = shift;
   return $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTX"} - 1 + $self->hdr->{"HIERARCH.ESO.DET.WIN.NX"};
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   return $self->hdr->{"HIERARCH.ESO.DET.WIN.STARTY"} - 1 + $self->hdr->{"HIERARCH.ESO.DET.WIN.NY"};
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::ISAAC> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::ISAAC;
   $Grp = new ORAC::Group::ISAAC("group_name");

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
  $group->fixedpart('gisaac');
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
comparing the relative start times of frames. For IRCAM this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

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


  # ORACTIME
  # For ISAAC this is the UTC header value converted to decimal hours
  # and a 12-hour offset to avoid worrying about midnight UT.
  my $time = $self->hdr( "UTC" ) / 3600.0 + 12.0;
  # Just return it (zero if not available)
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # ORACUT
  # For ISAAC this is the UTC header value converted to decimal hours.
  my $ut = $self->hdr( "UTC" ) / 3600.0;
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group::Michelle>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
