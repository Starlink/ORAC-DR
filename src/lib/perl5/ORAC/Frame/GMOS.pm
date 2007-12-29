package ORAC::Frame::GMOS;

=head1 NAME

ORAC::Frame::GMOS - class for dealing with GMOS observation files in ORAC-DR

This module provides methods for handling Frame objects that are
specific to GMOS. It provides a class derived from
B<ORAC::Frame::GEMINI>.

=cut

# A package to describe a GMOS group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::GMOS;
use ORAC::Constants;
use ORAC::Print;
use NDF;
use Starlink::HDSPACK qw/copobj/;

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# Let the object know that it is derived from ORAC::Frame::GEMINI;
use base qw/ORAC::Frame::GEMINI/;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::GEMINI>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::GMOS> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::GMOS;
   $Frm = new ORAC::Frame::GMOS("file_name");
   $Frm = new ORAC::Frame::GMOS("UT","number");

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
  $self->rawfixedpart('N');
  $self->rawsuffix('.fits');
  $self->rawformat('GMEF');
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  # Dirty hacks
  $self->uhdr("ORAC_OBSERVATION_MODE", "imaging");

  return $self;

}

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
  my $hdr_ext = $self->file.".header";

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

    my ($href, $status) = fits_read_header($rootfile . ".$kluge");
    # Store the header associated with this subframe
    $self->hdr->{$i} = $href if $status == &NDF::SAI__OK;

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

=back

=head2 General Methods

=over 4

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
GMOS.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the GMOS case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = pattern_from_bits($prefix, $obsnum);

  # Replace prepend  '.', drop the suffix and append '.ok'
  my $suffix = $self->rawsuffix;
  $raw =~ s/$suffix$//;
  my $flag = ".$raw.ok";

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

  my ($number);

  # Get the number from the raw data filename
  # Leading zeroes are dropped

  my $raw = $self->raw;
  if (defined $raw && $raw =~ /N(\d+)_(\d+).sdf$/) {
    # Drop leading 00
    $number = $2 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

$fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for GMOS.

=cut

sub file_from_bits { 
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  return $self->rawfixedpart . $prefix . 'S' . $obsnum . $self->rawsuffix;

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
  # If NFILES equals 1 we don't need to do anything
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



=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 AUTHORS

Paul Hirst <p.hirst@jach.hawaii.edu>
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
