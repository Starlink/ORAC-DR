package ORAC::Frame::ISAAC;

=head1 NAME

ORAC::Frame::ISAAC - ISAAC class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::ISAAC;

  $Frm = new ORAC::Frame::ISAAC("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ISAAC. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::ISAAC> objects.

=cut

# A package to describe a ISAAC group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::Michelle/;

# NDF module for mergehdr
use NDF;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for ISAAC should go here.
# First the imaging...
my %hdr = (
            DEC_SCALE            => "CDELT1",
            RA_SCALE             => "CDELT2",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "GRATENC",
            GRATING_DISPERSION   => "CDELT1",
            GRATING_NAME         => "GRATNAME",
            GRATING_ORDER        => "GRAORDER",
            GRATING_WAVELENGTH   => "GRATWLEN",
            SLIT_ANGLE           => "SLITANG",
            SLIT_NAME            => "SLIT",
            X_DIM                => "WINNX",
            Y_DIM                => "WINNY",

# then the general.
            AIRMASS_START        => "SAIRMASS",
            AIRMASS_END          => "EAIRMASS",
            CHOP_ANGLE           => "CHPANGLE",
            CHOP_THROW           => "CHPTHROW",
            DEC_BASE             => "DEC",
            EXPOSURE_TIME        => "EXPTIME",
            FILTER               => "FILTER",
            NUMBER_OF_EXPOSURES  => "DETNDIT",
            NUMBER_OF_READS      => "NCORRS",
            OBSERVATION_NUMBER   => "OBSNUM",
            WAVEPLATE_ANGLE      => "WPLANGLE",
            X_LOWER_BOUND        => "STARTX",
            Y_LOWER_BOUND        => "STARTY"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Frame::ISAAC->_generate_orac_lookup_methods( \%hdr );

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoffset = 0.0;
   if ( exists $self->hdr->{OFFSETD} ) {
      $decoffset = $self->hdr->{OFFSETD};

   } elsif ( exists $self->hdr->{OFFSETX} &&
             exists $self->hdr->{OFFSETY} ) {

      my $pixscale = $self->hdr->{PIXSCALE};
      my $x_as = $self->hdr->{OFFSETX} * $pixscale;
      my $y_as = $self->hdr->{OFFSETY} * $pixscale;

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
   if ( exists $self->hdr->{OFFSETA} ) {
      $raoffset = $self->hdr->{OFFSETA};

   } elsif ( exists $self->hdr->{OFFSETX} &&
             exists $self->hdr->{OFFSETY} ) {

      my $pixscale = $self->hdr->{PIXSCALE};
      my $x_as = $self->hdr->{OFFSETX} * $pixscale;
      my $y_as = $self->hdr->{OFFSETY} * $pixscale;

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
sub to_DETECTOR_READ_TYPE {
   my $self = shift;
   my $read_type;
   my $chop = $self->hdr->{CHOPSTAT};
   my $readout_mode = $self->hdr->{DETMODE};
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
   my $mode = $self->hdr->{INSMODE};
   if ( $mode =~ /SW/ ) {
      $gain = 4.6;
   } else {
      my $readout_mode = $self->hdr->{DETMODE};
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
   return $self->hdr->{TPLNEXP} + 1;
}
            
sub _from_NUMBER_OF_OFFSETS {
   "TPLNEXP",  $_[0]->uhdr( "ORAC_NUMBER_OF_OFFSETS" ) - 1;
}

sub _to_OBSERVATION_MODE {
   my $self = shift;
   my $mode = $self->hdr->{DPRTECH};
   if ( uc( $mode ) eq "IMAGE" ) {
      $mode = "imaging";
   } else {
      $mode = "spectroscopy";
   }
   return $mode;
}

sub _from_OBSERVATION_MODE {
   "DPRTECH",  $_[0]->uhdr( "ORAC_OBSERVATION_MODE" );
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = $self->hdr->{DPRTYPE};
   if ( uc( $type ) eq "STD" ) {
      $type = "OBJECT";
   } elsif ( uc( $type ) eq "SKY,FLAT" )  {
      $type = "SKY";
   }
   return $type;
}

sub _from_OBSERVATION_TYPE {
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
   my $template = $self->hdr->{TEMPLATE};

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
   my $mode = $self->hdr->{INSMODE};
   if ( $mode =~ /SW/ ) {
      $spd_gain = "Normal";
   } else {
      my $readout_mode = $self->hdr->{DETMODE};
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
   my $type = $self->hdr->{DPRTYPE};
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
   } elsif ( exists $self->hdr->{STARTX} && exists $self->hdr->{WINNX} ) {
      my $xl = $self->hdr->{STARTX};
      my $xu = $self->hdr->{WINNX};
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
   } elsif ( exists $self->hdr->{STARTY} && exists $self->hdr->{WINNY} ) {
      my $yl = $self->hdr->{STARTY};
      my $yu = $self->hdr->{WINNY};
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
   return $self->hdr->{STARTX} - 1 + $self->hdr->{WINNX};
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   return $self->hdr->{STARTY} - 1 + $self->hdr->{WINNY};
}

# Sampling is always 1x1, and therefore there are no headers with
# these values.

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::ISAAC object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::ISAAC;
   $Frm = new ORAC::Frame::ISAAC("file_name");
   $Frm = new ORAC::Frame::ISAAC("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'm' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('isaac');
  $self->rawsuffix('.sdf');
  $self->rawformat('NDF');

  # ISAAC is really a single frame instrument
  # So this should be "NDF" and we should be inheriting
  # from UFTI
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
