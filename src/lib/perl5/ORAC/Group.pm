package ORAC::Group;

=head1 NAME

ORAC::Group - base class for dealing with observation groups in ORACDR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group("group1");

  $Grp->file("Group_file_name");
  $group_name = $Grp->name;
  $Grp->push("frame2");
  $total_in_group = $Grp->num;
  $frame3 = $Grp->frame(2);

=head1 DESCRIPTION

This module provides the basic methods available to all
ORAC::Group objects. This class should be used when 
storing information relating to a group of observations
processed in the ORACDR data reduction pipeline.


=cut


# A package to describe the GROUP entity for the pipeline

use 5.004;
use Carp;
use strict;
use vars qw/$VERSION/;

$VERSION = undef; # -w protection
$VERSION = '0.10';

# Setup the object structure


=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of a ORAC::Group object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group;
   $Grp = new ORAC::Group("group_name");

=cut

# NEW - create new instance of Frame

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $group = {};  # Anon hash

  $group->{Name} = undef;
  $group->{Members} = [];
  $group->{Header} = undef;
  $group->{File} = undef;
  $group->{Recipe} = undef;

  bless($group, $class);

  # If an arguments are supplied then we can configure the object
  # Currently the argument will simply be the group name (ID)

  if (@_) { 
    $group->name(shift);
  }

  return $group;

}


# Create some methods to access "instance" data
#
# With args they set the values
# Without args they only retrieve values


# Return/set the current file name of the object
# Make sure that the extension is not present

=item name

Set or retrieve the name of the group (ie the 
group identifier)

    $Grp->name("group_name");
    $group_name = $Grp->name;

=cut


sub name {
  my $self = shift;
  if (@_) { $self->{Name} = shift;}
  return $self->{Name};
}


=item file

Set or retrieve the filename associated with the
reduced group.

    $Grp->file("group_filename");
    $group_file = $Grp->file;

=cut


sub file {
  my $self = shift;
  if (@_) { $self->{File} = $self->stripfname(shift); }
  return $self->{File};
}



# Method to populate the header with a hash
# Requires a hash reference and returns a hash reference

=item header

Set or retrieve the hash associated with the header information
stored in the reduced group file.

    $Grp->header(\%hdr);
    $hashref = $Grp->header;

This methods takes and returns a reference to a hash.

=cut


sub header {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash reference") unless ref($arg) eq "HASH";
    $self->{Header} = $arg;
  }


  return $self->{Header};
}

# Method to return the recipe name
# If an argument is supplied the recipe is set to that value
# The recipe name can not be set automatically since it relies
# on the members of the group.

#=item recipe
#
#Set or retrieve the name of the recipe being used to reduce the
#group.
#
#    $Grp->recipe("recipe_name");
#    $recipe_name = $Grp->recipe;
#
#=cut


#sub recipe {
#  my $self = shift;
#  if (@_) { $self->{Recipe} = shift;}
#  return $self->{Recipe};
#}


# Method to set/return all members of the group
# This takes an array as input
# An array is returned

=item members

Set or retrieve the array containing the members of the
group.

    $Grp->members(@frames);
    @frames = $Grp->members;

=cut

sub members {
  my $self = shift;
  if (@_) { @{ $self->{Members} } = @_;}
  return @{ $self->{Members} };
}
 
# This method returns the reference to the array

=item aref

Set or retrieve the reference to the array containing the members of the
group.

    $Grp->aref(\@frames);
    $arrayref = $Grp->aref;

=cut


sub aref {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not an array reference") unless ref($arg) eq "ARRAY";
    $self->{Members} = $arg;
  }

  return $self->{Members};
}


# General methods


# Supply a method to access individual pieces of header information
# Without forcing the user to access the hash directly

=item hdr

This method allows specific entries in the header to be accessed.
The header must be available (set by the "header" method).
The input argument should correspond to the keyword in the header
hash.

  $tel = $Grp->("TELESCOP");
  $instrument = $Grp->("INSTRUME");

=cut


sub hdr {
  my $self = shift;

  my $keyword = shift;

  return ${$self->header}{$keyword};
}



# Methods for dealing with the members

# Method to push data onto the group
# Multiple members can be added in one go

=item push

Method to push an observation into the group. Multiple observations
can be pushed on at once (see L<perl> "push()" command).

  $Grp->push("observation2");
  $Grp->push(@obs);

There are no return arguments.

=cut

sub push {
  my $self = shift;
  if (@_) {
    push(@{$self->{Members}}, @_);
  }
}

# Method to access a member by number

# Must supply a number
# Optionally can also supply a value that the nth frame should take
# Presumed to contain objects derived from ORAC::Frame

=item frame

Retrieve or set the nth frame of the group.
Counting starts at 0 as for a standard perl array.

  $obj = $Grp->frame(2);

A second argument can be used to set the nth frame.

  $Grp->frame(3, $obj);


=cut

sub frame {

  my $self = shift;

  my $number = shift;

  # Seems that we are setting the value
  if (@_) { ${$self->aref}[$number] = shift; }

  # Return the value
  return ${$self->aref}[$number];
}


# Method to return the number of frames in a group
# Same style as for $#array.

=item num

Return the number of frame in a group minus one.
This is identical to the $# construct.

  $number_of_frames = $Grp->num;

=cut

sub num {

  my $self = shift;

  return $#{$self->aref};

}


=item membernumbers

Return a list of all the observation numbers associated with
the group. This is achieved by invoking the number() method for
each object stored in the Members array.
For this to work each member must be an object capable of invoking
numbers() (e.g. ORAC::Frame). Currently the routine does not check
to make sure this is possible - the program will die if you try
to use a SCALAR.

  @numbers = $Grp->membernumbers;

=cut

sub membernumbers {

  my $self = shift;

  my @list = ();
  foreach my $member ($self->members) {

    push(@list, $member->number);

  }
  return @list;
}

=item membernames

Return a list of all the files associated with
the group. This is achieved by invoking the file() method for
each object stored in the Members array.
For this to work each member must be an object capable of invoking
numbers() (e.g. ORAC::Frame). Currently the routine does not check
to make sure this is possible - the program will die if you try
to use a SCALAR.

If an argument list is given the file names for each member of the
group are updated. This will only be attempted if the number of 
arguments given matches the number of members in the group.

  $Grp->membernames(@newnames);
  @names = $Grp->membernames;

=cut

sub membernames {

  my $self = shift;

  # If arguments are supplied use the values to update the
  # filenames in each frame
  if (@_) {
    # Only attempt this if the number of arguments supplied matches
    # The number of members in the group
    if ($self->num == $#_) {
      foreach my $member ($self->members) {
	my $newname = shift;
	$member->file($newname);
      }
    }

  }

  # Now return the list of names associated with each member
  my @list = ();
  foreach my $member ($self->members) {

    push(@list, $member->file);

  }
  return @list;
}

=item inout

Method to return the current filenames for each frame in the
group (similar to the membernames() method) and a set of output
names for each file. This is achieved by calling the inout()
method for each frame in turn. This will fail if the members of the
group do not possess the inout() method.

This method takes one argument (the new suffix) and 
returns references to two arrays.

  ($inref, $outref) = $Grp->inout("suffix");

=cut

sub inout {

  my $self = shift;

  # Find the suffix
  my $suffix = shift;

  # Initialise the output arrays
  my @in = ();
  my @out = ();

  # Now loop over the members
  foreach my $member ($self->members) {

    # Retrieve the input and output names of these files
    my ($in, $out) = $member->inout($suffix);
    push(@in, $in);
    push(@out, $out);

  }

  # Return the array references
  return \@in, \@out;

}

=item updateout

This method updates the current filename of each member of the group
when supplied with a suffix. The inout() method (of the individual frame)
is invoked for each member to generate the output name.

  $Grp->updateout("suffix");

This can be used to update the member filenames after an operation
has been applied to every file in the group. Alternatively the 
membernames() method can be invoked with the output of the inout()
method.

=cut

sub updateout {
  my $self = shift;

  my $suffix = shift;
  
  # Now loop over the members
  foreach my $member ($self->members) {

    my ($in, $out) = $member->inout($suffix);
    $member->file($out);
  }

  return 1;
}

=item template()

Method to change all the current filenames in the group so that they
match the supplied template. This method invokes the template
method for each member of the group.

  $Grp->template("filename_template");

There are no return arguments. The intelligence for this method resides
in the individual frame objects.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  # Loop over the members
  foreach my $member ($self->members) {
    $member->template($template);
  }
}

=item lastmember

Method to determine whether the supplied argument
matches the last member of the group. Returns a 1 if
it is the last member and a zero otherwise.

   $islast = $Grp->lastmember($Frm);

=cut

sub lastmember {
  my $self = shift;
  my $member = shift;

  if ($member eq $self->frame($self->num)) {
    return 1;
  }

  return 0;
}


=item reduce

Method to return all members of the group that should be processed
during the current pipeline loop. Currently this always returns
the last member of the group (ie most recent addition).
The intention is that this method is modified when necessary so that
it returns a list of all frames that should be rereduced

=cut

sub reduce {
  my $self = shift;

  return $self->frame($self->num);

}


=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=cut

# Private method for removing file extensions from the filename strings
# In the base class this does nothing. It is up to the derived classes
# To do something special with this.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For the base class this method
does nothing. It is intended for derived classes (e.g. so that ".sdf"
can be removed). Granted that I could simply force the "file" method
to be modified for derived classes....(which is why this method is
private).

=cut

sub stripfname {

  my $self = shift;
  my $name = shift;
  return $name;
}


=back

=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=cut
