package ORAC::Group::JCMT;

=head1 NAME

ORAC::Group::JCMT - JCMT class for dealing with observation groups in ORACDR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::JCMT("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to JCMT. It provides a class derived from ORAC::Group.
All the methods available to ORAC::Group objects are available
to ORAC::Group::JCMT objects. Some additional methods are supplied.

=cut
 
# A package to describe a UKIRT group object for the
# ORAC pipeline
 
use 5.004;
use ORAC::Group;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Group::JCMT::ISA = qw/ORAC::Group/;

 
# standard error module and turn on strict
use Carp;
use strict;

# For reading the header
use NDF;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=over 4

=cut

# Same as for Group.pm except that we use '_dem_' for the fixed part.
# and .sdf for the suffix

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $group = {};  # Anon hash

  $group->{Name} = undef;
  $group->{Members} = [];
  $group->{Header} = undef;
  $group->{File} = undef;
  $group->{Recipe} = undef;
  $group->{FixedPart} = '_grp_';
  $group->{FileSuffix} = '.sdf';

  bless($group, $class);

  # If an arguments are supplied then we can configure the object
  # Currently the argument will simply be the group name (ID)

  if (@_) { 
    $group->name(shift);
  }

  return $group;

}


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

=item file_from_bits

Method to return the group filename derived from a fixed
variable part (eg UT) and a group designator (usually obs
number). The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num");

Returns file of form UT_dem_00num.sdf

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;

  my $padnum = '0'x(4-length($num)) . $num;

  return $prefix . $self->fixedpart . $padnum . $self->filesuffix;

}



=back

=head1 NEW METHODS

This section describes methods that are available to the
JCMT implementation of ORAC::Group.

=over 4

=item membernamessub

Return list of file names associated with the specified
sub instrument.

  @names = $Grp->membernamessub($sub)

=cut

sub membernamessub {

  my $self = shift;
  my $sub = lc(shift);

  my @list = ();

  # Loop through each frame
  foreach my $frm ($self->members) {

    # Loop through each sub instrument
    my @subs = $frm->subs;
    for (my $i=0; $i < $frm->nsubs; $i++) {
      push (@list, $frm->file($i+1)) if $sub eq lc($subs[$i]);
    }
  }

  return @list;

}

=item grpoutsub

Method to determine the group filename associated with
the current sub-instrument.

This method uses the file() method to determine the
group rootname and then tags it by the specified sub-instrument.

  $file = $Grp->grpoutsub($sub);

=cut

sub grpoutsub {
  my $self = shift;

  # dont bother checking whether something was specified
  my $sub = shift;

  # Retrieve the root name
  my $file = $self->file;

  # Set suffix
  my $suffix = '_' . lc($sub);

  # Append the sub-instrument (don't if the sub is already there!
  $file .= $suffix unless $file =~ /$suffix$/;

  return $file;
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
