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
use ORAC::Constants;
 
# Let the object know that it is derived from ORAC::Frame;
use base qw/ORAC::Frame/;
 
 
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
  $frame->{RawSuffix} = ".sdf";
  $frame->{RawFixedPart} = 'ro'; 
  $frame->{UserHeader} = {};
  $frame->{NoKeepArr} = [];
  $frame->{Intermediates} = [];

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


=item erase

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specified the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  # Append the .sdf if required
  $file .= '.sdf' unless $file =~ /\.sdf$/;
 
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

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

   my ($ref, $status);
  
  if (@_) {
    
    ($ref, $status) = fits_read_header(shift);
    
  } else {
    
    # Just read the NDF fits header
    ($ref, $status) = fits_read_header($self->file);
    
    
  };
  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);

  return $ref;
}


=item findgroup

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');


  # Is this group name set to anything useful
  if ($hdrgrp == 0) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = $self->hdr('RUN');
    }

  }
  return $hdrgrp;

}

=item findrecipe

Find the recipe name. At the moment we perform a KLUDGE by 
only returning recipes for calibrations (specifically 
DARK observations). All other times we will return undef
and hope that the pipeline will realise that for undef it should 
take the command line override value

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if ($recipe !~ /./) {

       $recipe = 'QUICK_LOOK';


  } 
  return $recipe;


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

  $name =~ s/\.sdf$//;

  
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
