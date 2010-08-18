package ORAC::Frame::SOFI;

=head1 NAME

ORAC::Frame::SOFI - SOFI class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::SOFI;

  $Frm = new ORAC::Frame::SOFI("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to SOFI. It provides a class derived from
B<ORAC::Frame::ESO>.  All the methods available to B<ORAC::Frame::ESO>
objects are available to B<ORAC::Frame::SOFI> objects.

=cut

# A package to describe a SOFI frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use Math::Trig;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::ESO;
use base  qw/ORAC::Frame::ESO/;

# NDF module for mergehdr
use NDF;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
$VERSION = '1.0';

# Instrument-specific translations.
# =================================

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoffset = 0.0;
   if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"} ) {
      $decoffset = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETD"};

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} ||
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

# Obtain the x-y offsets in arcsecs.
      my ($x_as, $y_as) = $self->xy_offsets();

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
   my $order = 0;
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"} ) {
      $order = $self->hdr->{"HIERARCH.ESO.INS.GRAT.ORDER"};
    }
    if ( $self->_to_GRATING_NAME eq "LR" ) {
      if ( lc( $order ) eq "blue" || $self->_to_FILTER eq "GBF" ) {
         $dispersion = 6.96e-4;
      } else {
         $dispersion = 1.022e-3;
      }

# Medium dispersion
   } elsif ( $self->_to_GRATING_NAME eq "MR" ) {
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
   return $dispersion;
}

sub _to_GRATING_NAME{
   my $self = shift;
   my $name = "MR";
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"} ) {
      $name = $self->hdr->{"HIERARCH.ESO.INS.GRAT.NAME"};

# Name is missing for low resolution.
   } elsif ( $self->_to_FILTER =~ /^G[BR]F/ ) {
      $name = "LR";
   }
   return $name;
}

sub _to_GRATING_WAVELENGTH{
   my $self = shift;
   my $wavelength = 0;
   if ( exists $self->hdr->{"HIERARCH.ESO.INS.GRAT.WLEN"} ) {
      $wavelength = $self->hdr->{"HIERARCH.ESO.INS.GRAT.WLEN"};

# Wavelength is missing for low resolution.
   } elsif ( $self->_to_FILTER =~ /^GBF/ ) {
      $wavelength = 1.3;
   } elsif ( $self->_to_FILTER =~ /^GRF/ ) {
      $wavelength = 2.0;
   }
   return $wavelength;
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

sub _to_NUMBER_OF_READS {
   my $self = shift;
   my $number = 2;
   if ( exists $self->hdr->{"HIERARCH.ESO.DET.NCORRS"} ) {
      $number = $self->hdr->{"HIERARCH.ESO.DET.NCORRS"};
   }
   return $number;
}

# FLAT and DARK need no change.
sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{"HIERARCH.ESO.DPR.TYPE"};
   $type = exists( $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} ) ? $self->hdr->{"HIERARCH.ESO.DPR.TYPE"} : "OBJECT";

   my $cat = $self->hdr->{"HIERARCH.ESO.DPR.CATG"};
   $cat = exists( $self->hdr->{"HIERARCH.ESO.DPR.CATG"} ) ? $self->hdr->{"HIERARCH.ESO.DPR.CATG"} : "SCIENCE";

   if ( uc( $cat ) eq "TEST" ) {
      $type = "TEST";
   } elsif ( uc( $type ) eq "STD" || uc( $cat ) eq "SCIENCE" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" || uc( $type ) eq "FLAT,SKY" ||
             uc( $cat ) eq "OTHER" ) {
      $type = "SKY";
   } elsif ( uc( $type ) eq "LAMP,FLAT" || uc( $type ) eq "FLAT,LAMP" ||
             uc( $type ) eq "FLAT" ) {
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

   } elsif ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} ||
             exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {

# Obtain the x-y offsets in arcsecs.
      my ($x_as, $y_as) = $self->xy_offsets();

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

   } elsif ( $template eq "SOFI_img_cal_DomeFlats" ) {
      $recipe = "DOME_FLAT";

   } elsif ( $template eq "SOFI_img_cal_SpecialDomeFlats" ) {
      $recipe = "SPECIAL_DOME_FLAT";

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
   my $telescope = "ESONTT";
   if ( exists $self->hdr->{TELESCOP} ) {
      my $scope = $self->hdr->{TELESCOP};
      if ( defined( $scope ) ) {
         $telescope = $scope;
         $telescope =~ s/-U//g;
         $telescope =~ s/-//;
      }
   }
   return $telescope;
}

# Supplementary methods for the translations
# ------------------------------------------
sub xy_offsets {
   my $self = shift;
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
   my $x_as = 0.0;
   my $y_as = 0.0;
   my $mode = uc( $self->get_instrument_mode() );
   if ( !( $expno == 1 && ( $mode eq "IMAGE" || $mode eq "POLARIMETRY" ) ) ) {
      if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} ) {
         $x_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETX"} * $pixscale;
      }
      if ( exists $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} ) {
         $y_as = $self->hdr->{"HIERARCH.ESO.SEQ.CUMOFFSETY"} * $pixscale;
      }
   }
   return ($x_as, $y_as);
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::SOFI object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::SOFI;
   $Frm = new ORAC::Frame::SOFI("file_name");
   $Frm = new ORAC::Frame::SOFI("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'm' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Run the base-class constructor with a hash reference defining
# additions to the class.   Do not supply user-arguments yet.
# This is because if we do run configure via the constructor
# the rawfixedpart and rawsuffix will be undefined.
   my $self = $class->SUPER::new();

# Configure the initial state---could pass these in with
# the class initialisation hash---this assumes that we know
# the hash member name.
#   $self->rawfixedpart( 'SOFI.' );
#   $self->rawsuffix( '.fits' );
#   $self->rawformat( 'FITS' );
   $self->rawfixedpart( 'sofi' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );

# SOFI is really a single frame instrument.  So this should be
# "NDF" and we should be inheriting from UFTI
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number.
   $self->configure(@_) if @_;

   return $self;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Frame::ESO>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
