package ORAC::Group::JCMT_DAS;

=head1 NAME

ORAC::Group::JCMT_DAS - JCMT DAS class for dealing with observation
groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::JCMT_DAS;

  $Grp = new ORAC::Group::JCMT_DAS("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to DAS observations taken at the JCMT. It provides
a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::JCMT_DAS> objects. Some additional methods are supplied.

=cut

use 5.006;
use strict;
use warnings;
use Carp;
use ORAC::Group::NDF;

# Let the object know that it is derived from ORAC::Frame;
use base qw/ ORAC::Group::NDF /;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::JCMT_DAS> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::JCMT_DAS;
   $Grp = new ORAC::Group::JCMT_DAS("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of '_grp_'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('_grp_');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}


=back

=head2 General Methods

=over 4

=item B<file>

This is an extension to the default file() method.
This method accepts a root name for the group file
(independent of sub-instrument) - same as for the base 
class. If a number is supplied the root name is returned
with the appropriate extension relating to the 
sub-instrument order in the current frame.

The number to sub-instrument conversion uses the last frame in the
group to calculate the allowed number of sub-instruments and
the order. Note that this may well not be what you want.
Use the grpoutsub() method if you know the name of the sub-instrument.

=cut

sub file {

  my $self = shift;

  if (@_) {
    # There is either a string here or a number.
    my $arg = shift;

    # Now check to see if we have a number
    if ($arg =~ /^\d+$/) {

      # Get a copy of the last frame in the group
      # This will cause problems if frames in the group
      # have different sub instruments and the last frame
      # is not representative (since it could be just an LONG
      # without that SHORT even thought the rest of the group used
      # SHORT).
      # Currently it at least matches the behaviour of num_files()

      my $frm = $self->frame($self->num);
      my @subs = $frm->subs;
      # Number is 1 more than the array member
      my $sub = $subs[$arg - 1];

      my $file = $self->grpoutsub($sub);
      return $file;

    } else {
      # No number so we just assume this is a root name
      # and set it
      $self->{File} = $self->stripfname($arg);
    }

  }
  # Return the current value
  # If a number has been supplied then we return at another
  # section of code
  return $self->{File};
}

=item B<file_from_bits>

Method to return the group filename derived from a fixed
variable part (eg UT) and a group designator (usually obs
number). The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num");

Returns file of form UT_grp_00num.sdf

Note that this is the filename before sub-instruments
have been taken into account (essentially this is the
default root name for file() - the suffix is stripped).

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;

  my $padnum = '0'x(4-length($num)) . $num;

  return $prefix . $self->fixedpart . $padnum . $self->filesuffix;

}

=item B<gui_id>

The file identification for comparison with the B<ORAC::Display>
system. Input argument is the file number (starting from 1).

This routine calculates the current suffix from the group file
name base and prepends a string 'gN' signifying that this is
a group observation and the Nth frame is requested (N is less than
or equal to nfiles()).

The assumption is that file() returns a root name (ie without
a sub-instrument designation). This then allows us to create an
ID based on number and suffix without having to chop the
sub-instrument name off the end.

=cut

sub gui_id {

  my $self = shift;
  my $num = 1;
  if (@_) { $num = shift; }

  # Get the current root
  my $fname = $self->file;

  # Split on underscore
  my (@split) = split(/_/,$fname);

  # Now the default situation is that the Grp name is just
  # ut_grp_num_sub
  # in this case we don't want the GUI ID to contain the number
  # if it is a number replace it with a string 'NUM'
  # This may well be a hack since it is probably preferable that
  # use of NUM should be extended in the DISPLAY software
  if ($split[-1] =~ /^\d+$/) {
    $split[-1] = 'NUM';
  }

  return "g$num" . $split[-1];

}

=item B<nfiles>

This method returns the number of files currently associated
with the group. What this in fact means is that it returns
the number of files associated with the last member of the 
group (since that is how I construct output names in the
first place). grpoutsub() method is responsible for 
converting this number into a filename via the file() method.

=cut

sub nfiles {
  my $self = shift;

  # Find last frame
  my $frm = $self->frame($self->num);

  # Now get the number of files from that
  return $frm->nfiles;
}




=back

=head1 NEW METHODS

This section describes methods that are available to the
JCMT implementation of ORAC::Group.

=over 4

=item B<grpoutsub>

Method to determine the group filename associated with
the supplied sub-instrument.

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


=item B<membernamessub>

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



=item B<subs>

Returns an array containing all the sub instruments present
in the group (some frames may only have one sub-instrument)

  @subs = $Grp->subs;

The frames should be able to invoke the subs() method.

=cut

sub subs {
  my $self = shift;

  my %subs = ();

  # Loop over each member
  foreach my $frm ($self->members) {

    # Now store the keys
    foreach  my $sub ($frm->subs) {
      $subs{$sub}++;
    }
  }

  # Return the keys
  return keys %subs;

}




=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
