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
use ORAC::General;

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
            GRATING_NAME         => "HIERARCH.ESO.INS.GRAT.NAME",
            GRATING_ORDER        => "HIERARCH.ESO.INS.GRAT.ORDER",
            GRATING_WAVELENGTH   => "HIERARCH.ESO.INS.GRAT.WLEN",
            SLIT_NAME            => "HIERARCH.ESO.INS.SLIT",
            X_DIM                => "HIERARCH.ESO.DET.WIN.NX",
            Y_DIM                => "HIERARCH.ESO.DET.WIN.NY",

# then the general.
            AIRMASS_END          => "HIERARCH.ESO.TEL.AIRM.END",
            CHOP_ANGLE           => "HIERARCH.ESO.SEQ.CHOP.POSANGLE",
            CHOP_THROW           => "HIERARCH.ESO.SEQ.CHOP.THROW",
            DEC_BASE             => "DEC",
            EXPOSURE_TIME        => "EXPTIME",
            NUMBER_OF_EXPOSURES  => "HIERARCH.ESO.DET.NDIT",
            NUMBER_OF_READS      => "HIERARCH.ESO.DET.NCORRS",
            OBSERVATION_NUMBER   => "OBSNUM",
            WAVEPLATE_ANGLE      => "HIERARCH.ESO.SEQ.ROT.OFFANGLE",
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::ISAAC->_generate_orac_lookup_methods( \%hdr );

sub _to_AIRMASS_START {
   my $self = shift;
   my $start_airmass = 1.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.TEL.AIRM.START"} ) {
      $start_airmass =  $self->hdr->{"HIERARCH.ESO.TEL.AIRM.START"};
   }
   return $start_airmass;
}

sub _from_AIRMASS_START {
   "HIERARCH.ESO.TEL.AIRM.START", $_[0]->uhdr( "ORAC_AIRMASS_START" );
}

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
      $raoffset = -$x_as * $cosrot + $y_as * $sinrot;
   }
              
# The sense is reversed compared with UKIRT, as these measure the
# place on the sky, not the motion of the telescope.
   return -1.0 * $raoffset;
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

# Equinox may be absent for calibrations such as darks.
sub _to_EQUINOX {
   my $self = shift;
   my $equinox = 0;
   if ( exists $self->hdr->{EQUINOX} ) {
      $equinox = $self->hdr->{EQUINOX};
   }
   return $equinox;
}

# Filter positions 1 and 2 used for SW and 3 & 4 for LW.
sub _to_FILTER {
   my $self = shift;
   my $filter = "Ks";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"} ) {
      $filter = $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"};
   } elsif ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT3.ID"} ) {
      $filter = $self->hdr->{"HIERARCH.ESO.INS.FILT3.ID"};
   }
   return $filter;
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

sub _to_GRATING_DISPERSION {
   my $self = shift;
   my $dispersion = 0.0;
   if ( exists $self->hdr->{CDELT1} ) {
      $dispersion = $self->hdr->{CDELT1};
   } else {
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} &&
           exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"} ) {
         my $order = $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"};
         if ( $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} eq "LR" ) {
            if ( $order == 6 ) {
               $dispersion = 2.36e-4;
            } elsif ( $order == 5 ) {
               $dispersion = 2.83e-4;
            } elsif ( $order == 4 ) {
               $dispersion = 3.54e-4;
            } elsif ( $order == 3 ) {
               $dispersion = 4.72e-4;
            } elsif ( $order == 2 ) {
               $dispersion = 7.09e-4;
            } elsif ( $order == 1 ) {
               if ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"} ) {
                  my $filter = $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"};
                  if ( $filter =~/SL/ ) {
                     $dispersion = 1.412e-3;
                  } else {
                     $dispersion = 1.45e-3;
                  }
               } else {
                 $dispersion = 1.41e-3;
               }
            }

# Medium dispersion
         } elsif ( $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} eq "MR" ) {
            if ( $order == 6 ) {
               $dispersion = 3.7e-5;
            } elsif ( $order == 5 ) {
               $dispersion = 4.6e-5;
            } elsif ( $order == 4 ) {
               $dispersion = 5.9e-5;
            } elsif ( $order == 3 ) {
               $dispersion = 7.8e-5;
            } elsif ( $order == 2 ) {
               $dispersion = 1.21e-4;
            } elsif ( $order == 1 ) {    
               if ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"} ) {       
                  my $filter = $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"};
                  if ( $filter =~/SL/ ) {
                     $dispersion = 2.52e-4;
                  } else {       
                     $dispersion = 2.39e-4;
                  }
               } else {
                 $dispersion = 2.46e-4;
               }
            }   
         }
      }
   }
   return $dispersion;
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
   "HIERARCH.ESO.TPL.NEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
#   "NEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
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
   "HIERARCH.ESO.DPR.TECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
#   "DPRTECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   if ( uc( $type ) eq "STD" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" ) {
      $type = "SKY";
   } elsif ( uc( $type ) eq "LAMP" ) {
      $type = "ARC";
   }
   return $type;
}

sub _from_OBSERVATION_TYPE {
   "HIERARCH.ESO.DPR.TYPE",  $_[0]->uhdr( "ORAC_OBSERVATION_TYPE" );
#   "DPRTYPE",  $_[0]->uhdr( "ORAC_OBSERVATION_TYPE" );
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = $self->hdr->{RA};
   return $ra / 15.0;
}

# Derive the translation between observing template and recipe name.
sub _to_RECIPE {
   my $self = shift;
   my $recipe = "QUICK_LOOK";

# Obtain the observing template.  These are equivalent
# to the UKIRT OT science programmes and their tied DR recipes.
# However, there are some wrinkles and variations to be tested.
   my $template = $self->hdr->{"HIERARCH.ESO.TPL.ID"};
   my $seq = $self->hdr->{"HIERARCH.ESO.TPL.PRESEQ"};

   if ( $template =~ /ISAAC[SL]W_img_obs_AutoJitter/ ||
        $template =~ /ISAAC[SL]W_img_obs_GenericOffset/ ) {
      $recipe = "JITTER_SELF_FLAT";

   } elsif ( $template eq "ISAACSW_img_cal_StandardStar" ||
             $template eq "ISAACLW_img_cal_StandardStarOff" ||
             $template eq "ISAACSW_img_tec_Zp" ||
             $template eq "ISAACLW_img_tec_ZpNoChop" ||
             $seq eq "ISAAC_img_cal_StandardStar" ||
             $seq eq "ISAACLW_img_cal_StandardStarOff" ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";

   } elsif ( $template eq "ISAACSW_img_cal_StandardStar" ||
             $template eq "ISAACLW_img_cal_StandardStarOff" ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";

   } elsif ( $template =~ /ISAAC[SL]W_img_obs_AutoJitterOffset/ ) {
      $recipe = "CHOP_SKY_JITTER";

   } elsif ( $template eq "ISAACLW_img_obs_AutoChopNod" ||
             $seq eq "ISAACLW_img_obs_AutoChopNod" ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK";

   } elsif ( $template eq "ISAACLW_img_cal_Standard_Star" ||
             $template =~ /^ISAACSW_img_tec_Zp/ ||
             $seq eq "ISAACLW_img_cal_Standard_Star" ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK_APHOT";

   } elsif ( $template =~ /ISAAC[SL]W_img_cal_Darks/ ||
             $seq eq "ISAAC_img_cal_Darks" ) {
      $recipe = "REDUCE_DARK";
                       
   } elsif ( $template =~ /ISAAC[SL]W_img_cal_TwFlats/ ) {
      $recipe = "SKY_FLAT_MASKED";

# Imaging spectroscopy.  There appears to be no distinction
# for flats from target, hence no division into POL_JITTER and
# SKY_FLAT_POL.
   } elsif ( $template eq "ISAACSW_img_obs_Polarimetry" ) {
      $recipe = "POL_JITTER";

# Spectroscopy.  EXTENDED_SOURCE may be more appropriate for
# the ISAACSW_spec_obs_GenericOffset template.
   } elsif ( $template =~ /ISAAC[SL]W_spec_obs_AutoNodOnSlit/ ||
             $template =~ /ISAAC[SL]W_spec_obs_GenericOffset/ ||
             $template eq "ISAACLW_spec_obs_AutoChopNod" ) {
      $recipe = "POINT_SOURCE";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_StandardStar/ ||
             $template eq "ISAACLW_spec_cal_StandardStarNod" ) {
      $recipe = "STANDARD_STAR";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_NightCalib/ ) {
      $recipe = "REDUCE_SINGLE_FRAME";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_Arcs/ ||
             $seq eq "ISAAC_spec_cal_Arcs" ) {
      $recipe = "REDUCE_ARC";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_Flats/ ) {
      $recipe = "LAMP_FLAT";
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

# Translate to the SLALIB name for reference frame in spectroscopy.
sub _to_TELESCOPE {
   my $self = shift;
   my $telescope = "VLT1";
   if ( exists $self->hdr->{TELESCOP} ) {
      my $scope = $self->hdr->{TELESCOP};
      if ( defined( $scope ) ) {
         $telescope = $scope;
         $telescope =~ s/ESO-//;
         $telescope =~ s/-U//g;
      }
   }
   return $telescope;
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

   if ( exists $self->hdr->{PC001001} ) {
      my $pc11 = $self->hdr->{PC001001};
      my $pc21 = $self->hdr->{PC002001};
      $rotangle = $dtor * atan2( -$pc21 / $dtor, $pc11 / $dtor );
   } else {
      $rotangle = 180.0;
   }
   return $rotangle;
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
of 'gisaac'.

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
comparing the relative start times of frames.  For UKIRT this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
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
  my $time = $self->get_UT_hours() + 12.0;
  # Just return it (zero if not available)
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # ORACUT
  # For ISAAC this is the UTC header value converted to decimal hours.
  my $ut =  $self->get_UT_hours();
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

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
