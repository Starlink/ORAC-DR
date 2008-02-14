package ORAC::Group::ClassicCam;

=head1 NAME

ORAC::Group::ClassicCam - ClassicCam class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::ClassicCam("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that are
specific to ClassicCam.  It provides a class derived from
B<ORAC::Group::UKIRT>. All the methods available to B<ORAC::Group>
objects are available to B<ORAC::Group::ClassicCam> objects.

=cut

# A package to describe a ClassicCam group object for the
# ORAC-DR pipeline.

use 5.006;
use Carp;

# standard error module and turn on strict
use warnings;
use strict;

use ORAC::Group::UKIRT;
use ORAC::Constants;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation headers for ClassicCam should go here.
my %hdr = (
           AIRMASS_END            => "AIRMASS",
           DEC_TELESCOPE_OFFSET   => "DSECS",
           EQUINOX                => "EQUINOX",
           EXPOSURE_TIME          => "EXPTIME",
           FILTER                 => "FILTER",
           OBJECT                 => "OBJECT",
           OBSERVATION_NUMBER     => "IRPICNO",
           RA_TELESCOPE_OFFSET    => "ASECS",
           SPEED_GAIN             => "SPEED",
           X_DIM                  => "NAXIS1",
           Y_DIM                  => "NAXIS2"
          );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::ClassicCam->_generate_orac_lookup_methods( \%hdr );

sub _to_AIRMASS_START {
   my $self = shift;
   my $airmass = 1.0;
   if ( defined( $self->hdr->{AIRMASS} ) ) {
      $airmass = $self->hdr->{AIRMASS};
   }
   return $airmass;
}

# Convert from sexagesimal d:m:s to decimal degrees.
sub _to_DEC_BASE {
   my $self = shift;
   my $dec = 0.0;
   my $sexa = $self->hdr->{"DEC"};
   if ( defined( $sexa ) ) {
      $dec = $self->dms_to_degrees( $sexa );
   }
   return $dec;
}

# This is N to the top, i.e increasing with pixel index, for
# declinations south of -29 degrees.  It is flipped north of
# -29 degrees.
sub _to_DEC_SCALE {
   my $self = shift;
   my $scale = 0.115;
   my $sexa = $self->hdr->{"DEC"};
   if ( defined( $sexa ) ) {
      my $dec = $self->dms_to_degrees( $sexa );
      if ( $dec > -29 ) {
         $scale *= -1;
      }
   }
   return $scale;
}

sub _to_DETECTOR_READ_TYPE {
   "NDSTARE";
}

sub _to_GAIN {
   7.5; # hardwire in gain for now
}

sub _to_INSTRUMENT {
   "ClassicCam";
}

sub _to_NSCAN_POSITIONS {
   1;
}

sub _to_NUMBER_OF_EXPOSURES {
   1;
}

sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;

# Allow for the UKIRT convention of the final offset to 0,0, and a
# default dither pattern of 5.
   my $noffsets = 6;

# The number of gripu members appears to be given by keyword LOOP.
   if ( defined $self->hdr->{NOFFSETS} ) {
      $noffsets = $self->hdr->{NOFFSETS};
   }

   return $noffsets;
}

sub _to_NUMBER_OF_READS {
   my $self = shift;
   my $reads = 2;
   if ( defined $self->hdr->{READS_EP} && $self->hdr->{PRE_EP} ) {
      $reads = $self->hdr->{READS_EP} + $self->hdr->{PRE_EP};
   }
   return $reads;
}

sub _to_OBSERVATION_MODE {
   "imaging";  # Single imaging mode
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = "OBJECT";
   if ( defined $self->hdr->{OBJECT} ) {
      my $object = uc( $self->hdr->{OBJECT} );
      if ( $object eq "DARK" ) {
         $type = $object;
      } elsif ( $object =~ /FLAT/ ) {
         $type = "FLAT";
      }
   }
   return $type;
}

# Convert from sexagesimal h:m:s to decimal degrees.
sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   my $sexa = $self->hdr->{"RA"};
   if ( defined( $sexa ) ) {
      $ra = $self->hms_to_degrees( $sexa );
   }
   return $ra;
}

# This is E to the right, i.e increasing with pixel index, for
# declinations south of -29 degrees.  It is flipped north of
# -29 degrees.
sub _to_RA_SCALE {
   my $self = shift;
   my $scale = 0.115;
   my $sexa = $self->hdr->{"DEC"};
   if ( defined( $sexa ) ) {
      my $dec = $self->dms_to_degrees( $sexa );
      if ( $dec > -29 ) {
         $scale *= -1;
      }
   }
   return $scale;
}

sub _to_DR_RECIPE {
   my $self = shift;
   my $type = "OBJECT";
   my $recipe = "QUICK_LOOK";
   if ( defined $self->hdr->{OBJECT} ) {
      my $object = uc( $self->hdr->{OBJECT} );
      if ( $object eq "DARK" ) {
         $recipe = "REDUCE_DARK";
      } elsif ( $object =~ /SKY*FLAT/ ) {
         $recipe = "SKY_FLAT_MASKED";
      } elsif ( $object =~ /DOME*FLAT/ ) {
         $recipe = "SKY_FLAT";
      } else {
         $recipe = "JITTER_SELF_FLAT";
      }
   }
   return $recipe;
}

sub _to_ROTATION {
  0; # assume good alignment for now.
}

# Cope with non-standard format in DATE-OBS.  Guessing format is
# ddmmmyy, not supported by Time::DateParse, so parse it.
sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;

# Obtain the start time in seconds.
   return $self->get_UT_hours();
}

sub _from_UTEND {
   my $dechour = $_[0]->uhdr("ORAC_UTEND");
   my ($hour, $minute, $second);
   $hour = int( $dechour );
   $minute = int( ( $dechour - $hour ) * 60 );
   $second = int( ( ( ( $dechour - $hour ) * 60 ) - $minute ) * 60 );
   "UT", ( join ":", $hour, "0" x ( 2 - length( $minute ) ) . $minute,
           "0" x ( 2 - length( $second ) ) . $second );
}

# Derive from the end time, less the exposure time and some
# allowance for the read time.
sub _to_UTSTART {
   my $self = shift;
   my $utstart = $self->_to_UTEND();
   my $nreads = $self->_to_NUMBER_OF_READS();
   my $speed = $self->get_speed_sec();
   if ( defined $self->hdr->{EXPTIME} ) {
      $utstart -= ( $self->hdr->{EXPTIME} + $speed * $nreads ) / 3600.;
   }
   return $utstart;
}

sub _to_X_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return $bounds[ 0 ];
}

sub _to_X_REFERENCE_PIXEL {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return int( ( $bounds[ 0 ] + $bounds[ 2 ] ) / 2 ) + 1;
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return $bounds[ 2 ];
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return $bounds[ 1 ];
}

sub _to_Y_REFERENCE_PIXEL {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return int( ( $bounds[ 1 ] + $bounds[ 3 ] ) / 2 ) + 1;
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->quad_bounds();
   return $bounds[ 3 ];
}


# Supplementary methods for the translations
# ------------------------------------------

# Converts a sky angle specified in d:m:s format into decimal degrees.
# Argument is the sexagesimal format angle.
sub dms_to_degrees {
   my $self = shift;
   my $sexa = shift;
   my $dms;
   if ( defined( $sexa ) ) {
      my @pos = split( /:/, $sexa );
      $dms = $pos[ 0 ] + $pos[ 1 ] / 60.0 + $pos [ 2 ] / 3600.;
   }
   return $dms;
}

# Returns the detector speed in seconds.
sub get_speed_sec {
   my $self = shift;
   my $speed = 0.743;
   if ( exists $self->hdr->{SPEED} ) {
      my $s_speed = $self->hdr->{SPEED};
      $speed = 2.01 if ( $s_speed eq "2.0s" );
      $speed = 1.005 if ( $s_speed eq "1.0s" );
      $speed = 0.743 if ( $s_speed eq "743ms" );
      $speed = 0.405 if ( $s_speed eq "405ms" );
   }
   return $speed;
}

# Returns the UT date in YYYYMMDD format.
sub get_UT_date {
   my $self = shift;
   my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
   my $junk = $self->hdr->{"DATE-OBS"};
   my $day = substr( $junk, 0, 2 );
   my $smonth = substr( $junk, 2, 3 );
   my $mindex = 0;
   while ( $mindex < 11 && uc( $smonth ) ne uc( $months[ $mindex ] ) ) {
      $mindex++;
   }
   $mindex++;
   my $month = "0" x ( 2 - length( $mindex ) ) . $mindex;
   my $year = substr( $junk, 5, 2 );
   if ( $year > 90 ) {
      $year += 1900;
   } else {
      $year += 2000;
   }
   return join "", $year, $month, $day;
}

# Returns the UT time of observation in decimal hours.
sub get_UT_hours {
   my $self = shift;
   if ( exists $self->hdr->{UT} && $self->hdr->{UT} =~ /:/ ) {
      my ($hour, $minute, $second) = split( /:/, $self->hdr->{UT} );
      return $hour + ($minute / 60) + ($second / 3600);
   } else {
      return $self->hdr->{UT};
   }
}

# Converts a sky angle specified in h:m:s format into decimal degrees.
# It takes no account of latitude.  Argument is the sexagesimal format angle.
sub hms_to_degrees {
   my $self = shift;
   my $sexa = shift;
   my $hms;
   if ( defined( $sexa ) ) {
      my @pos = split( /:/, $sexa );
      $hms = 15.0 * ( $pos[ 0 ] + $pos[ 1 ] / 60.0 + $pos [ 2 ] / 3600. );
   }
   return $hms;
}

# Guess for the moment that QUAD 1,2,3,4 correspond to LL, LR, UL, UR
# quadrants, and 5 is thw whole 256x256-pixel array.
sub quad_bounds {
   my $self = shift;
   my @bounds = ( 1, 1, 256, 256 );
   my $quad = $self->hdr->{"QUAD"};
   if ( defined( $quad ) ) {
      if ( $quad < 5 ) {
         $bounds[ 0 ] += 128 * ( $quad + 1 ) % 2;
         $bounds[ 2 ] -= 128 * $quad % 2;
         if ( $quad > 2 ) {
            $bounds[ 1 ] += 128;
         } else {
            $bounds[ 3 ]-= 128;
         }
      }
   }
   return @bounds;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::ClassicCam> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::ClassicCam;
   $Grp = new ORAC::Group::ClassicCam("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gcc'.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required knowledge of
# fixedpart() and filesuffix().
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart( 'gcc' );
   $group->filesuffix( '.sdf' );

# Return the new object.
   return $group;
}

=back

=head2 General Methods

=over 4

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group>

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
