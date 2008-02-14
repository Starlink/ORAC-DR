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
are specific to ISAAC. It provides a class derived from B<ORAC::Group::ESO>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::ISAAC> objects. 

=cut

# A package to describe a ISAAC group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;

use Math::Trig;
use ORAC::Group::UKIRT;
use ORAC::Print;
use ORAC::General;

# Set inheritance
use base qw/ORAC::Group::ESO/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Instrument-specific translations.
# =================================

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoffset = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"} ) {
      $decoffset = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"};

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} &&
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

      my $pixscale = 0.148;
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) {
         $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      }

# Sometimes the first imaging cumulative offsets are non-zero contrary
# to the documentation.
      my $expno = 1;
      if ( exists $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"} ) {
         $expno = $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"};
      }
      my ( $x_as, $y_as );
      my $mode = uc( $self->get_instrument_mode() );
      if ( $expno == 1 && ( $mode eq "IMAGE" || $mode eq "POLARIMETRY" ) ) {
         $x_as = 0.0;
         $y_as = 0.0;
      } else {
         $x_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} * $pixscale;
         $y_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} * $pixscale;
      }

# Define degrees to radians conversion and obtain the rotation angle.
      my $dtor = atan2( 1, 1 ) / 45.0;

      my $rotangle = $self->rotation();
      my $cosrot = cos( $rotangle * $dtor );
      my $sinrot = sin( $rotangle * $dtor );

# Apply the rotation matrix to obtain the equatorial pixel offset.
      $decoffset = -$x_as * $sinrot + $y_as * $cosrot;
   }
              
# The sense is reversed compared with UKIRT, as these measure the
# place on the sky, not the motion of the telescope.
   return -1.0 * $decoffset;
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
   my $gain = 4.6;
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.MODE"} ) {
      if ( $self->hdr->{"HIERARCH.ESO.INS.MODE"} =~ /SW/ ) {
         $gain = 4.6;
      } else {
         if ( exists $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} ) {
            if ( $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} =~ /LowBias/ ) {
               $gain = 8.7;
            } else {
               $gain = 7.8;
            }
         }
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

# If the telescope offset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_RA_TELESCOPE_OFFSET {
   my $self = shift;
   my $raoffset = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETA"} ) {
      $raoffset = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETA"};

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} &&
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

      my $pixscale = 0.148;
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) {
         $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      }

# Sometimes the first imaging cumulative offsets are non-zero contrary
# to the documentation.
      my $expno = 1;
      if ( exists $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"} ) {
         $expno = $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"};
      }
      my ( $x_as, $y_as );
      my $mode = uc( $self->get_instrument_mode() );
      if ( $expno == 1 && ( $mode eq "IMAGE" || $mode eq "POLARIMETRY" ) ) {
         $x_as = 0.0;
         $y_as = 0.0;
      } else {
         $x_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} * $pixscale;
         $y_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} * $pixscale;
      }

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

# Derive the translation between observing template and recipe name.
sub _to_DR_RECIPE {
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

   } elsif ( $template =~ /ISAAC[SL]W_img_obs_AutoJitterOffset/ ) {
      $recipe = "CHOP_SKY_JITTER";

# The following two perhaps should be using NOD_CHOP and a variant of
# NOD_CHOP_APHOT to cope with the three source images (central double
# flux) rather than four.
   } elsif ( $template eq "ISAACLW_img_obs_AutoChopNod" ||
             $seq eq "ISAACLW_img_obs_AutoChopNod" ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK";

   } elsif ( $template eq "ISAACLW_img_cal_StandardStar" ||
             $template =~ /^ISAACLW_img_tec_Zp/ ||
             $seq eq "ISAACLW_img_cal_StandardStar" ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK_APHOT";

   } elsif ( $template =~ /ISAAC[SL]W_img_cal_Darks/ ||
             $seq eq "ISAAC_img_cal_Darks" ) {
      $recipe = "REDUCE_DARK";

   } elsif ( $template =~ /ISAAC[SL]W_img_cal_TwFlats/ ) {
      $recipe = "SKY_FLAT_MASKED";

# Imaging spectroscopy.  There appears to be no distinction
# for flats from target, hence no division into POL_JITTER and
# SKY_FLAT_POL.
   } elsif ( $template eq "ISAACSW_img_obs_Polarimetry" ||
             $template eq "ISAACSW_img_cal_Polarimetry" ) {
      $recipe = "POL_JITTER";

# Spectroscopy.  EXTENDED_SOURCE may be more appropriate for
# the ISAACSW_spec_obs_GenericOffset template.
   } elsif ( $template =~ /ISAAC[SL]W_spec_obs_AutoNodOnSlit/ ||
             $template =~ /ISAAC[SL]W_spec_obs_GenericOffset/ ||
             $template eq "ISAACLW_spec_obs_AutoChopNod" ) {
      $recipe = "POINT_SOURCE";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_StandardStar/ ||
             $template eq "ISAACLW_spec_cal_StandardStarNod" ||
             $template =~ /ISAAC[SL]W_spec_cal_AutoNodOnSlit/  ) {
      $recipe = "STANDARD_STAR";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_NightCalib/ ) {
      if ( $self->_to_OBSERVATION_TYPE() eq "LAMP" ) {
         $recipe = "LAMP_FLAT";
      } elsif ( $self->_to_OBSERVATION_TYPE() eq "ARC" ) {
         $recipe = "REDUCE_ARC";
      } else {
         $recipe = "REDUCE_SINGLE_FRAME";
      }

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_Arcs/ ||
             $seq eq "ISAAC_spec_cal_Arcs" ) {
      $recipe = "REDUCE_ARC";

   } elsif ( $template =~ /ISAAC[SL]W_spec_cal_Flats/ ) {
      $recipe = "LAMP_FLAT";
   }
   return $recipe;
}

# Fixed values for the gain depend on the camera (SW or LW), and for LW
# the readout mode.
sub _to_SPEED_GAIN {
   my $self = shift;
   my $spd_gain = "Normal";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.MODE"} ) {
      if ( $self->hdr->{"HIERARCH.ESO.INS.MODE"} =~ /SW/ ) {
         $spd_gain = "Normal";
      } else {
         if ( exists $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} ) {
            if ( $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} =~ /LowBias/ ) {
               $spd_gain = "HiGain";
            } else {
               $spd_gain = "Normal";
            }
         }
      }
   }
   return $spd_gain;
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
# knowledge of fixedpart() and filesuffix().
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart('gisaac');
   $group->filesuffix('.sdf');

# Return the new object.
   return $group;
}

=back

=head2 General Methods

=over 4

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
