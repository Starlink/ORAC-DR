package ORAC::Group::SOFI;

=head1 NAME

ORAC::Group::SOFI - SOFI class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::SOFI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to SOFI. It provides a class derived from B<ORAC::Group::ESO>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::SOFI> objects. 

=cut

# A package to describe a SOFI group object for the
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

      my $pixscale = 0.144;
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

# Filter positions 1 and 2 used.
sub _to_FILTER {
   my $self = shift;
   my $filter = "";
   my $filter1 = "open";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"} ) {
      $filter1 = $self->hdr->{"HIERARCH.ESO.INS.FILT1.ID"};
   }

   my $filter2 = "open";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.FILT2.ID"} ) {
      $filter2 = $self->hdr->{"HIERARCH.ESO.INS.FILT2.ID"};
   }

   if ( $filter1 eq "open" ) {
      $filter = $filter2;
   }

   if ( $filter2 eq "open" ) {
      $filter = $filter1;
   }

   if ( ( $filter1 eq "blank" ) ||
        ( $filter2 eq "blank" ) ) {
      $filter = "blank";
   }
   return $filter;
}


# Fixed values for the gain depend on the camera (SW or LW), and for LW
# the readout mode.
sub _to_GAIN {
   my $self = shift;
   my $gain = 5.4;
   return $gain;
}

# Dispersion in microns per pixel.
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
            if ( lc($order) eq "blue" ) {
               $dispersion = 6.96e-4;
            } else {
               $dispersion = 1.022e-3;
            }

# Medium dispersion
         } elsif ( $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} eq "MR" ) {
            if ( $order == 8 ) {
               $dispersion = 1.58e-4;
            } elsif ( $order == 7 ) {
               $dispersion = 1.87e-4;
            } elsif ( $order == 6 ) {
               $dispersion = 2.22e-5;
            } elsif ( $order == 5 ) {
               $dispersion = 2.71e-5;
            } elsif ( $order == 4 ) {
               $dispersion = 3.43e-5;
            } elsif ( $order == 3 ) {
               $dispersion = 4.62e-5;
            }
         }
      }
   }
   return $dispersion;
}     

# Cater for OBJECT keyword with unhelpful value.
sub _to_OBJECT {
   my $self = shift;
   my $object = undef;

# The object name should be in OBJECT...
   if ( exists $self->hdr->{OBJECT} ) {
      $object = $self->hdr->{OBJECT};

# Sometimes it's the generic STD for standard.
      if ( $object =~ /STD/ ) {
         if ( exists $self->hdr->{"HIERARCH.ESO.OBS.TARG.NAME"} ) {
            $object = $self->hdr->{"HIERARCH.ESO.OBS.TARG.NAME"};
         } else {
            $object = undef;
         }
      }
   }
   return $object;
}

# FLAT and DARK need no change.
sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   $type = exists( $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} ) ? $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} : "OBJECT";

   my $cat = $self->hdr->{"HIERARCH.ESO.DPR.CATG"};
   $cat = exists( $self->hdr->{"HIERARCH.ESO.DPR.CATG"} ) ? $self->hdr->{"HIERARCH.ESO.DPR.CATG"} : "SCIENCE";

   if ( uc( $type ) eq "STD" || uc( $cat ) eq "SCIENCE" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" || uc( $type ) eq "FLAT,SKY" ||
             uc( $cat ) eq "OTHER" ) {
      $type = "SKY";
   } elsif ( uc( $type ) eq "LAMP,FLAT" || uc( $type ) eq "FLAT,LAMP" ) {
      $type = "LAMP";
   } elsif ( uc( $type ) eq "LAMP" ) {
      $type = "ARC";
   } elsif ( uc( $type ) eq "OTHER" ) {
      $type = "OBJECT";
   }
   return $type;
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

      my $pixscale = 0.144;
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
sub _to_RECIPE {
   my $self = shift;
   my $recipe = "QUICK_LOOK";

# Obtain the observing template.  These are equivalent
# to the UKIRT OT science programmes and their tied DR recipes.
# However, there are some wrinkles and variations to be tested.
   my $template = $self->hdr->{"HIERARCH.ESO.TPL.ID"};
   my $seq = $self->hdr->{"HIERARCH.ESO.TPL.PRESEQ"};
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};

   if ( $template eq "SOFI_img_obs_AutoJitter" ||
        $template eq "SOFI_img_obs_Jitter" ||
        $template eq "SOFI_img_obs_GenericOffset" ) {
      if ( $type eq "STD" ) {
         $recipe = "JITTER_SELF_FLAT_APHOT";
      } else {
         $recipe = "JITTER_SELF_FLAT";
      }

   } elsif ( $template eq "SOFI_img_cal_StandardStar" ||
             $template eq "SOFI_img_tec_Zp" ||
             $seq eq "SOFI_img_cal_StandardStar" ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";

   } elsif ( $template eq "SOFI_img_obs_AutoJitterOffset" ||
             $template eq "SOFI_img_obs_JitterOffset" ) {
      $recipe = "CHOP_SKY_JITTER";

   } elsif ( $template eq "SOFI_img_cal_Darks" ||
             $seq eq "SOFI_img_cal_Darks" ) {
      $recipe = "REDUCE_DARK";

   } elsif ( $template eq "SOFI_img_cal_DomeFlats" ||
             $template eq "SOFI_img_cal_DomeFlats" ||
             $template eq "SOFI_img_cal_SpecialDomeFlats" ) {
      $recipe = "SKY_FLAT_MASKED";

# Imaging spectroscopy.  There appears to be no distinction
# for flats from target, hence no division into POL_JITTER and
# SKY_FLAT_POL.
   } elsif ( $template eq "SOFI_img_obs_Polarimetry" ||
             $template eq "SOFI_img_cal_Polarimetry" ) {
      $recipe = "POL_JITTER";

# Spectroscopy.  EXTENDED_SOURCE may be more appropriate for
# the SOFISW_spec_obs_GenericOffset template.
   } elsif ( $template eq "SOFI_spec_obs_AutoNodOnSlit" ||
             $template eq "SOFI_spec_obs_AutoNodNonDestr" ) {
      $recipe = "POINT_SOURCE";

   } elsif ( $template eq "SOFI_spec_cal_StandardStar" ||
             $template eq "SOFI_spec_cal_AutoNodOnSlit"  ) {
      $recipe = "STANDARD_STAR";

   } elsif ( $template eq "SOFI_spec_cal_NightCalib" ) {
      $recipe = "REDUCE_SINGLE_FRAME";

   } elsif ( $template eq "SOFI_spec_cal_Arcs" ||
             $seq eq "SOFI_spec_cal_Arcs" ) {
      $recipe = "REDUCE_ARC";

   } elsif ( $template eq "SOFI_spec_cal_DomeFlats" ||
             $template eq "SOFI_spec_cal_NonDestrDomeFlats" ) {
      $recipe = "LAMP_FLAT";
   }
   return $recipe;
}

# Fixed value for the gain.
sub _to_SPEED_GAIN {
   my $self = shift;
   my $spd_gain = "Normal";
   return $spd_gain;
}

# Translate to the SLALIB name for reference frame in spectroscopy.
sub _to_TELESCOPE {
   my $self = shift;
   my $telescope = "NTT";
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

Create a new instance of a B<ORAC::Group::SOFI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::SOFI;
   $Grp = new ORAC::Group::SOFI("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gsofi'.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required
# knowledge of fixedpart() and filesuffix().
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart('gsofi');
   $group->filesuffix('.sdf');

# Return the new object.
   return $group;
}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC
# headers.
   my %new = $self->SUPER::calc_orac_headers;
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

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
