package ORAC::Group::Michelle;

=head1 NAME

ORAC::Group::Michelle - Michelle class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::Michelle("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to Michelle. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::Michelle> objects. 

=cut

# A package to describe a Michelle group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ORAC::Group::UKIRT/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for Michelle should go here.
# First the imaging...
my %hdr = (
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy.
            CONFIGURATION_INDEX  => "CNFINDEX",
            DETECTOR_INDEX       => "DINDEX",
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
            UTEND                => "UTEND",
            UTSTART              => "UTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::Michelle->_generate_orac_lookup_methods( \%hdr );

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
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::Michelle> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::Michelle;
   $Grp = new ORAC::Group::Michelle("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gm'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gm');
  $group->filesuffix('.sdf');

  # return the new object
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

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie  E<lt>mjc@star.rl.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
