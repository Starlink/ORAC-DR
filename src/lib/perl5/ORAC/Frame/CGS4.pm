package ORAC::Frame::CGS4;

=head1 NAME

ORAC::Frame::CGS4 - CGS4 class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::CGS4;

  $Frm = new ORAC::Frame::CGS4("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to CGS4. It provides a class derived from B<ORAC::Frame::UKIRT>.
All the methods available to B<ORAC::Frame::UKIRT> objects are available
to B<ORAC::Frame::CGS4> objects. Some additional methods are supplied.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::UKIRT;
use ORAC::Print;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::UKIRT/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# standard error module and turn on strict
use Carp;
use strict;

# For reading the header
use NDF;
use Starlink::HDSPACK qw/copobj/;

# Translation tables for CGS4 should go here.
my %hdr = (
            CONFIGURATION_INDEX  => "CNFINDEX",
            DETECTOR_INDEX       => "DINDEX",
            DETECTOR_READ_TYPE   => "MODE",
            EXPOSURE_TIME        => "DEXPTIME",
            GAIN                 => "DEPERDN",
            GRATING_DISPERSION   => "GDISP",
            GRATING_NAME         => "GRATING",
            GRATING_ORDER        => "GORDER",
            GRATING_WAVELENGTH   => "GLAMBDA",
            NSCAN_POSITIONS      => "DETNINCR",
            RECIPE               => "DRRECIPE",
            SCAN_INCREMENT       => "DETINCR",
            SLIT_ANGLE           => "SANGLE",
            SLIT_NAME            => "SLIT",
            UTDATE               => "IDATE",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Frame::CGS4->_generate_orac_lookup_methods( \%hdr );

# Certain headers appear in each .In sub-frame.  Special translation
# rules are required to represent the combined image, and thus should
# not appear in the above hash.  For example, the start time is that of
# the first sub-image, and the end time that of the sub-image.  These
# translation methods make use 

sub _to_UTEND {
  my $self = shift;
  $self->hdr->{ $self->nfiles }->{RUTEND}
    if exists $self->hdr->{ $self->nfiles };
}

sub _from_UTEND {
  "RUTEND", $_[0]->uhdr("ORAC_UTEND");
}

sub _to_UTSTART {
  my $self = shift;
  $self->hdr->{ 1 }->{RUTSTART}
    if exists $self->hdr->{1};
}

sub _from_UTSTART {
  "RUTSTART", $_[0]->uhdr("ORAC_UTSTART");
}

sub _to_DEC_TELESCOPE_OFFSET {
  my $self = shift;
  my $return;
  my $hdr;
  if( exists( $self->hdr->{1} ) ) {
    $hdr = $self->hdr->{1};
  } else {
    $hdr = $self->hdr;
  }

  my $ut = $hdr->{IDATE};
  if( $ut < 20050315 ) {
    $return = $self->hdr->{DECOFF};
  } else {
    $return = $self->hdr->{TDECOFF};
  }
  return $return;
}

sub _from_DEC_TELESCOPE_OFFSET {
  my $self = shift;
  my %return;
  if( $self->uhdr("ORACUT") < 20050315 ) {
    $return{"DECOFF"} = $self->uhdr("ORAC_DEC_TELESCOPE_OFFSET");
  } else {
    $return{"TDECOFF"} = $self->uhdr("ORAC_DEC_TELESCOPE_OFFSET");
  }
  return %return;
}

sub _to_RA_TELESCOPE_OFFSET {
  my $self = shift;
  my $return;
  my $hdr;
  if( exists( $self->hdr->{1} ) ) {
    $hdr = $self->hdr->{1};
  } else {
    $hdr = $self->hdr;
  }

  my $ut = $hdr->{IDATE};
  if( $ut < 20050315 ) {
    $return = $self->hdr->{RAOFF};
  } else {
    $return = $self->hdr->{TRAOFF};
  }

  return $return;
}

sub _from_RA_TELESCOPE_OFFSET {
  my $self = shift;
  my %return;
  if( $self->uhdr("ORACUT") < 20050315 ) {
    $return{"RAOFF"} = $self->uhdr("ORAC_RA_TELESCOPE_OFFSET");
  } else {
    $return{"TRAOFF"} = $self->uhdr("ORAC_RA_TELESCOPE_OFFSET");
  }
  return %return;
}

sub _to_POLARIMETRY {
  my $self = shift;
  my $return;
  if( exists( $self->hdr->{FILTER} ) &&
      $self->hdr->{FILTER} =~ /\+PRISM/ ) {
    return 1;
  } else {
    return 0;
  }
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::CGS4 object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::CGS4;
   $Frm = new ORAC::Frame::CGS4("file_name");
   $Frm = new ORAC::Frame::CGS4("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'c' prefix although these can be overriden with the 
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
  $self->rawfixedpart('c');
  $self->rawsuffix('.sdf');
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

=over 4

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findrecipe and findnsubs()
methods are invoked by this command. Arguments are required.  If there
is one argument it is assumed that this is the raw filename. If there
are two arguments the filename is constructed assuming that arg 1 is
the prefix and arg2 is the observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

=cut

sub configure {
  my $self = shift;

  # If two arguments (prefix and number)
  # have to find the raw filename first
  # else assume we are being given the raw filename
  my $fname;
  if (scalar(@_) == 1) {
    $fname = shift;
  } elsif (scalar(@_) == 2) {
    # For CGS4 pattern_from_bits() returns a string, so this is okay.
    $fname = $self->pattern_from_bits(@_);
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }

  # set the filename

  $self->file($fname);
  my $rootfile = $self->file;

  # Set the raw data file name

  $self->raw($fname);

  # The number of sub frames is difficult. The .HEADER should not be
  # included but in chopped observations we want to use .INBEAMA/B 
  # instead of just .I1. To get around this problem findubs() populates
  # an internal data structure that will contain all the names we are
  # interested in.
  $self->findnsubs;

  # Read the internal data structure
  my @Components = @{ $self->{_Components} };

  # Populate the header
  # for hds container set header NDF to be in the .header extension
  my $hdr_ext = $self->file;
  $hdr_ext .= ".header" if @Components;

  $self->readhdr($hdr_ext);

  # now read the subheaders 
  my $i = 1;
  foreach my $comp (@Components) {
    # Read the header associated with the subframe
    # KLUGE - Michelle chop data does not have a fits header
    # in the .I1BEAMA components so we need to put in a nasty hack
    # here
    # Skip if we are in beamB
    next if $comp =~ /BEAMB$/;

    # Strip the chop information
    (my $kluge = $comp) =~ s/BEAM[AB]$//;
    #my ($href, $status) = fits_read_header($rootfile . ".$kluge");
    my $hdr = new Astro::FITS::Header::NDF( File => $rootfile .".$kluge");
    # Store the header associated with this subframe
    $self->hdr->{$i} = $hdr if $hdr;

    $i++;
  }

  # ....and make sure calc_orac_headers is up-to-date after this
  $self->calc_orac_headers;

  # Filenames
  $i = 1;
  foreach my $comp (@Components) {
    # Update the filename
    $self->file($i,$rootfile.".$comp");
    $i++;
  }

  # Find the group name and set it
  $self->findgroup;

  # Find the recipe name
  $self->findrecipe;

  # Return something
  return 1;
}

=item B<findnsubs>

This method returns the number of .I? NDFs found in an HDS container.
It can not simply count the number of NDFs and subtract 1 (the .HEADER)
because Michelle stored extra NDFs in the container.

  $ncomp = $Frm->findnsubs;

The header is updated.

Additionally, the names of the components are stored in an internal
data structure so that configure() can access them. This is because
in Michelle the chopped observations should not use .I1 but rather
the chopped frames themselves.

=cut

sub findnsubs {
  my $self = shift;

  my $file = shift;

  my ($loc,$status);

  unless (defined $file) {
    $file = $self->file;
  }

  # Now need to find the NDFs in the output HDS file
  $status = &NDF::SAI__OK;
  hds_open($file, 'READ', $loc, $status);

  # Need to rely on status being good before proceeding
  my @comps;
  if ($status == &NDF::SAI__OK) {

    # Find out how many we have
    dat_ncomp($loc, my $ncomp, $status);

    # Get all the component names
    for my $i (1..$ncomp) {

      # Get locator to component
      dat_index($loc, $i, my $cloc, $status);

      # Find its name
      dat_name($cloc, my $name, $status);
      push(@comps, $name) if $status == &NDF::SAI__OK;

      # Release locator
      dat_annul($cloc, $status);

      last if $status != &NDF::SAI__OK;
    }

  }

  # Close file
  dat_annul($loc, $status);

  unless ($status == &NDF::SAI__OK) {
    orac_err("Can't open $file for nsubs or error reading components\n");
    return 0;
  }

  # Now need to go through component names looking for useful names
  my (@IN, @INBEAM);
  for my $comp (@comps) {
    if ($comp =~ /^I\d+$/) {
      push(@IN, $comp);
    } elsif ($comp =~ /^I\d+BEAM/) {
      push(@INBEAM, $comp);
    }
  }

  # Now see what we have
  my ($ncomp, @result);
  if (@INBEAM) {
    # Chopped observation
    @result = @INBEAM;
  } elsif (@IN) {
    # Standard HDS observation
    @result = @IN;
  }

  $ncomp = scalar(@result);
  $self->{_Components} = [@result];

  unless (defined $ncomp) {
    orac_err "Could not find .I1?? NDF component in file $file\n";
    return 0;
  }

  # Update the header
  $self->nsubs($ncomp);

  return $ncomp;

}

=item B<sync_headers>

=cut

sub sync_headers {
  return;
}

=back

=head1 METHODS UNIQUE TO THIS CLASS

=over 4

=item B<mergehdr>

Method to propagate the FITS header from an HDS container to an NDF
Run after updating $Frm.

 $Frm->files($out);
 $Frm->mergehdr;

=cut

sub mergehdr {

  my $self = shift;
  my $status;

  my $old = pop(@{$self->intermediates});
  my $new = $self->file;

  my ($root, $rest) = $self->_split_name($old);

  if (defined $rest) {
    $status = &NDF::SAI__OK;

    # determine whether we have got a .MORE component already
    ndf_begin();
    ndf_find(&NDF::DAT__ROOT(), $new, my $indf, $status);
    ndf_xnumb($indf, my $num, $status);
    ndf_annul($indf, $status);
    ndf_end($status);

    # if we have no extensions we have to copy the whole .MORE
    # if we have some extensions just copy .FITS
    my $copy = ( $num ? "MORE.FITS" : "MORE");

    $status = copobj($root.".header.$copy",$new.".$copy",$status);

    orac_err("Failed dismally to propagate HDS header from $root to NDF file $new\n") unless ($status==&NDF::SAI__OK);

  };

}

=item B<template>

Create new file name from template. zero-pads.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # pad with leading zeroes - 5(!) digit obsnum
  $num = '0'x(5-length($num)) . $num;

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}


=back

=head1 PRIVATE METHODS

=over 4

=item B<_split_name>

Internal routine to split a 'file' name into an actual
filename (the HDS container) and the NDF name (the
thing inside the container).

Splits on '.'

Argument: string to split (eg test.i1)
Returns:  root name, ndf name (eg 'test' and 'i1')

NDF name is undef if there are no 'sub-frames'.

This routine is so simple that it may not be worth the effort.

=cut

sub _split_name {
  my $self = shift;
  my $file  = shift;

  # Split on '.'
  my ($root, $rest) = split(/\./, $file, 2);

  return ($root, $rest);
}

=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
Paul Hirst (p.hirst@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
