package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Obs = new ORAC::Frame::UKIRT("filename");
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
@ORAC::Frame::UKIRT::ISA = qw/ORAC::Frame/;
 
 
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
 
   $Obs = new ORAC::Frame::UKIRT;
   $Obs = new ORAC::Frame::UKIRT("file_name");
   $Obs = new ORAC::Frame::UKIRT("UT","number");

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
  $frame->{Nsubs} = undef;
  $frame->{Subs} = [];
  $frame->{Filters} = [];
  $frame->{WaveLengths} = [];
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = 'ro'; 
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



=item readhdr

Reads the header from the observation file (the filename is stored
in the object). The reference to the header hash is returned.
This method does not set the header in the object (in general that
is done by configure() ).

    $hashref = $Grp->readhdr;

If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no input arguments.

=cut

sub readhdr {

  my $self = shift;
  
  # Just read the NDF fits header
  my ($ref, $status) = fits_read_header($self->file);

  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);

  return $ref;
}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//;
  
  return $name;
}


=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
