package ORAC::Frame::Michelle;

=head1 NAME

ORAC::Frame::Michelle - Michelle class for dealing with observation files in ORAC-DR.

=head1 SYNOPSIS

  use ORAC::Frame::Michelle;

  $Frm = new ORAC::Frame::Michelle("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to Michelle. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::Michelle> objects.

=cut

# A package to describe a Michelle group object for the ORAC-DR pipeline.

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::CGS4/;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for Michelle should go here.
# First the imaging...
my %hdr = (
            DR_RECIPE               => "RECIPE",
            DEC_SCALE            => "CDELT2",
#            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "CDELT1",
#            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "CNFINDEX",
            GRATING_DISPERSION   => "GRATDISP",
            GRATING_NAME         => "GRATNAME",
            GRATING_ORDER        => "GRATORD",
            GRATING_WAVELENGTH   => "GRATPOS",
            SLIT_ANGLE           => "SLITANG",
            SLIT_NAME            => "SLITNAME",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS",

# then the general.
            CHOP_ANGLE           => "CHPANGLE",
            CHOP_THROW           => "CHPTHROW",
            EXPOSURE_TIME        => "EXP_TIME",
            GAIN                 => "GAIN",
            NUMBER_OF_READS      => "NREADS",
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
#
# This will define the methods at runtime. The methods below this
# are defined at compile time and will be redefined by this call
# if there are clashes.
ORAC::Frame::Michelle->_generate_orac_lookup_methods( \%hdr );

# Certain headers appear in each .In sub-frame.  Special translation
# rules are required to represent the combined image, and thus should
# not appear in the above hash.  For example, the start time is that of
# the first sub-image, and the end time that of the sub-image. 

# Declination offsets need to be handled differently for spectroscopy
# mode because of the new nod iterator.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $decoff;

# Determine the observation mode, e.g. spectroscopy or imaging.
   my $mode = $self->_to_OBSERVATION_MODE();
   if ( $mode eq 'spectroscopy' ) {

# If the nod iterator is used, then telescope offsets always come out
# as 0,0.  We need to check if we're in the B beam (the nodded
# position) to figure out what the offset is using the chop angle
# and throw.
      if ( exists( $self->hdr->{CHOPBEAM} ) &&
           $self->hdr->{CHOPBEAM} =~ /^B/ &&
           exists( $self->hdr->{CHPANGLE} ) &&
           exists( $self->hdr->{CHPTHROW} ) ) {

         my $pi = 4 * atan2( 1, 1 );
         my $throw = $self->hdr->{CHPTHROW};
         my $angle = $self->hdr->{CHPANGLE} * $pi / 180.0;
         $decoff = $throw * cos( $angle );
      } else {
         $decoff = $self->hdr->{TDECOFF};
      }

# Imaging.
   } else {
      $decoff = $self->hdr->{TDECOFF};
   }

   return $decoff;
}

sub _from_DEC_TELESCOPE_OFFSET { 
   "TDECOFF", $_[0]->uhdr("ORAC_DEC_TELESCOPE_OFFSET");
}

sub _to_DETECTOR_INDEX {
   my $self = shift;

   if ( exists( $self->hdr->{ "I".$self->nfiles } ) && exists( $self->hdr->{ "I".$self->nfiles }->{DINDEX} ) ) {
      $self->hdr->{ "I".$self->nfiles }->{DINDEX};
  }
}

sub _from_DETECTOR_INDEX {
   "DINDEX", $_[0]->uhdr("ORAC_DETECTOR_INDEX");
}

# Allow for changing FITS-header keyword by date.
sub _to_DETECTOR_READ_TYPE {
   my $self = shift;

# Need the UTDATE as integer.  Undefined UT dates are assumed
# to be in the early epoch.
   my $ut = $self->get_UT_date();
   if ( !defined( $ut ) ) {
      $ut = 0;
   }

# Select the read-type keyword by epoch.
   my $read_type;
   if ( $ut < 20040206 ) {
      $read_type = $self->hdr->{DETMODE};
   } else {
      $read_type = $self->hdr->{DET_MODE};
   }

   return $read_type;
}


# Cater for early data with missing headers.
sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;

# It's normally a ABBA pattern.  Add one for the final offset to 0,0.
   my $noffsets = 5;

# Look for a defined header containing integers.
   if ( exists $self->hdr->{NOFFSETS} ) {
      my $noff = $self->hdr->{NOFFSETS};
      if ( defined $noff && $noff =~ /\d+/ ) {
         $noffsets = $noff;
      }
   }
   return $noffsets;
}

# Cater for early data with missing values.
sub _to_NSCAN_POSITIONS {
   my $self = shift;

# Number of scan positions.
   my $nscan = undef;
   if ( exists $self->hdr->{DETNINCR} ) {
      $nscan = $self->hdr->{DETNINCR};
      if ( $nscan =~ /scan positions/ ) {
         $nscan = undef;
      }
   }
   return $nscan;
}

# Cater for early data with missing values.
sub _to_OBJECT {
   my $self = shift;

# Number of scan positions.
   my $object = undef;
   if ( exists $self->hdr->{OBJECT} ) {
      $object = $self->hdr->{OBJECT};
      if ( $object =~ /^Object Name/ ) {
         $object = undef;
      }
   }
   return $object;
}

# Allow for changing FITS-header keyword by date.
sub _to_OBSERVATION_MODE {
   my $self = shift;

# Need the UTDATE as integer.  Undefined UT dates are assumed
# to be in the early epoch.
   my $ut = $self->get_UT_date();
   if ( !defined( $ut ) ) {
      $ut = 0;
   }

# Select the observation mode keyword by epoch.
   my $mode;
   if ( $ut < 20040206 ) {
      $mode = $self->hdr->{CAMERA};
   } else {
      $mode = $self->hdr->{INSTMODE};
   }

   return $mode;
}

# Right-ascension offsets need to be handled differently for spectroscopy
# mode because of the new nod iterator.
sub _to_RA_TELESCOPE_OFFSET {
   my $self = shift;
   my $raoff;

# Determine the observation mode, e.g. spectroscopy or imaging.
   my $mode = $self->_to_OBSERVATION_MODE();
   if ( $mode eq 'spectroscopy' ) {

# If the nod iterator is used, then telescope offsets always come out
# as 0,0.  We need to check if we're in the B beam (the nodded
# position) to figure out what the offset is using the chop angle
# and throw.
      if ( exists( $self->hdr->{CHOPBEAM} ) &&
           $self->hdr->{CHOPBEAM} =~ /^B/ &&
           exists( $self->hdr->{CHPANGLE} ) &&
           exists( $self->hdr->{CHPTHROW} ) ) {
         my $pi = 4 * atan2( 1, 1 );
         my $throw = $self->hdr->{CHPTHROW};
         my $angle = $self->hdr->{CHPANGLE} * $pi / 180.0;
         $raoff = $throw * sin( $angle );

       } else {
         $raoff = $self->hdr->{TRAOFF};
       }

# Imaging.
   } else {
      $raoff = $self->hdr->{TRAOFF};
   }
   return $raoff;
}

sub _from_RA_TELESCOPE_OFFSET { 
   "TRAOFF", $_[0]->uhdr("ORAC_RA_TELESCOPE_OFFSET");
}

# Cater for early data with missing values.
sub _to_SCAN_INCREMENT {
   my $self = shift;

# Number of scan positions.
   my $sincr = undef;
   if ( exists $self->hdr->{DETINCR} ) {
      $sincr = $self->hdr->{DETINCR};
      if ( $sincr =~ /[a-z]+/ ) {
         $sincr = undef;
      }
   }
   return $sincr;
}


# Cater for early data with missing values.
sub _to_STANDARD {
   my $self = shift;

# Whether or not observation is of a standard.
   my $standard = undef;
   if ( exists $self->hdr->{STANDARD} ) {
      $standard = $self->hdr->{STANDARD};
      if ( $standard !~ /[TF10]/ ) {
         $standard = undef;
      }
   }
   return $standard;
}

# Cater for early data with missing values.
sub _to_UTDATE {
   my $self = shift;
   return $self->get_UT_date();
}

sub _to_UTEND {
   my $self = shift;
   if ( exists( $self->hdr->{ "I".$self->nfiles } ) &&  exists( $self->hdr->{ "I".$self->nfiles }->{UTEND} ) ) {
      $self->hdr->{ "I".$self->nfiles }->{UTEND};
   }
}

sub _from_UTEND {
   "UTEND", $_[0]->uhdr("ORAC_UTEND");
}

sub _to_UTSTART {
   my $self = shift;
   if ( exists( $self->hdr->{I1} ) &&  exists( $self->hdr->{I1}->{UTSTART} ) ) {
      $self->hdr->{I1}->{UTSTART};
   }
}

sub _from_UTSTART {
   "UTSTART", $_[0]->uhdr("ORAC_UTSTART");
}

# Specify the reference pixel, which is normally near the frame centre.
# Note that offsets for polarimetry are undefined.
sub _to_X_REFERENCE_PIXEL{
   my $self = shift;
   my $xref;

# Use the average of the bounds to define the centre.
  if ( exists $self->hdr->{RDOUT_X1} && exists $self->hdr->{RDOUT_X2} ) {
     my $xl = $self->hdr->{RDOUT_X1};
     my $xu = $self->hdr->{RDOUT_X2};
     $xref = nint( ( $xl + $xu ) / 2 );

# Use a default of the centre of the full array.
   } else {
      $xref = 161;
   }
   return $xref;
}

sub _from_X_REFERENCE_PIXEL {
   "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

# Specify the reference pixel, which is normally near the frame centre.
# Note that offsets for polarimetry are undefined.
sub _to_Y_REFERENCE_PIXEL{
   my $self = shift;
   my $yref;

# Use the average of the bounds to define the centre.
   if ( exists $self->hdr->{RDOUT_Y1} && exists $self->hdr->{RDOUT_Y2} ) {
      my $yl = $self->hdr->{RDOUT_Y1};
      my $yu = $self->hdr->{RDOUT_Y2};
      $yref = nint( ( $yl + $yu ) / 2 );

# Use a default of the centre of the full array.
   } else {
      $yref = 121;
   }
   return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
   "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}


# Supplementary methods for the translations
# ------------------------------------------

# Returns the UT date in YYYYMMDD format or
# undef if the UTDATE keyword is absent or has no
# value.
sub get_UT_date {
   my $self = shift;

# This is UT start and time.
   my $utdate = undef;
   if ( exists $self->hdr->{UTDATE} ) {
      $utdate = $self->hdr->{UTDATE};

# Remove any hyphen delimiters.  They should be present
# but check, just in case.
      $utdate =~ s/-//g;

# Allow for blank value in early data.  Hence the
# value returned is the comment.
      if ( $utdate =~ /yyyymmdd/ ) {
         $utdate = undef;
      }
   }
   return $utdate;
}



=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::Michelle object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::Michelle;
   $Frm = new ORAC::Frame::Michelle("file_name");
   $Frm = new ORAC::Frame::Michelle("UT","number");

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
  $self->rawfixedpart('m');
  $self->rawsuffix('.sdf');
#  $self->rawformat('UKIRTio');
  $self->rawformat('HDS');
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 General Methods

This section describes sub-classed methods.

=over 4


=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
Malcolm J. Currie (mjc@jach.hawaii.edu)

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
