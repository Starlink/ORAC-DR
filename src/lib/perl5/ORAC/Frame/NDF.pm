package ORAC::Frame::NDF;

=head1 NAME

ORAC::Frame::NDF - Class for dealing with frames based on NDF files

=head1 SYNOPSIS

  use ORAC::Frame::NDF

  $Frm = new ORAC::Frame::NDF;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the NDF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Frame) rather than directly from
ORAC::Frame. For JCMT and UKIRT the group files are based on NDFs and
inherit from this class.

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use ORAC::Frame;

# Inherit from ORAC::Group
use base qw/ORAC::Frame/;

use warnings;
use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# We need to read NDF files
use NDF 1.43;

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<erase>

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specifies the file number to be erased.
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


=item B<file_exists>

Checks for the existence of the frame file(). Assumes a C<.sdf>
extension.

  $exists = $Frm->exists($i)

The optional argument specifies the file number to be used.
All extension are removed from the file name before adding the
C<.sdf> so that HDS containers can be supported (and files
that already have the extension)  -- but note that
this version of the method does not look inside HDS containers
looking for NDFs.

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file(@_);

  # Strip anything after the first dot (in case extensions already
  # present)
  $file =~ s/\..*$//;

  # Check for file existence
  if (-e "$file.sdf") {
    return 1;
  } else {
    return 0;
  }
}

=item B<readhdr>

Reads the header from the observation file (the filename is stored in
the object).  This method sets the header in the object (in general
that is done by configure() ).

    $Frm->readhdr;

The filename can be supplied if the one stored in the object
is not required:

    $Frm->readhdr($file);

but the header in $Frm is over-written.
All exisiting header information is lost. The calc_orac_headers()
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no return arguments.

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
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//
    if defined $name;

  return $name;
}


=back

=head1 REQUIREMENTS

Currently this module requires the L<NDF> module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
