package ORAC::Frame::Michelle;

=head1 NAME

ORAC::Frame::Michelle - Michelle class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::Michelle;

  $Obs = new ORAC::Frame::Michelle("filename");
  $Obs->file("file")
  $Obs->readhdr;
  $Obs->configure;
  $value = $Obs->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to Michelle. It provides a class derived from ORAC::Frame.
All the methods available to ORAC::Frame objects are available
to ORAC::Frame::Michelle objects. Some additional methods are supplied.

=cut
 
# A package to describe a Michelle group object for the
# ORAC pipeline
 
use 5.004;
use ORAC::Frame;
 
# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Frame::Michelle::ISA = qw/ORAC::Frame::UKIRT/;
use base  qw/ORAC::Frame::UKIRT/;
 
# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=over 4

=cut
 
=item new
 
Create a new instance of a ORAC::Frame::Michelle object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.
 
   $Obs = new ORAC::Frame::Michelle;
   $Obs = new ORAC::Frame::Michelle("file_name");
   $Obs = new ORAC::Frame::Michelle("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'c' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash

  $frame->{RawName} = undef;
  $frame->{RawSuffix} = '.sdf';
  $frame->{RawFixedPart} = 'c'; 
  $frame->{Header} = undef;
  $frame->{Group} = undef;
  $frame->{Files} = [];
  $frame->{Nsubs} = undef;
  $frame->{Recipe} = undef;
  $frame->{UserHeader} = {};
  $frame->{Format} = undef;
  $frame->{IsGood} = 1;


  bless($frame, $class);

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  # This could be extended to include a reference to a hash holding the
  # header info but this may well compromise the object since
  # the best way to generate the header (including extensions) is to use the
  # readhdr method.

  if (@_) { 
    $frame->configure(@_);
  }

  return $frame;

}

=item configure

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), header(), group() and recipe() methods are
invoked by this command. Arguments are required.
If there is one argument it is assumed that this is the
raw filename. If there are two arguments the filename is
constructed assuming that arg 1 is the prefix and arg2 is the
observation number.

  $Obs->configure("fname");
  $Obs->configure("UT","num");

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

 # Populate the header
  # for hds container set header NDF to be in the .header extension
  my $hdr_ext = $self->file.".header";

  $self->header($self->readhdr($hdr_ext));

  # Set the raw data file name

  $self->raw($fname);

  # We have as many files as there are NDF compenents, minus the header component
  $self->nsubs($self->findnsubs - 1);

  # populate file method

  for my $i (1..$self->nsubs) {

    # Set the filename

    $self->file($i,$rootfile.".i$i");

  };



  # Find the group name and set it
  $self->group($self->findgroup);

  # Find the recipe name
  $self->recipe($self->findrecipe);

  

  # Return something
  return 1;
}

=item findnsubs

This method returns the number of NDFs found in an HDS container

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
  dat_ncomp($loc, $ncomp, $status);
  dat_annul($loc, $status);

  orac_err("Can't open $file for nsubs") unless $status == &NDF::SAI__OK;
  
  return $ncomp;
  

}

=item inout

Copes with non-existence of HDS container and handles NDF subframes

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

=cut

sub inout {

  my $self = shift;
 
  my $suffix = shift;

  # Read the number
  my $num = 1; 
  if (@_) { $num = shift; }
  
  my $infile = $self->file($num);

  # Split infile into a root and a tail
  my ($root, $rest) = $self->split_name($infile);

  # Chop off at last underscore
  # Must be able to do this with a clever pattern match
  # Want to use s/_.*$// but that turns a_b_c to a and not a_b
  # instead split on underscore and recombine using underscore
  # but ignoring the last member of the split array
  my (@junk) = split(/_/,$root);

  # We only want to drop the SECOND underscore. If we only have
  # two components we simply append. If we have more we drop the last
  # This prevents us from dropping the observation number in 
  # ro970815_28

  my $outfile;
  if ($#junk > 1) {
    $outfile = join("_", @junk[0..$#junk-1]);
  } else {
    $outfile = $root;
  }

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Now append the suffix to the outfile
  $outfile .= $suffix;

  # If we had a suffix (eg .i1) now need to
  # reattach it and create an HDS container *IF* NFILES is greater than 1
  # If NFILES equals 1 
  if (defined $rest && $nfiles > 1) {
    unless (-e $outfile.".sdf") {
      my ($loc,$status);
      my @null = (0);
      
      hds_new ($outfile,substr($outfile,0,9),"MICHELLE_HDS",0,@null,$loc,$status);
      dat_annul($loc, $status);
      orac_err("Failed to create HDS container!") if $status != &NDF::SAI__OK;
    }
  
    $outfile .= ".".$rest;
  }

  return ($infile, $outfile);
}


=item gui_id

Calculate the ID for the display system. Uses the last suffix
as a key (not including dots). If nfiles>1 an 's' followed
by a number (reflecting the file number requested) is prepended
to the string.

 eg s2dk from c19991231_1_dk.i2

If only one underscore is found (ie a raw number with no data
reduction suffix) 'num' is returned along with the image
identifier if multiple sub-frames are present

 eg  s2num from c19991231_1.i2
     s3num from c19991231_1.i3

Argument: sub-frame number

=cut

sub gui_id {
  my $self = shift;
  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  # Retrieve the Nth file name (start counting at 1)
  my $fname = $self->file($num);

  # Split infile into a root and a tail
  my ($root, $rest) = $self->split_name($fname);

  # Split on underscore
  my (@split) = split(/_/,$root);

  # If there are > 2 chunks then we have a real suffix
  # else we have a raw data
  my $id;
  if ($#split > 1) {
    $id = $split[-1];
  } else {
    $id = 'num';
  }

  # Find out how many files we have 
  my $nfiles = $self->nfiles;

  # Prepend with s$num if nfiles > 1
  $id = "s$num" . $id if $nfiles > 1;

  return $id;

}

=back

=head1 PRIVATE METHODS

=over 4

=item split_name

Internal routine to split a 'file' name into an actual
filename (the HDS container) and the NDF name (the
thing inside the container).

Splits on '.'

Argument: string to split (eg test.i1)
Returns:  root name, ndf name (eg 'test' and 'i1')

NDF name is undef if there are no 'sub-frames'.

This routine is so simple that it may not be worth the effort.

=cut

sub split_name {
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

L<ORAC::Frame::UKIRT>

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
