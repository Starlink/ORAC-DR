package ORAC::Frame::UIST;

=head1 NAME

ORAC::Frame::UIST - UIST class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UIST;

  $Frm = new ORAC::Frame::UIST("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to UIST. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::UIST> objects.

=cut

# A package to describe a UIST group object for the
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

# Translation tables for UIST should go here.
# First the imaging...
my %hdr = (
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "CDELT2",
            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "CNFINDEX",
            GRATING_DISPERSION   => "CDELT1",
            GRATING_NAME         => "GRISM",
            GRATING_ORDER        => "GRATORD",
            GRATING_WAVELENGTH   => "CENWAVL",
            SLIT_ANGLE           => "SLIT_PA",
            SLIT_NAME            => "SLITNAME",
            UTDATE               => "UTDATE",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS",

# then the general.
            OBSERVATION_MODE     => "INSTMODE",
            DETECTOR_READ_TYPE   => "DET_MODE",
            GAIN                 => "GAIN",
            NUMBER_OF_EXPOSURES  => "NEXP",
            NUMBER_OF_READS      => "NREADS",
            POLARIMETRY          => "POLARISE",
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Frame::UIST->_generate_orac_lookup_methods( \%hdr );

sub _to_CHOP_ANGLE {
  my $self = shift;
  my $chop_angle = 0;
  if( exists( $self->hdr->{ "I".$self->nfiles } ) &&
      exists( $self->hdr->{ "I".$self->nfiles }->{CHPANGLE} ) ) {
    $chop_angle = $self->hdr->{ "I".$self->nfiles }->{CHPANGLE};
  } elsif( exists( $self->hdr->{CHPANGLE} ) ) {
    $chop_angle = $self->hdr->{CHPANGLE};
  }

  return $chop_angle;
}

sub _to_CHOP_THROW {
  my $self = shift;
  my $chop_throw = 0;
  if( exists( $self->hdr->{ "I".$self->nfiles } ) &&
      exists( $self->hdr->{ "I".$self->nfiles }->{CHPTHROW} ) ) {
    $chop_throw = $self->hdr->{ "I".$self->nfiles }->{CHPTHROW};
  } elsif( exists( $self->hdr->{CHPTHROW} ) ) {
    $chop_throw = $self->hdr->{CHPTHROW};
  }

  return $chop_throw;
}

sub _to_EXPOSURE_TIME {
  my $self = shift;
  my $exptime;
  if( exists $self->hdr->{ "I".$self->nfiles }  && exists $self->hdr->{"I".$self->nfiles}->{EXP_TIME}) {
    $exptime = $self->hdr->{ "I".$self->nfiles }->{EXP_TIME};
  } else {
    $exptime = $self->hdr->{EXP_TIME};
  }
  return $exptime;
}

sub _from_EXPOSURE_TIME {
  "EXP_TIME", $_[0]->uhdr("ORAC_EXPOSURE_TIME");
}

sub _to_NSCAN_POSITIONS {
  1;
}

sub _from_NSCAN_POSITIONS {
  "DETNINCR", 1;
}

# ROTATION comprises the rotation matrix with respect to flipped axes,
# i.e. x corresponds to declination and Y to right ascension.  For other
# UKIRT instruments this was not the case, the rotation being defined
# in CROTA2.  Here the effective rotation is that evaluated from the
# PC matrix with a 90-degree counter-clockwise rotation for the rotated
# axes. If there is a PC3_2 header, we assume that we're in spectroscopy
# mode and use that instead.

sub _to_ROTATION {
  my $self = shift;
  my $rotation;
  if ( exists( $self->hdr->{PC1_1} ) && exists( $self->hdr->{PC2_1}) ) {
    my $pc11;
    my $pc21;
    if ( exists ($self->hdr->{PC3_2} ) && exists( $self->hdr->{PC2_2} ) ) {

      # We're in spectroscopy mode.
      $pc11 = $self->hdr->{PC3_2};
      $pc21 = $self->hdr->{PC2_2};
    } else {

      # We're in imaging mode.
      $pc11 = $self->hdr->{PC1_1};
      $pc21 = $self->hdr->{PC2_1};
    }
    my $rad = 57.2957795131;
    $rotation = $rad * atan2( -$pc21 / $rad, $pc11 / $rad ) + 90.0;
  } elsif ( exists $self->hdr->{CROTA2} ) {
    $rotation =  $self->hdr->{CROTA2} + 90.0;
  } else {
    $rotation = 90.0;
  }
  return $rotation;
}

sub _to_SCAN_INCREMENT {
  1;
}

sub _from_SCAN_INCREMENT {
  "DETINCR", 1;
}

sub _to_UTEND {
  my $self = shift;
  my $utend;
  if( exists $self->hdr->{ "I".$self->nfiles } && exists $self->hdr->{ "I".$self->nfiles }->{UTEND} ) {
    $utend = $self->hdr->{ "I".$self->nfiles }->{UTEND};
  } else {
    $utend = $self->hdr->{UTEND};
  }
  return $utend;
}

sub _from_UTEND {
  "UTEND", $_[0]->uhdr("ORAC_UTEND");
}

sub _to_UTSTART {
  my $self = shift;
  my $utstart;
  if( exists $self->hdr->{I1} && exists $self->hdr->{I1}->{UTSTART} ) {
    $utstart = $self->hdr->{I1}->{UTSTART};
  } else {
    $utstart = $self->hdr->{UTSTART};
  }
  return $utstart;
}

sub _from_UTSTART {
  "UTSTART", $_[0]->uhdr("ORAC_UTSTART");
}

# Use the nominal reference pixel if correctly supplied, failing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_X_REFERENCE_PIXEL{
  my $self = shift;
  my $xref;
  if ( exists $self->hdr->{CRPIX1} ) {
    $xref = $self->hdr->{CRPIX1};
  } elsif ( exists $self->hdr->{RDOUT_X1} && exists $self->hdr->{RDOUT_X2} ) {
    my $xl = $self->hdr->{RDOUT_X1};
    my $xu = $self->hdr->{RDOUT_X2};
    $xref = nint( ( $xl + $xu ) / 2 );
  } else {
    $xref = 480;
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
  } elsif ( exists $self->hdr->{RDOUT_Y1} && exists $self->hdr->{RDOUT_Y2} ) {
    my $yl = $self->hdr->{RDOUT_Y1};
    my $yu = $self->hdr->{RDOUT_Y2};
    $yref = nint( ( $yl + $yu ) / 2 );
  } else {
    $yref = 480;
  }
  return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
  "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

# For imaging, the declination pixel scale is in the CDELT1 header,
# and for spectroscopy and IFU, it's in CDELT3.
sub _to_DEC_SCALE {
  my $self = shift;
  my $return;
  if( $self->hdr->{INSTMODE} eq 'imaging' ) {
    $return = $self->hdr->{CDELT1};
  } else {
    $return = $self->hdr->{CDELT3};
  }
  return $return;
}

# Sampling is always 1x1, and therefore there are no headers with
# these values.

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::UIST object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::UIST;
   $Frm = new ORAC::Frame::UIST("file_name");
   $Frm = new ORAC::Frame::UIST("UT","number");

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
  $self->rawfixedpart('u');
  $self->rawsuffix('.sdf');
  $self->rawformat('HDS');

  # UIST is really a single frame instrument
  # So this should be "NDF" and we should be inheriting
  # from UFTI
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 General Methods

=over 4

=item B<mergehdr>

Method to propagate the FITS header from an HDS container to an NDF.
Run after updating $Frm.

 $Frm->files($out);
 $frm->mergehdr;

Headers in the .I1 and .HEADER components are merged.

=cut

sub mergehdr {

  my $self = shift;
  my $status;

  my $old = pop(@{$self->intermediates});
  my $new = $self->file;

  my ($root, $rest) = $self->_split_name($old);

  if (defined $rest) {
    $status = &NDF::SAI__OK;

    # Begin NDF context
    ndf_begin();

    # Open the file
    ndf_find(&NDF::DAT__ROOT(), $root . '.header', my $indf, $status);

    # Get the fits locator
    ndf_xloc($indf, 'FITS', 'READ', my $xloc, $status);

    # Find out how many entries we have
    my $maxdim = 7;
    my @dim = ();
    dat_shape($xloc, $maxdim, @dim, my $ndim, $status);

    # Must be 1D
    if ($status == &NDF::SAI__OK && scalar(@dim) > 1) {
      $status = &NDF::SAI__ERROR;
      err_rep(' ',"hsd2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",
	      $status);
    }

    # Read the FITS array
    my @fitsA = ();
    my $nfits;
    dat_get1c($xloc, $dim[0], @fitsA, $nfits, $status)
      if $status == &NDF::SAI__OK; # -w protection
		
    # Close the NDF file
    dat_annul($xloc, $status);
    ndf_annul($indf, $status);
		
    # Now we need to open the input file and modify the FITS entries
    ndf_open(&NDF::DAT__ROOT, $new, 'UPDATE', 'OLD', $indf, my $place,
	     $status);
		
    # Check to see if there is a FITS component in the output file
    ndf_xstat($indf, 'FITS', my $there, $status);
    my @fitsB = ();
    if (($status == &NDF::SAI__OK) && ($there)) {
			
      # Get the fits locator (note the deja vu)
      ndf_xloc($indf, 'FITS', 'UPDATE', $xloc, $status);
			
      # Find out how many entries we have
      dat_shape($xloc, $maxdim, @dim, $ndim, $status);
			
      # Must be 1D
      if ($status == &NDF::SAI__OK && scalar(@dim) > 1) {
	$status = &NDF::SAI__ERROR;
	err_rep(' ',"hds2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",$status);
      }
			
      # Read the second FITS array
      dat_get1c($xloc, $dim[0], @fitsB, $nfits, $status)
	if $status == &NDF::SAI__OK; # -w protection
			
      # Annul the locator
      dat_annul($xloc, $status);
      ndf_xdel($indf,'FITS', $status);
    }

    # Remove duplicate headers
    my %f = map { $_, undef } @fitsA;
    @fitsB = grep { !exists $f{$_} } @fitsB;

    # Merge arrays
    push(@fitsA, @fitsB);

    # Now resize the FITS extension by deleting and creating
    # (cmp_modc requires the parent locator)
    $ndim = 1;
    $nfits = scalar(@fitsA);
    my @nfits = ($nfits);
    ndf_xnew($indf, 'FITS', '_CHAR*80', $ndim, @nfits, $xloc, $status);
		
    # Upload the FITS entries
    dat_put1c($xloc, $nfits, @fitsA, $status);
		
    # Shutdown
    dat_annul($xloc, $status);
    ndf_annul($indf, $status);
    ndf_end($status);
		
    if ($status != &NDF::SAI__OK) {
      err_flush($status);
      err_end($status);
    }
  }
}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@star.rl.ac.ukE<gt>

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
