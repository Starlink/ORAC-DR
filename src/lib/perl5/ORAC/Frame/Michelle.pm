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
  
  orac_err("Can't open $file for nsubs") unless $status == &NDF::SAI__OK;
  
  dat_ncomp($loc, $ncomp, $status);
  
  return $ncomp;
  
  dat_annul($loc, $status);
}

=item inout

Copes with non-existence of HDS container and handles NDF subframes

=cut

sub inout {

  my $self = shift;
 
  my $suffix = shift;

  # Read the number
  my $num = 1; 
  if (@_) { $num = shift; }
  
  my $infile = $self->file($num);


  # Chop off at last underscore
  # Must be able to do this with a clever pattern match
  # Want to use s/_.*$// but that turns a_b_c to a and not a_b

  my ($root,$rest) = split(/\./,$infile,2);


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

  # Now append the suffix to the outfile
  $outfile .= $suffix;
  if (defined $rest) {
    unless (-e $outfile.".sdf") {
      my ($loc,$status);
      my @null = (0);
      
      hds_new ($outfile,substr($outfile,0,8),"MICHELLE_HDS",0,@null,$loc,$status);
      dat_annul($loc, $status);
      orac_err("Failed to create HDS container!") if $status != &NDF::SAI__OK;
    }
  
    $outfile .= ".".$rest;
  }

  return ($infile, $outfile);
}




=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
