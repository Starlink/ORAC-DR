package ORAC::Frame::INGRID;

=head1 NAME

ORAC::Frame::INGRID - INGRID class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::INGRID;

  $Frm = new ORAC::Frame::INGRID("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to INGRID. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::INGRID> objects.

=cut

# A package to describe a INGRID group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::CGS4/;

# NDF module and object-copying task for inout. 
use NDF;
use Starlink::HDSPACK qw/copobj/;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

*pattern_from_bits = \&file_from_bits;

# Translation tables for INGRID should go here.
# First the imaging...
my %hdr = (

# then the general.
            AIRMASS_END          => "AIRMASS",
            AIRMASS_START        => "AIRMASS",
            EXPOSURE_TIME        => "EXPTIME",
            FILTER               => "INGF1NAM",
            INSTRUMENT           => "DETECTOR",
            NUMBER_OF_EXPOSURES  => "COAVERAG",
            NUMBER_OF_READS      => "NUMREADS",
            OBSERVATION_NUMBER   => "RUN"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Frame::INGRID->_generate_orac_lookup_methods( \%hdr );

sub _to_DEC_SCALE {
   my $self = shift;
   my $decscale = 0.2387;

# Assumes either x-y scales the same or the y corresponds to
# declination.
   if ( exists $self->hdr->{I1}->{CCDYPIXE} && exists $self->hdr->{INGPSCAL} ) {
      $decscale = $self->hdr->{I1}->{CCDYPIXE} * 1000.0 * $self->hdr->{INGPSCAL};
   }
   return $decscale;
}

sub _to_RA_SCALE {
   my $self = shift;
   my $rascale = -0.2387;

# Assumes either x-y scales the same or the x corresponds to right
# ascension, and right ascension decrements with increasing x. 
   if ( exists $self->hdr->{I1}->{CCDXPIXE} && exists $self->hdr->{INGPSCAL} ) {
      $rascale = $self->hdr->{I1}->{CCDXPIXE} * -1000.0 * $self->hdr->{INGPSCAL};
   }
   return $rascale;
}

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoffset = 0.0;
   if ( exists $self->hdr->{"CAT-DEC"} && exists $self->hdr->{DEC} &&
        exists $self->hdr->{"CAT-RA"} && exists $self->hdr->{RA} ) {

# Obtain the reference and telescope declinations positions measured in degrees.
      my $refdec = $self->dms_to_degrees( $self->hdr->{"CAT-DEC"} );
      my $dec = $self->dms_to_degrees( $self->hdr->{DEC} );

# Find the offsets between the positions in arcseconds on the sky.
      $decoffset = 3600.0 * ( $dec - $refdec );
   }

# The sense is reversed compared with UKIRT, as these measure the
# place son the sky, not the motion of the telescope.
   return -1.0 * $decoffset
}

# If the telescope ofset exists in arcsec, then use it.  Otherwise
# convert the Cartesian offsets to equatorial offsets.
sub _to_RA_TELESCOPE_OFFSET {
   my $self = shift;
   my $raoffset = 0.0;

   if ( exists $self->hdr->{"CAT-DEC"} && exists $self->hdr->{DEC} &&
        exists $self->hdr->{"CAT-RA"} && exists $self->hdr->{RA} ) {

# Obtain the reference and telescope sky positions measured in degrees.
      my $refra = $self->hms_to_degrees( $self->hdr->{"CAT-RA"} );
      my $ra = $self->hms_to_degrees( $self->hdr->{RA} );
      my $refdec = $self->dms_to_degrees( $self->hdr->{"CAT-DEC"} );

# Find the offset between the positions in arcseconds on the sky.
      $raoffset = 3600.0 * ( $ra - $refra ) * cosdeg( $refdec );
   }

# The sense is reversed compared with UKIRT, as these measure the
# place son the sky, not the motion of the telescope.
   return -1.0 * $raoffset;
}

sub _to_DEC_BASE {
   my $self = shift;
   my $dec = 0.0;
   my $sexa = $self->hdr->{"CAT-DEC"};
   if ( defined( $sexa ) ) {
      $dec = $self->dms_to_degrees( $sexa );
   }
   return $dec;
}

# This is guesswork at present.
sub _to_DETECTOR_READ_TYPE {
   my $self = shift;
   my $read_type;
   my $readout_mode = $self->hdr->{READMODE};
   my $nreads = $self->hdr->{NUMREADS};
   if ( $readout_mode =~ /^mndr/i ||
        ( $readout_mode =~ /^cds/i && $nreads == 1 ) ) {
      $read_type = "NDSTARE";
   } elsif ( $readout_mode =~ /^cds/i ) {
      $read_type = "NDSTARE";
   }
   return $read_type;
}

sub _to_EQUINOX {
   my $self = shift;
   my $equinox = 2000.0;
   if ( exists $self->hdr->{"CAT-EQUI"} ) {
      $equinox = $self->hdr->{"CAT-EQUI"};
      $equinox =~ s/[BJ]//;
   }
   return $equinox;
}

sub _to_GAIN {
   my $self = shift;
   my $gain = 4.1;
   if ( exists $self->hdr->{I1}->{GAIN} ) {
      $gain =  $self->hdr->{I1}->{GAIN};
   }
   return $gain;
}

sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;
   my $noffsets = 5;

# Look for a dither pattern.  These begin D-<n>/<m>: where
# <m> represents the number of jitter positions in the group
# and <n> is the number within the group.
   my $object = $self->hdr->{OBJECT};
   if ( $object =~ /D-\d+\/\d+/ ) {

# Extract the string betwen the solidus and the colon.  Add one
# to match the UKIRT convention.
      $noffsets = substr( $object, index( $object, "/" ) + 1 );
      $noffsets = substr( $noffsets, 0, index( $noffsets, ":" ) );
   }
   return $noffsets + 1;
}

sub _to_OBSERVATION_MODE {
   return "imaging";
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $obstype = uc( $self->hdr->{OBSTYPE} );
   if ( $obstype eq "TARGET" ) {
      $obstype = "OBJECT";
   }
   return $obstype;
}

sub _to_OBJECT {
   my $self = shift;
   my $object = $self->hdr->{OBJECT};

# Look for a dither pattern.  These begin D-<n>/<m>: where
# <m> represents the number of jitter positions in the group
# and <n> is the number within the group.  We want to extract
# the actual object name.
   if ( $object =~ /D-\d+\/\d+/ ) {
      $object = substr( $object, index( $object, ":" ) + 2 );
   }
   return $object;
}

sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   my $sexa = $self->hdr->{"CAT-RA"};
   if ( defined( $sexa ) ) {
      $ra = $self->hms_to_degrees( $sexa );
   }
   return $ra;
}

# No clue what the recipe is apart for a dark and assume a dither
# pattern means JITTER_SELF_FLAT.
sub _to_RECIPE {
   my $self = shift;
   my $recipe = "QUICK_LOOK";

# Look for a dither pattern.  These begin D-<n>/<m>: where
# <m> represents the number of jitter positions in the group
# and <n> is the number within the group.
   my $object = $self->hdr->{OBJECT};
   if ( $object =~ /D-\d+\/\d+/ ) {
      $recipe = "JITTER_SELF_FLAT";
   } elsif ( $self->hdr->{OBSTYPE} =~ /DARK/i ) {
      $recipe = "REDUCE_DARK";
   }

   return $recipe;
}

sub _to_ROTATION {
   my $self = shift;
   return $self->rotation();
}

# Fixed values for the gain depend on the camera (SW or LW), and for LW
# the readout mode.
sub _to_SPEED_GAIN {
   my $self = shift;
   my $spd_gain;
   my $speed = $self->hdr->{CCDSPEED};
   if ( $speed =~ /SLOW/ ) {
      $spd_gain = "Normal";
   } else {
      $spd_gain = "HiGain";
   }
   return $spd_gain;
}

sub _to_STANDARD {
   my $self = shift;
   my $standard = 0;
   my $type = $self->hdr->{OBSTYPE};
   if ( uc( $type ) eq "STANDARD" ) {
      $standard = 1;
   }
   return $standard;
}

sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;

# This is approximate end UT in seconds.
   return $self->get_UT_hours() + $self->hdr->{EXPTIME} / 3600.0;
}

sub _to_UTSTART {
   my $self = shift;
   return $self->get_UT_hours();
}

sub _to_WAVEPLATE_ANGLE {
   0;
}

# Use the nominal reference pixel if correctly supplied, failing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_X_REFERENCE_PIXEL{
   my $self = shift;
   my $xref;
   my @bounds = $self->getbounds();
   if ( $bounds[ 0 ] > 1 || $bounds[ 1 ] < 1024 ) {
      $xref = nint( ( $bounds[ 0 ] + $bounds[ 1 ] ) / 2 );
   } else {
      $xref = 512;
   }
   return $xref;
}

# Use the nominal reference pixel at the centre for now.  For sub-arrays
# take the average of the bounds.
sub _to_Y_REFERENCE_PIXEL{
   my $self = shift;
   my $yref;
   my @bounds = $self->getbounds();
   if ( $bounds[ 2 ] > 1 || $bounds[ 3 ] < 1024 ) {
      $yref = nint( ( $bounds[ 2 ] + $bounds[ 3 ] ) / 2 );
   } else {
      $yref = 512;
   }
   return $yref;
}

sub _to_X_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->getbounds();
   return $bounds[ 0 ];
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->getbounds();
   return $bounds[ 2 ];
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->getbounds();
   return $bounds[ 1 ];
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->getbounds();
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

# Obtain the detector bounds from a section in [xl:xu,yl:yu] syntax.
# If the RTDATSEC header is absent, use a default which corresponds
# to the full array.
sub getbounds{
   my $self = shift;
   my @bounds = ( 1, 1024, 1, 1024 );
   if ( exists $self->hdr->{RTDATSEC} ) {
      my $section = $self->hdr->{RTDATSEC};
      $section =~ s/\[//;
      $section =~ s/\]//;
      $section =~ s/,/:/g;
      @bounds = split( /:/, $section );
   }
   return @bounds;
}

# Returns the UT date in YYYYMMDD format.
sub get_UT_date {
   my $self = shift;

# This is UT start and time.
   my $dateobs = $self->hdr->{"DATE-OBS"};

# Extract out the data in yyyymmdd format.
   return substr( $dateobs, 0, 4 ) . substr( $dateobs, 5, 2 ) . substr( $dateobs, 8, 2 )
}

sub get_UT_hours {
   my $self = shift;
   my $startsec = 0.0;
   if ( exists ( $self->hdr->{UTSTART} ) ) {

# The time is encoded in FITS data format, i.e. hh:mm:ss.  So convert to seconds.
      my $t = $self->hdr->{UTSTART};
      $startsec = substr( $t, 0, 2 ) * 3600.0 +
                  substr( $t, 3, 2 ) * 60.0 + substr( $t, 6, 2 );
   }

# Convert from seconds to decimal hours.
   return $startsec / 3600.0;
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

# Derives the rotation angle from the rotation matrix.
sub rotation{
   my $self = shift;
   my $rotangle = 0.0;

   if ( exists $self->hdr->{ROTSKYPA} ) {
      $rotangle = $self->hdr->{ROTSKYPA};
   }
   return $rotangle;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::INGRID object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::INGRID;
   $Frm = new ORAC::Frame::INGRID("file_name");
   $Frm = new ORAC::Frame::INGRID("UT","number");

The constructor hard-wires the '.fit' rawsuffix and the
'' prefix although these can be overriden with the
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
   $self->rawfixedpart( 'r' );
   $self->rawsuffix( '.fit' );
   $self->rawformat( 'INGMEF' );

# INGRID is really a single frame instrument
# So this should be "NDF" and we should be inheriting
# from UFTI
   $self->format( 'HDS' );

# If arguments are supplied then we can configure the object
# Currently the argument will be the filename.
# If there are two args this becomes a prefix and number
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
comparing the relative start times of frames.  For INGRID this
number is decimal hours.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.  It returns a hash containing the new
keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC headers.
   my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# --------
# For INGRID this is the UTC header value converted to decimal hours
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
   $new{ORACUT} = $ut;

   return %new;
}

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut

sub number {
   my $self = shift;

   my $number = $self->hdr( "RUN" );
   if ( !defined $number ) {
      $number = -1;
   }

   return $number;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

INGRID file name convention is

  rNNNNNN.fit

where NNNNNN is the observation number. e.g

  r597816.fit

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for INGRID.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# INGRID naming.
   return $self->rawfixedpart . $obsnum . $self->rawsuffix;
}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  Copes with non-existence of HDS container
and handles NDF subframes.

The following logic is applied:

 - If a '.' is present

   NFILES > 1
       The new suffix is attached before the dot.
       An HDS container is created (based on the root) to
       receive the expected NDF.

   NFILES = 1
       We remove the dot and append the suffix as normal
       (by removing the old suffix first).
       This ensures that when NFILES=1 we will no longer
       be using HDS containers

 - If no '.' is present

       This is the standard behaviour. Simply remove after
       last underscore and replace with new suffix.

If you want to retain the HDS container syntax, this routine has to be
fooled into thinking that nfiles is greater than 1 (e.g. by adding a dummy
file name to the frame).

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

   ($in, $out) = $Frm->inout($suffix,2);

=cut

sub inout {

   my $self = shift;
   my $suffix = shift;

# Read the number.
   my $num = 1; 
   if (@_) { $num = shift; }

   my $infile = $self->file($num);

# Split infile into a root and a tail.
   my ( $junk, $rest ) = $self->_split_fname( $infile );
   my @junk = @$junk;

# We still need the root name though for the copobj.
   my $root = $self->_join_fname( $junk, '');

# We only want to drop the SECOND underscore.  If we only have
# two components we simply append.  If we have more we drop the
# last.  This prevents us from dropping the observation number in
# ro970815_28.  Special case numbers.
   if ($#junk > 0 && $junk[-1] !~ /^\d+$/) {
     @junk = @junk[0..$#junk-1];
  }

# Find out how many files we have.
   my $nfiles = $self->nfiles;

# Now append the suffix to the outfile.  We need to strip a leading
# underscore if we are using join_name.
   $suffix =~ s/^_//;
   push( @junk, $suffix );
   my $outfile = $self->_join_fname( \@junk, '' );

# If we had a suffix (e.g. .I1) now need to re-attach it and create
# an HDS container *IF* NFILES is greater than 1.  If NFILES equals 1
# we don't need to do anything.
   if ( defined $rest && $nfiles > 1 ) {

      my ( $loc, $status );
      $status = &NDF::SAI__OK;

      if ( -e $outfile.".sdf" ) {

        err_begin( $status );
        hds_open( $outfile, 'UPDATE', $loc, $status );

        dat_there( $loc, $rest, my $there, $status );
        if ( $there ) {
           dat_erase( $loc, $rest, $status );
        };

        dat_annul( $loc, $status );
        err_end( $status );

      } else {

         my @null = ( 0 );

         hds_new ( $outfile, substr( $outfile, 0, 9 ), "MICHELLE_HDS", 0, @null, $loc, $status );
         dat_annul( $loc, $status );
         orac_err( "Failed to create HDS container!" ) if $status != &NDF::SAI__OK;

# Propagate the header.
         $status = copobj( $root.".header", $outfile.".header", $status );
         orac_err( "Failed to propagate header!" ) if $status != &NDF::SAI__OK;
      }

      $outfile .= "." . $rest;
   }

   return ( $infile, $outfile ) if wantarray();  # Array context
   return $outfile;                              # Scalar context
}

sub mergehdr {

}

sub template {
   my $self = shift;
   my $template = shift;

   my $num = $self->number;

# Change the first number.
   $template =~ s/\d+_/${num}_/;

# Update the filename.
   $self->file( $template );

}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
