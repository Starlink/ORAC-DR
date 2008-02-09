package ORAC::Group::INGRID;

=head1 NAME

ORAC::Group::INGRID - INGRID class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::INGRID("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to INGRID. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::INGRID> objects. 

=cut

# A package to describe a INGRID group object for the
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

# Translation tables for INGRID should go here.
# First the imaging...
my %hdr = (

# then the general.
            AIRMASS_END          => "AIRMASS",
            AIRMASS_START        => "AIRMASS",
            EXPOSURE_TIME        => "EXPTIME",
            FILTER               => "INGF1NAM",
            GAIN                 => "GAIN",
            INSTRUMENT           => "DETECTOR",
            NUMBER_OF_EXPOSURES  => "COAVERAG",
            NUMBER_OF_READS      => "NUMREADS",
            OBSERVATION_NUMBER   => "RUN"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::INGRID->_generate_orac_lookup_methods( \%hdr );

sub _to_DEC_SCALE {
   my $self = shift;
   my $decscale = 0.2387;

# Assumes either x-y scales the same or the y corresponds to
# declination.
   if ( exists $self->hdr->{CCDYPIXE} && exists $self->hdr->{INGPSCAL} ) {
      $decscale = $self->hdr->{CCDYPIXE} * 1000.0 * $self->hdr->{INGPSCAL};
   }
   $decscale /= 3600;
   return $decscale;
}

sub _to_RA_SCALE {
   my $self = shift;
   my $rascale = -0.2387;

# Assumes either x-y scales the same or the x corresponds to right
# ascension, and right ascension decrements with increasing x. 
   if ( exists $self->hdr->{CCDXPIXE} && exists $self->hdr->{INGPSCAL} ) {
      $rascale = $self->hdr->{CCDXPIXE} * -1000.0 * $self->hdr->{INGPSCAL};
   }
   $rascale /= 3600.0;
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

sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;
   my $noffsets = 5;

# Look for a dither pattern.  These begin D-<n>/<m>: where
# <m> represents the number of jitter positions in the group
# and <n> is the number within the group.
   my $object = $self->hdr->{OBJECT};
   if ( $object =~ /D-\d+\/\d+/ ) {

# Extract the string between the solidus and the colon.  Add one
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
sub _to_DR_RECIPE {
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
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::INGRID> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::INGRID;
   $Grp = new ORAC::Group::INGRID("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gingrid'.

=cut

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required knowledge of
# fixedpart() and filesuffix() methods.
   my $group = $class->SUPER::new(@_);

# Configure it.
   $group->fixedpart( 'gingrid' );
   $group->filesuffix( '.sdf' );

# Eeturn the new object.
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
comparing the relative start times of frames.  For INGRID this
number is decimal hours.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the group header.  It returns a hash containing the
new keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC headers.
   my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# --------
# For INGRID this is the UTSTART header value converted to decimal hours
# and a 12-hour offset to avoid worrying about midnight UT.  The time is
# encoded in FITS data format, i.e. hh:mm:ss.
   my $t = $self->hdr->{UTSTART};
   my $time = substr( $t, 0, 2 ) + substr( $t, 3, 2 ) / 60.0 +
              substr( $t, 6, 2 ) / 3600.0 + 12.0;

# Just return it (zero if not available).
   $time = 0 unless (defined $t);
   $self->hdr('ORACTIME', $time);

   $new{'ORACTIME'} = $time;

# ORACUT
# ------
# Get the UT date.
   my $ut = $self->get_UT_date();
   $ut = 0 unless defined $ut;
   $self->hdr( 'ORACUT', $ut );

   return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group::Michelle>

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
