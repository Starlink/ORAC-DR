package ORAC::Frame::CGS4;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Obs = new ORAC::Frame::CGS4("filename");
  $Obs->file("file")
  $Obs->readhdr;
  $Obs->configure;
  $value = $Obs->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from ORAC::Frame.
All the methods available to ORAC::Frame objects are available
to ORAC::Frame::UKIRT objects. Some additional methods are supplied.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use ORAC::Frame;
 
# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Frame::CGS4::ISA = qw/ORAC::Frame::UKIRT/;
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
 
Create a new instance of a ORAC::Frame::UKIRT object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.
 
   $Obs = new ORAC::Frame::CGS4;
   $Obs = new ORAC::Frame::CGS4("file_name");
   $Obs = new ORAC::Frame::CGS4("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'ro' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash

  $frame->{RawName} = undef;
  $frame->{Header} = undef;
  $frame->{Group} = undef;
  $frame->{Files} = [];
  $frame->{Recipe} = undef;
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = 'c'; 
  $frame->{UserHeader} = {};

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

  # Set the filename

  $self->file($fname);

  # Set the raw data file name

  $self->raw($fname);

  # Populate the header
  # for hds container set
  my $hdr_ext = $self->file.".header";

  $self->header($self->readhdr($hdr_ext));

  # Find the group name and set it
  $self->group($self->findgroup);

  # Find the recipe name
  $self->recipe($self->findrecipe);

  # Return something
  return 1;
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
