package ORAC::Frame::ClassicCam;

=head1 NAME

ORAC::Frame::ClassicCam - Class for dealing with Magellan ClassicCam observation frames

=head1 SYNOPSIS

  use ORAC::Frame::ClassicCam;

  $Frm = new ORAC::Frame::ClassicCam("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ClassicCam. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame>
objects are available to B<ORAC::Frame::ClassicCam> objects.

The class only deals with the NDF form of ClassicCam data rather than the
native FITS format (the pipeline forces a conversion as soon as the
data are located).

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use ORAC::Print qw/orac_warn/;
use ORAC::Constants;

our $VERSION;

use base qw/ORAC::Frame::UKIRT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

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
ORAC::Frame::ClassicCam->_generate_orac_lookup_methods( \%hdr );

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

sub _to_RECIPE {
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

# Returns the UT date in YYYYMMDD format.
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

# Returns the detector speed in seconds.
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
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::ClassicCam> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::ClassicCam;
   $Frm = new ORAC::Frame::ClassicCam("file_name");
   $Frm = new ORAC::Frame::ClassicCam("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'cc' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {
   my $proto = shift;
   my $class = ref( $proto ) || $proto;

# Run the base class constructor with a hash reference
# defining additions to the class.  Do not supply user-arguments
# yet. This is because if we do run configure via the constructor
# the rawfixedpart and rawsuffix will be undefined.
   my $self = $class->SUPER::new();

# Configure initial state - could pass these in with
# the class initialisation hash - this assumes that I know
# the hash member name
   $self->rawfixedpart( 'cc' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number.
   $self->configure( @_ ) if @_;

   return $self;
}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames.  For Magellan this
number is decimal hours + 12.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.  It returns a hash containing the new
keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC_
# headers
   my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# --------
# For ClassicCam this is the UTC header value converted to decimal hours
# and a 12-hour offset to avoid worrying about midnight UT.
   my $time = $self->get_UT_hours() + 12.0;

# Just return it (zero if not available).
   $time = 0 unless ( defined $time );
   $self->hdr( 'ORACTIME', $time );

   $new{'ORACTIME'} = $time;

# ORACUT
# ------
# Get the UT date.
   my $ut = $self->get_UT_date();
   $ut = 0 unless defined $ut;
   $self->hdr( 'ORACUT', $ut );

   $new{'ORACUT'} = $ut;

   return %new;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For ClassicCam the raw filename after pressing by cc2oracdr.csh is
of the form:

  ccYYYYMMDD_NNNNN.sdf

where the number is 0 padded.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# Zero pad the number.
   $obsnum = sprintf( "%05d", $obsnum );

# Temporary ClassicCam UKIRT-like form form is fixed prefix _ num suffix
   return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

   my $self = shift;

   my $amiagroup;
   my $hdrgrp;

   $hdrgrp = $self->hdr('GRPNUM');
   if ($self->hdr('GRPMEM')) {
      $amiagroup = 1;
   } elsif (!defined $self->hdr('GRPMEM')){
      $amiagroup = 1;
   } else {
      $amiagroup = 0;
   }

# Is this group name set to anything useful
  if ( !$hdrgrp || !$amiagroup ) {

# If the group is invalid there is not a lot we can do about
# it except for the case of certain calibration objects that
# we know are the only members of their group (e.g. DARK).

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
#    }

  }

  $self->group( $hdrgrp );

  return $hdrgrp;

}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix. The input filename is chopped at the
underscore and the suffix appended. The suffix is simply appended
if there is no underscore.

Note that this method does not set the new output name in this
object. This must still be done by the user.

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Therefore if in=file_db and suffix=_ff then out would
become file_db_ff but if in=file_db_ff and suffix=dk then
out would be file_db_dk.

An optional second argument can be used to specify the
file number to be used. Default is for this method to process
the contents of file(1).

  ($in, $out) = $Frm->inout($suffix, 2);

will return the second file name and the name of the new output
file derived from this.

The last suffix is not removed if it consists solely of numbers.
This is to prevent truncation of raw data filenames.

=cut

=item B<mergehdr>

Dummy method.

  $frm->mergehdr();

=cut

sub mergehdr {

}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
   my $self = shift;
   my $template = shift;

   my $num = $self->number;

# Pad with leading zeroes for a 5-digit obsnum.
   $num = "0" x ( 5 - length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>

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
