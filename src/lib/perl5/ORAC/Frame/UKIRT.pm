package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use vars qw/$VERSION/;
use ORAC::Frame;
use ORAC::Constants;
 
# Let the object know that it is derived from ORAC::Frame;
use base qw/ORAC::Frame/;
 
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

 
# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=item B<erase>

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



=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

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

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'DRRECIPE FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if ($recipe !~ /./) {
    $recipe = 'QUICK_LOOK';
  } 

  # Update
  $self->recipe($recipe);

  return $recipe;
}

=item B<readhdr>

Reads the header from the observation file (the filename is stored in
the object).  This method sets the header in the object (in general
that is done by configure() ).

    $Frm->readhdr;

The filename can be supplied if the one stored in the object
is not required:

    $Frm->readhdr($file);

All exisiting header information is lost. The calc_orac_headers()
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no input or return arguments.

=cut

sub readhdr {
  
  my $self = shift;

   my ($ref, $status);
  
  if (@_) {
    
    ($ref, $status) = fits_read_header(shift);
    
  } else {
    
    # Just read the NDF fits header
    ($ref, $status) = fits_read_header($self->file);
    
  }

  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);

  # Update the contents
  %{$self->hdr} = %$ref;

  # calc derived headers
  $self->calc_orac_headers;

  return;
}



=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot (or .gz as well)
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//;
  
  return $name;
}


=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
