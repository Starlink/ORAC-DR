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

Any file extensions (e.g. .sdf or .fits) are removed from this
string.

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

=item recipe

Set or retrieve the name of the recipe being used to reduce the
group.

    $Grp->recipe("recipe_name");
    $recipe_name = $Grp->recipe;

=cut


sub recipe {
  my $self = shift;
  if (@_) { $self->{Recipe} = shift;}
  return $self->{Recipe};
}


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

=head1 REQUIREMENTS

Currently this module requires the NDF module.
This is probably a bug...


=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
    

=cut
