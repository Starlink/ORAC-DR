package ORAC::Group::UFTI;

=head1 NAME

ORAC::Group::UKIRT - UKIRT class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::UFTI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to UFTI. It provides a class derived from B<ORAC::Group>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::UFTI> objects.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use vars qw/$VERSION/;
use ORAC::Group;
 
# Let the object know that it is derived from ORAC::Frame;
@ORAC::Group::UFTI::ISA = qw/ORAC::Group/;

 '$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
 
# standard error module and turn on strict
use Carp;
use strict;
 
# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.
=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::UFTI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::UFTI;
   $Grp = new ORAC::Group::UFTI("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('g');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}

=head2 General Methods

=over 4

=item B<readhdr>

Reads the header from the reduced group file (the filename is stored
in the Group object) and sets the Group header. The reference to the
header hash is returned. This method sets the
header in the object from the file.

    $Grp->readhdr;

All exisiting header information is lost.  If there is an error during
the read an empty hash is stored.

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

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. For UFTI we strip all extensions of the
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


=item fixedpart

Set or retrieve the part of the group filename that does not
change between invocation. The output filename can be derived using
this. Defaults to 'g'

    $Grp->fixedpart("g");
    $prefix = $Grp->fixedpart;

=cut


sub fixedpart {
  my $self = shift;
  if (@_) { $self->{FixedPart} = shift;};
  unless (defined $self->{FixedPart}) {
    $self->{FixedPart} = 'g';
  };
  return $self->{FixedPart};
}



=back

=head1 REQUIREMENTS

Currently this module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (t.jenness@jach.hawaii.edu)
    

=cut

 
1;
