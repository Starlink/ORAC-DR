package ORAC::Group::UKIRT;
=head1 NAME

ORAC::Group::UKIRT - UKIRT class for dealing with observation groups in ORACDR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::UKIRT("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to UKIRT. It provides a class derived from ORAC::Group.
All the methods available to ORAC::Group objects are available
to ORAC::Group::UKIRT objects. Some additional methods are supplied.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use ORAC::Group;
 
# Let the object know that it is derived from ORAC::Frame;
@ORAC::Group::UKIRT::ISA = qw/ORAC::Group/;
 
 
# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=over 4

=item readhdr

Reads the header from the reduced group file (the filename is stored
in the Group object) and sets the Group header. The reference to the
header hash is returned.

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

  # Set the header in the group 
  $self->header($ref);

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
