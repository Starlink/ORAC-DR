package ORAC::Group;

# A package to describe the GROUP entity for the pipeline

use 5.004;
use Carp;
use strict;
use vars qw/$VERSION/;


$VERSION = undef; # -w protection
$VERSION = '0.10';

# Setup the object structure


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

sub file {
  my $self = shift;
  if (@_) { $self->{File} = $self->stripfname(shift); }
  return $self->{File};
}


sub name {
  my $self = shift;
  if (@_) { $self->{Name} = shift;}
  return $self->{Name};
}

# Method to populate the header with a hash
# Requires a hash reference and returns a hash reference

sub header {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Header} = $arg;
  }


  return $self->{Header};
}

# Method to return the recipe name
# If an argument is supplied the recipe is set to that value
# The recipe name can not be set automatically since it relies
# on the members of the group.

sub recipe {
  my $self = shift;
  if (@_) { $self->{Recipe} = shift;}
  return $self->{Recipe};
}


# Method to set/return all members of the group
# This takes an array as input
# An array is returned

sub members {
  my $self = shift;
  if (@_) { @{ $self->{Members} } = @_;}
  return @{ $self->{Members} };
}
 
# This method returns the reference to the array

sub aref {
  my $self = shift;
  return $self->{Members};
}




# General methods

# Method to read header information from the file directly
# Put it separately so that we do not need to specify how we read
# header or whether we include NDF extensions
# Returns reference to hash
# No input arguments - only assumes that the object knows the name of the
# file associated with it

sub readhdr {

  my $self = shift;
  
  # Just read the NDF fits header
  my ($ref, $status) = fits_read_header($self->file);

  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);

  return $ref;

}

# Supply a method to access individual pieces of header information
# Without forcing the user to access the hash directly

sub hdr {
  my $self = shift;

  my $keyword = shift;

  return ${$self->header}{$keyword};
}



# Methods for dealing with the members

# Method to push data onto the group
# Multiple members can be added in one go

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

sub num {

  my $self = shift;

  return $#{$self->aref};

}
