package ORAC::Frame::Michelle;

=head1 NAME

ORAC::Frame::Michelle - Michelle class for dealing with observation files in ORAC-DR

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

# A package to describe a Michelle group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;

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
            DEC_SCALE            => "PIXELSIZ",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "PIXELSIZ",
            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "CNFINDEX",
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
            EXPOSURE_TIME        => "EXP_TIME",
            GAIN                 => "GAIN",
            NUMBER_OF_READS      => "NREADS",
            OBSERVATION_MODE     => "CAMERA"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
# This will define the methods at runtime. The methods below this
# are defined at compile time and will be redefined by this call
# if there are clashes.
ORAC::Frame::Michelle->_generate_orac_lookup_methods( \%hdr );

# Certain headers appear in each .In sub-frame.  Special translation
# rules are required to represent the combined image, and thus should
# not appear in the above hash.  For example, the start time is that of
# the first sub-image, and the end time that of the sub-image.  These
# translation methods make use 

sub _to_DETECTOR_INDEX {
  my $self = shift;
  $self->hdr->{ $self->nfiles }->{DINDEX};
}

sub _from_DETECTOR_INDEX {
  "DINDEX", $_[0]->uhdr("ORAC_DETECTOR_INDEX");
}

sub _to_UTEND {
  my $self = shift;
  $self->hdr->{ $self->nfiles }->{UTEND};
}

sub _from_UTEND {
  "UTEND", $_[0]->uhdr("ORAC_UTEND");
}

sub _to_UTSTART {
  my $self = shift;
  $self->hdr->{ 1 }->{UTSTART};
}

sub _from_UTSTART {
  "UTSTART", $_[0]->uhdr("ORAC_UTSTART");
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

=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'RECIPE' FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('RECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if (! defined $recipe || length($recipe) == 0) {
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
