package ORAC::Group::NACO;

=head1 NAME

ORAC::Group::NACO - NACO class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::NACO("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to NACO. It provides a class derived from B<ORAC::Group::ESO>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::NACO> objects. 

=cut

# A package to describe a NACO group object for the
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

sub _to_DEC_SCALE {
   my $self = shift;
   my $scale;
   my $scale_def = 0.0271;
   if ( exists ( $self->hdr->{CDELT2} ) ) {
      $scale = 3600.0 * $self->hdr->{CDELT2};
   } elsif ( exists ( $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) ) {
      $scale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
   }
   $scale = defined( $scale ) ? $scale: $scale_def; 
   return $scale;
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

      my $pixscale = 0.0271;
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) {
         $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      }

# Sometimes the first cumulative offsets are non-zero contrary to the
# documentation.
      my $expno = 1;
      if ( exists $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"} ) {
         $expno = $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"};
      }
      my ( $x_as, $y_as );
      if ( $expno == 1 ) {
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

# Filters appear to be in wheels 4 to 6.  It appears the filter
# in just one of the three.
sub _to_FILTER {
   my $self = shift;
   my $filter = "empty";

   my $id = 4;
   while ( $filter eq "empty" && $id < 7 ) {
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.OPTI${id}.NAME"} ) {
          $filter = $self->hdr->{"HIERARCH.ESO.INS.OPTI${id}.NAME"};
      }
      $id++;
   }
   return $filter;
}

# Fixed value for the gain, as that's all the documentation gives.
# the readout mode.
sub _to_GAIN {
   10;
}

# Using Table 10 of the NACO USer's Guide.
sub _to_GRATING_DISPERSION {
   my $self = shift;
   my $dispersion = 0.0;
   if ( exists $self->hdr->{CDELT1} ) {
      $dispersion = $self->hdr->{CDELT1};
   } else {
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} &&
           exists $self->hdr->{"HIERARCH.ESO.OPTI7.NAME"} ) {
         my $order = $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"};
         my $camera = $self->hdr->{"HIERARCH.ESO.OPTI7.NAME"};

         if ( $camera eq "S54" ) {
            if ( $order == 1 ) {
               $dispersion = 1.98e-3;
            } elsif ( $order == 2 ) {
               $dispersion = 6.8e-4;
            } elsif ( $order == 3 ) {
               $dispersion = 9.7e-4;
            }

         } elsif ( $camera eq "L54" ) {
            $dispersion = 3.20e-3;

         } elsif ( $camera eq "S27" ) {
            if ( $order == 1 ) {
               $dispersion = 9.5e-4;
            } elsif ( $order == 2 ) {
               $dispersion = 5.0e-4;
            }
         }
      }
   }
   return $dispersion;
}

sub _to_RA_SCALE {
   my $self = shift;
   my $scale;
   my $scale_def = -0.0271;
   if ( exists ( $self->hdr->{CDELT1} ) ) {
      $scale = 3600.0 * $self->hdr->{CDELT1};
   } elsif ( exists ( $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) ) {
      $scale = - $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
   }
   $scale = defined( $scale ) ? $scale: $scale_def; 
   return $scale;
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

      my $pixscale = 0.0271;
      if ( exists $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"} ) {
         $pixscale = $self->hdr->{"HIERARCH.ESO.INS.PIXSCALE"};
      }

# Sometimes the first cumulative offsets are non-zero contrary to the
# documentation.
      my $expno = 1;
      if ( exists $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"} ) {
         $expno = $self->hdr->{"HIERARCH.ESO.TPL.EXPNO"};
      }
      my ( $x_as, $y_as );
      if ( $expno == 1 ) {
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

   if ( $template =~ /_img_obs_AutoJitter/ ||
        $template =~ /_img_obs_GenericOffset/ ) {
      $recipe = "JITTER_SELF_FLAT";

   } elsif ( $template =~ /_img_cal_StandardStar/ ||
             $template =~ /_img_cal_StandardStarOff/ ||
             $template =~ /_img_tec_Zp/ ||
             $template =~ /_img_tec_ZpNoChop/ ||
             $seq =~ /_img_cal_StandardStar/ ||
             $seq =~ /_img_cal_StandardStarOff/ ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";

   } elsif ( $template =~ /_img_obs_AutoJitterOffset/ ||
             $template =~ /_img_obs_FixedSkyOffset/ ) {
      $recipe = "CHOP_SKY_JITTER";

# The following two perhaps should be using NOD_CHOP and a variant of
# NOD_CHOP_APHOT to cope with the three source images (central double
# flux) rather than four.
   } elsif ( $template =~ /_img_obs_AutoChopNod/ ||
             $seq =~ /_img_obs_AutoChopNod/ ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK";

   } elsif ( $template =~ /_img_cal_ChopStandardStar/ ) {
      $recipe = "NOD_SELF_FLAT_NO_MASK_APHOT";

   } elsif ( $template =~ /_cal_Darks/ ||
             $seq =~ /_cal_Darks/ ) {
      $recipe = "REDUCE_DARK";

   } elsif ( $template =~ /_img_cal_TwFlats/ ||
             $template =~ /_img_cal_SkyFlats/ ) {
      $recipe = "SKY_FLAT_MASKED";

   } elsif ( $template =~ /_img_cal_LampFlats/ ) {
      $recipe = "LAMP_FLAT";

# Imaging spectroscopy.  There appears to be no distinction
# for flats from target, hence no division into POL_JITTER and
# SKY_FLAT_POL.
   } elsif ( $template =~ /_pol_obs_GenericOffset/ ||
             $template =~ /_pol_cal_StandardStar/ ) {
      $recipe = "POL_JITTER";

   } elsif ( $template =~ /_pol_obs_AutoChopNod/ ||
             $template =~ /_pol_cal_ChopStandardStar/ ) {
      $recipe = "POL_NOD_CHOP";

   } elsif ( $template =~ /_pol_cal_LampFlats/ ) {
      $recipe = "POL_JITTER";

# Spectroscopy.  EXTENDED_SOURCE may be more appropriate for
# the NACO_spec_obs_GenericOffset template.
   } elsif ( $template =~ /_spec_obs_AutoNodOnSlit/ ||
             $template =~ /_spec_obs_GenericOffset/ ||
             $template =~ /_spec_obs_AutoChopNod/ ) {
      $recipe = "POINT_SOURCE";

   } elsif ( $template =~ /_spec_cal_StandardStar/ ||
             $template =~ /_spec_cal_StandardStarNod/ ||
             $template =~ /_spec_cal_AutoNodOnSlit/  ) {
      $recipe = "STANDARD_STAR";

   } elsif ( $template =~ /_spec_cal_NightCalib/ ) {
      $recipe = "REDUCE_SINGLE_FRAME";

   } elsif ( $template =~ /_spec_cal_Arcs/ ||
             $seq =~ /_spec_cal_Arcs/ ) {
      $recipe = "REDUCE_ARC";

   } elsif ( $template =~ /_spec_cal_LampFlats/ ) {
      $recipe = "LAMP_FLAT";
   }
   return $recipe;
}

# Just translate to shorter strings for ease and to fit within the
# night log.
sub _to_SPEED_GAIN {
   my $self = shift;
   my $spd_gain = "HighSens";
   my $detector_mode = exists( $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} ) ?
                       $self->hdr->{"HIERARCH.ESO.DET.MODE.NAME"} : $spd_gain; 
   if ( $detector_mode eq "HighSensitivity" ) {
      $spd_gain = "HighSens";
   } elsif ( $detector_mode eq "HighDynamic" ) {
      $spd_gain = "HighDyn";
   } elsif ( $detector_mode eq "HighBackground" ) {
      $spd_gain = "HighBack";
   }
   return $spd_gain;
}

# Translate to the SLALIB name for reference frame in spectroscopy.
sub _to_TELESCOPE {
   my $self = shift;
   my $telescope = "VLT4";
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

Create a new instance of a B<ORAC::Group::NACO> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::NACO;
   $Grp = new ORAC::Group::NACO("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gnaco'.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required
# knowledge of fixedpart() and filesuffix().
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart('gnaco');
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
