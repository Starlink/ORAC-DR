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
            CONFIGURATION_INDEX => "CNFINDEX",
            DETECTOR_INDEX  => "DINDEX",
            DETECTOR_MODE   => "DETMODE",
            DIM1            => "DCOLUMNS",
            DIM2            => "DROWS",
            EXP_TIME        => "DEXPTIME",
            GRATING_NAME    => "GRATING",
            GRATING_ORDER   => "GORDER",
            GRATING_WAVELENGTH => "GLAMBDA",
            NSCAN_POSITIONS => "DETNINCR",
            NUMBER_OF_EXPOSURES => "NEXP",
            SCAN_INCREMENT  => "DETINCR",
            SLIT_ANGLE      => "SANGLE",
            SLIT_NAME       => "SLIT",
            TDECOFF         => "DECOFF",
            TRAOFF          => "RAOFF",
            UTDATE          => "IDATE"
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
those available from ORAC::Frame::UKIRT.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::UKIRT object.
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
    $fname = $self->file_from_bits(@_);
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }

  # set the filename

  $self->file($fname);
  my $rootfile = $self->file;

  # Set the raw data file name

  $self->raw($fname);

  # We have as many files as there are NDF compenents, minus the header component
  $self->findnsubs;

 # Populate the header
  # for hds container set header NDF to be in the .header extension
  my $hdr_ext = $self->file.".header";

  $self->readhdr($hdr_ext);

  # now read the subheaders 

  foreach my $i (1..$self->nsubs) {
    my ($href, $status) = fits_read_header($self->file . ".i$i");
     $self->hdr->{$i} = $href;
    # (same as $self->hdr($i, $href);)
  }

  # ....and make sure calc_orac_headers is up-to-date after this
  $self->calc_orac_headers;

  # populate file method

  for my $i (1..$self->nsubs) {

    # Set the filename

    $self->file($i,$rootfile.".i$i");

  };

  # Find the group name and set it
  $self->findgroup;

  # Find the recipe name
  $self->findrecipe;

  # Return something
  return 1;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For CGS4 the raw filename is of the form:

  cYYYYMMDD_NNNNN.sdf

where the number is 0 padded.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Zero pad the number
  $obsnum = sprintf("%05d", $obsnum);

  # CGS4 form is  FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<findnsubs>

This method returns the number of .I? NDFs found in an HDS container.
It can not simply count the number of NDFs and subtract 1 (the .HEADER)
because Michelle stored extra NDFs in the container.

  $ncomp = $Frm->findnsubs;

The header is updated.

=cut

sub findnsubs {
  my $self = shift;

  my $file = shift;

  my ($loc,$status,$ncomp);

  unless (defined $file) {
    $file = $self->file;
  }

  # Now need to find the NDFs in the output HDS file
  $status = &NDF::SAI__OK;
  hds_open($file, 'READ', $loc, $status);

  # Need to rely on status being good before proceeding
  if ($status == &NDF::SAI__OK) {

    # Loop until we get an error
    my $there = 1;
    $ncomp = 0;
    while ($there && $status == &NDF::SAI__OK) {

      # increment counter
      $ncomp++;

      # Check for the .I?? component
      dat_there($loc, "I$ncomp", $there, $status );

    }

    # ncomp will be one too large since we have to check
    # for 1 higher
    $ncomp--;

  }

  # Loop until 
  dat_annul($loc, $status);

  unless ($status == &NDF::SAI__OK) {
    orac_err("Can't open $file for nsubs\n");
    return 0;
  }

  if ($ncomp == 0) {
    orac_err "Could not find .I1 NDF component in file $file\n";
    return 0;
  }

  # Update the header
  $self->nsubs($ncomp);

  return $ncomp;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
CGS4 and is usually of the form:

  .cYYYYMMDD_NNNNN.ok

=cut



sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # flag files for CGS4 of the type .cYYYYMMDD_NNNNN.ok
  my $raw = $self->file_from_bits($prefix, $obsnum);

  # raw includes the .sdf so we have to strip it
  $raw = $self->stripfname($raw);

  my $flag = ".".$raw.".ok";

}

=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  Copes with non-existence of HDS container
and handles NDF subframes

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
fooled into thinking that nfiles is greater than 1 (eg by adding a dummy
file name to the frame).

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

   ($in,$out) = $Frm->inout($suffix,2);

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1; 
  if (@_) { $num = shift; }

  my $infile = $self->file($num);

  # Split infile into a root and a tail
  my ($junk, $rest) = $self->_split_fname( $infile );
  my @junk = @$junk;

  # We still need the root name though for the copobj
  my $root = $self->_join_fname( $junk, '');

  # We only want to drop the SECOND underscore. If we only have
  # two components we simply append. If we have more we drop the last
  # This prevents us from dropping the observation number in
  # ro970815_28. Special case numbers.
  if ($#junk > 1 && $junk[-1] !~ /^\d+$/) {
    @junk = @junk[0..$#junk-1];
  }

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Now append the suffix to the outfile
  # Need to strip a leading underscore if we are using join_name
  $suffix =~ s/^_//;
  push(@junk, $suffix);
  my $outfile = $self->_join_fname(\@junk, '');

  # If we had a suffix (eg .i1) now need to
  # reattach it and create an HDS container *IF* NFILES is greater than 1
  # If NFILES equals 1 
  if (defined $rest && $nfiles > 1) {

    my ($loc,$status);
    $status = &NDF::SAI__OK;

    if (-e $outfile.".sdf") {

      err_begin($status);
      hds_open($outfile, 'UPDATE', $loc, $status);

      dat_there($loc, $rest, my $there, $status);
      if ($there) {
	dat_erase($loc, $rest, $status);
      };

      dat_annul($loc, $status);
      err_end($status);


    } else {

      my @null = (0);

      hds_new ($outfile,substr($outfile,0,9),"MICHELLE_HDS",0,@null,$loc,$status);
      dat_annul($loc, $status);
      orac_err("Failed to create HDS container!") if $status != &NDF::SAI__OK;

      # propagate header
      $status = copobj($root.".header",$outfile.".header",$status);
      orac_err("Failed to propagate header!") if $status != &NDF::SAI__OK;
    }

    $outfile .= ".".$rest;
  }

  return ($infile, $outfile) if wantarray();  # Array context
  return $outfile;                            # Scalar context
}



=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'DRRECIPE' FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

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
    $status = copobj($root.".header.more.fits",$new.".more.fits",$status);
    orac_err("Failed dismally to propagate HDS header to NDF file\n") unless ($status==&NDF::SAI__OK);
  };

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

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
