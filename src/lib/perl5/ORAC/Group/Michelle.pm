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
            DEC_SCALE            => "PIXELSIZ",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            EXPOSURE_TIME        => "EXP_TIME",
            GAIN                 => "GAIN",
            RA_SCALE             => "PIXELSIZ",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART",

# then the spectroscopy.
            CONFIGURATION_INDEX  => "CNFINDEX",
            DETECTOR_INDEX       => "DINDEX",
            GRATING_DISPERSION   => "GRATDISP",
            GRATING_NAME         => "GRATNAME",
            GRATING_ORDER        => "GRATORD",
            GRATING_WAVELENGTH   => "GRATPOS",
            NSCAN_POSITIONS      => "DETNINCR",
            SCAN_INCREMENT       => "DETINCR",
            SLIT_ANGLE           => "SLITANG",
            SLIT_NAME            => "SLITNAME",
            UTDATE               => "UTDATE",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS",

# then the general.
            CHOP_ANGLE           => "CHPANGLE",
            CHOP_THROW           => "CHPTHROW",
            DETECTOR_READ_TYPE   => "DETMODE",
            NUMBER_OF_READS      => "NREADS",
            OBSERVATION_MODE     => "CAMERA"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::Michelle->_generate_orac_lookup_methods( \%hdr );

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

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames. For IRCAM this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC
  # headers
  my %new = $self->SUPER::calc_orac_headers;


  # ORACTIME
  # For IRCAM the keyword is simply RUTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('RUTSTART');
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # ORACUT
  # For IRCAM this is simply the IDATE header value
  my $ut = $self->hdr('IDATE');
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
