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

$VERSION = '0.12';

# Associated classes
use ORAC::Print;          # Print statements
use ORAC::Index::Extern;  # For bad observation index list

# Setup the object structure


=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

The following constructors are available:

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
  $group->{AllMembers} = [];
  $group->{Members} = [];
  $group->{Header} = undef;
  $group->{File} = undef;
  $group->{Recipe} = undef;
  $group->{FixedPart} = undef;
  $group->{FileSuffix} = undef;
  $group->{BadObsIndex} = undef;

  bless($group, $class);

  # If an arguments are supplied then we can configure the object
  # Currently the argument will simply be the group name (ID)

  if (@_) { 
    $group->name(shift);
  }

  return $group;

}

=item subgrp

Method to return a new group (ie a subgrp of the existing
group) that contains all members of the main group matching
certain header values.

Arguments is a hash that is used for comparison with each
frame.

  $subgrp = $Grp->subgrp(NAME => 'CRL618', CHOP=> 60.0);

The new subgrp is blessed into the same class as $Grp.

This method is generally used where access to members of the
group by some search criterion is required.

It is possible that the returned group will contain no 
members....

=cut

sub subgrp {
  my $self = shift;

  # Read the input hash
  my %hash = @_;

  # Create a new grp
  my @subgrp = (); # Storage array
  my $subgrp = $self->new($self->name . "subgrp");  

  # Now loop over all members of the group and compare with
  # the hash
  foreach my $member ($self->members) {

    my $match = 1;  # Assume a match

    # We are doing a string comparison
    foreach my $key (%hash) {
      unless ($hash{$key} eq $member->hdr($key)) {
        $match = 0;
        last;
      }
    }

    # If we have matched all keys then we push onto the subgrp
    # Use a temporary array for efficiency
    push(@subgrp, $member) if $match;

  }

  # Store the matched members in the sub group
  # If we do it this way we do not have to check group membership
  # (Since we know the frames are valid since they came from the
  # members() method)
  # but we do have to set members_ref as well as allmembers_ref
  
  $subgrp->allmembers_ref(\@subgrp);
  $subgrp->members_ref(\@subgrp);

  return $subgrp;

}


=item subgrps

Returns frames grouped by the supplied header keys.
A frame can not belong to more than one sub group created by this
method:

   @grps = $Grp->subgrps(@keys);

The groups in @grps are blessed into the same class as $Grp.
For example, if @keys = ('MODE','CHOP') then you can gurantee
that the members of each sub group will have the same values
for MODE and CHOP. 

=cut

sub subgrps {
  my $self = shift;
  my @keys = @_;
  
  # We can create a unique key in a hash for the header values
  # specified. So create a temporary hash.
  my %store = ();
  
  # Loop over all members of current group

  foreach my $member ($self->members) {
    # Create a key
    my $key = "";
    foreach my $hdr (@keys) {
      $key .= $member->hdr($hdr);
    }

    # Now see whether this key already exists in the hash
    # if it doesnt we populate it with a group object
    $store{$key} = $self->new() unless exists $store{$key};
    
    # Store the frame (this is inefficient since it 
    # forces a check_membership every time and we know membership
    # is okay since members() only returns valid frames.
    $store{$key}->push($member);
    
  }

  # Return the values
  return values %store;  
}



=back

=head2 Instance methods

The following methods are available for accessing the 
'instance' data.

=over 4

=cut

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


# The default file method should be able to accept numbers
# If an integer is supplied then do nothing - simply return
# current value. This is added here so that the Display system
# can ask for multiple file names based on index - which
# is used by the Frames in some cases (eg SCUBA, MICHELLE). The Display
# sub-system does not distinguish between Groups and Frames
# so the shared methods have to be supported on both.

sub file {
  my $self = shift;
  if (@_) { 
    my $arg = shift;
    $self->{File} = $self->stripfname($arg)
      unless ($arg =~ /^\d+$/ && $arg != 0); 
  }
  return $self->{File};
}

=item filesuffix

Set or retrieve the filename suffix associated with the
reduced group.

    $Grp->filesuffix(".sdf");
    $group_file = $Grp->filesuffix;

=cut


sub filesuffix {
  my $self = shift;
  if (@_) { $self->{FileSuffix} = shift;};

  # Default to .sdf
  unless (defined $self->{FileSuffix}) {
    $self->{FileSuffix} = '.sdf';
  }

  return $self->{FileSuffix};
}

=item fixedpart

Set or retrieve the part of the group filename that does not
change between invocation. The output filename can be derived using
this. Defaults to 'rg'

    $Grp->fixedpart("rg");
    $prefix = $Grp->fixedpart;

=cut


sub fixedpart {
  my $self = shift;
  if (@_) { $self->{FixedPart} = shift;};
  unless (defined $self->{FixedPart}) {
    $self->{FixedPart} = 'rg';
  };
  return $self->{FixedPart};
}




# Method to populate the header with a hash
# Requires a hash reference and returns a hash reference

=item header

Set or retrieve the hash associated with the header information
stored in the reduced group file.

    $Grp->header(\%hdr);
    $hashref = $Grp->header;

This methods takes and returns a reference to a hash.

The header values can be accessed by using the hdr() method
or by dereferencing the return value of header():

   $value = $Grp->header->{KEY};
   $value = $Grp->hdr('KEY');

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


# This method returns the reference to the array

=item allmembers_ref

Set or retrieve the reference to the array containing the members of the
group.

    $Grp->allmembers_ref(\@frames);
    $arrayref = $Grp->allmembers_ref;

This should probably be considered a private routine. Use the members()
method to return a list of all valid members and the allmembers() method
to return a list of all Group members.

=cut

sub allmembers_ref {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("allmembers_ref: Argument is not an array reference") 
      unless ref($arg) eq "ARRAY";
    $self->{AllMembers} = $arg;

    # Check membership
    $self->check_membership;
  }

  return $self->{AllMembers};
}


# For backwards compatibility.
sub aref {
  my $self = shift;
  print "Use of this routine is deprecated - use allmembers_ref instead\n";
  if (@_) {
    $self->allmembers_ref(@_);
  }
  return $self->allmembers_ref;
}


=item members_ref

Set or retrieve the reference to the array containing the valid
members of the group.

    $Grp->members_ref(\@frames);
    $arrayref = $Grp->members_ref;

This should probably be considered a private routine. Use the members()
method to return a list of all valid members and the allmembers() method
to return a list of all Group members.

=cut

sub members_ref {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("members_ref: Argument is not an array reference") 
      unless ref($arg) eq "ARRAY";
    $self->{Members} = $arg;
  }

  return $self->{Members};
}


=item badobs_index

Return (or set) the index object associate with the bad observation
index file. A index of class ORAC::Index::Extern is used since 
this index is modified by an external user/program.

=cut

sub badobs_index {

  my $self = shift;
  if (@_) { $self->{BadObsIndex} = shift }

  # If undef we can create a new index object
  unless (defined $self->{BadObsIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.badobs";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.badobs";
    $self->{BadObsIndex} = new ORAC::Index::Extern($indexfile,$rulesfile);
  };

  return $self->{BadObsIndex}; 

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


=back

=head2 General methods

The following methods are provided for manipulating ORAC::Group
objects:

=over 4

=item file_from_bits

Method to return the group filename derived from a fixed
variable part (eg UT) and a group designator (usually obs
number). The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num");

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;

  # Follow UKIRT style
  return $self->fixedpart . $prefix . '_' . $num . $self->filesuffix;

}


# Method to set/return all members of the group
# This takes an array as input
# An array is returned

=item allmembers

Set or retrieve the array containing the objects of which the group
consists.

    $Grp->allmembers(@frames);
    @frames = $Grp->allmembers;

The setting function of this routine should only be used
if you know what you are doing (since it completely changes the group
membership).

All group members are returned regardless of the state of each member.
Use the members() method to return only valid members.

=cut

sub allmembers {
  my $self = shift;
  if (@_) { 
    @{ $self->allmembers_ref } = @_;
    $self->check_membership; # Check valid frames.
  }
  return @{ $self->allmembers_ref };
}


=item members

Set or retrieve the array containing the objects of which the group
consists.

    $Grp->members(@frames);
    @frames = $Grp->members;

This is the safest way to access the group members
since it only returns valid frames to the caller.

Use the allmembers() method to return all members of the group 
regardless of the state of the individual frames.

=cut

sub members {
  my $self = shift;
  if (@_) { @{ $self->members_ref } = @_;}
  return @{ $self->members_ref };
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
 

# General methods


# Supply a method to access individual pieces of header information
# Without forcing the user to access the hash directly

=item hdr

This method allows specific entries in the header to be accessed.
The header must be available (set by the "header" method).
The input argument should correspond to the keyword in the header
hash.

  $tel = $Grp->hdr("TELESCOP");
  $instrument = $Grp->hdr("INSTRUME");

Can also be used to set values in the header.

  $Obs->hdr("INSTRUME", "IRCAM");

If no arguments are provided, the reference to the header hash
is returned (equivalent to running the header() method).

=cut


sub hdr {
  my $self = shift;

  if (@_) {
    my $keyword = shift;

    if (@_) { $self->header->{$keyword} = shift; }

    return $self->header->{$keyword};
  }

  # No arguments, return the header hash reference
  return $self->header;
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
    push(@{ $self->allmembers_ref }, @_);
    # Check frame membership
    $self->check_membership;
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
  if (@_) { $self->members_ref->[$number] = shift; }

  # Return the value
  return $self->members_ref->[$number];
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

  return $#{$self->members_ref};

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




=item check_membership

Check whether any of the members of the group have been marked for
removal from the group. The valid group members are copied
to a new array and can be retrieved by the members() or members_ref()
methods. Note that all group methods use the list of valid group
members.

This routine is automatically run whenever the group membership
is updated (via the push() or  allmembers() methods. This may
cause too high an overhead with push() in, for example, the
subgrps method).

This method works by looking in a text file created by the
observer in $ORAC_DATA_OUT called index.badobs. This file
contains a list of numbers (two per line) relating to observations
that should be turned off. The first number is the UT date
(YYYYMMDD) and the second number is the observation
number. This is necessary so that ORAC_DATA_OUT can be reused
for a different UT date without worrying about the index file
file turning off incorrect observations.

The UT and observation number are compared with each member of
the group (the full list of members - see allmembers()).
For each group member, the following test is performed to test
for validity. First it is queried to check whether it is in a
good state (ie has been processed successfully). 
A frame will be marked as bad if the recipe fails to execute
successfully. If the frame is good (from the pipeline viewpoint)
the UT date and observation number is then compared with the
entries in the index file. If a match can B<NOT> be found the
frame is considered to be valid and is copied to the list of valid
group members (see the members() method).

The format of the index file should be of the form:

 24 19980716 
 27 19980716 
 43 19980815 
 ...

=cut

sub check_membership {
  my $self = shift;

  # Array of good frames
  my @good = ();

  # Need to loop over all members of the group
  foreach my $member ($self->allmembers) {

    # First need to see whether the the frame is in a valid
    # state -- no point continuing if not valid

    if ($member->isgood) {

      # Now compare the current frame with the bad observation
      # index list. This routine will return undef if there was
      # no match [ie a good file] and an index key if the file
      # was bad (the first matching key is returned)
      # Note that we have to make sure that the keys are in
      # alphabetical order (not very clever) since this is the
      # order constrained by the Index class and must match the
      # order used in the user-supplied index file

      my $badobs = 
          $self->badobs_index->cmp_with_hash({
					      ORACNUM => $member->number,
					      ORACUT => $member->hdr('ORACUT')
					     });

      # if the $badobs is not defined then we have a good observation
      unless (defined $badobs) {
	push (@good, $member);
      } else {
	orac_warn "Removing observation ". $member->number ." from group\n";
      }

    }

  }

  # Update the good members list
  $self->members_ref(\@good);

}


=back

=head1 DISPLAY COMPATIBILITY

These methods are provided for compatibility with the ORAC display
system.

=over 4

=item nfiles

This method is used by the display system to determine the
number of files to display. Since the Group base class can only
ever contain one file name (as returned by file()) this method
always returns a 1.

=cut

sub nfiles {
  return 1;
}

=item gui_id

Returns the identification string that is used to compare the
current frame with the frames selected for display in the
display definition file.

In the default case, this method returns everything after the
last suffix stored in file().

In some derived implementation of this method an argument
may be used so that multiple IDs can be extracted from objects
that contain more than one output file per observation.

=cut

sub gui_id {
  my $self = shift;

  my $fname = $self->file;

  # Split on underscore
  my (@split) = split(/_/,$fname);

  return $split[-1];

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
