package ORAC::Frame;

use strict;
use Carp;
use vars qw/$VERSION/;

# Need to read the header from the file
use NDF;


$VERSION = undef; # -w protection
$VERSION = '0.10';




# Setup the object structure


# NEW - create new instance of Frame

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $frame = {};  # Anon hash

  $frame->{RawName} = undef;
  $frame->{Header} = undef;
  $frame->{Group} = undef;
  $frame->{File} = undef;
  $frame->{Recipe} = undef;

  bless($frame, $class);

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # This could be extended to include a reference to a hash holding the
  # header info but this may well compromise the object since
  # the best way to generate the header (including extensions) is to use the
  # readhdr method.

  if (@_) { 
    $frame->configure(@_);
  }

  return $frame;

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

# Method to return/set the filename of the raw data
# Initially this is the same as {File}
# Make sure that no extension is present (eg .sdf)

sub raw {
  my $self = shift;
  if (@_) { $self->{RawName} = $self->stripfname(shift); }
  return $self->{RawName};
}


# Method to return group
# If an argument is supplied the group is set to that value
# If the group is undef then the findgroup method is invoked to set it

sub group {
  my $self = shift;
  if (@_) { $self->{Group} = shift;}

  unless (defined $self->{Group}) {
    $self->findgroup;
  }

  return $self->{Group};
}

# Method to return the recipe name
# If an argument is supplied the recipe is set to that value
# If the recipe is undef then the findrecipe method is invoked to set it

sub recipe {
  my $self = shift;
  if (@_) { $self->{Recipe} = shift;}

  unless (defined $self->{Recipe}) {
    $self->findrecipe;
  }

  return $self->{Recipe};
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



# Method to configure the object.
# Assumes that the filename is available

sub configure {
  my $self = shift;

  my $fname = shift;

  # Set the filename
  $self->file($fname);

  # Set the raw data file name
  $self->raw($fname);

  # Populate the header
  $self->header($self->readhdr);

  # Find the group name and set it
  $self->group($self->findgroup);

  # Find the recipe name
  $self->recipe($self->findrecipe);

}


# Supply a method to find the group name and set it

sub findgroup {
  my $self = shift;

  # Simplistic routine that simply returns the GROUP 
  # entry in the header

  return $self->hdr('GROUP');

}


# Supply a method to find the recipe name and set it

sub findrecipe {
  my $self = shift;

  # Simplistic routine that simply returns the RECIPE
  # entry in the header

  return $self->hdr('RECIPE');

}


# Supply a method to return the number associated with the observation

sub number {

  my $self = shift;

  my ($number);

  # Get the number from the raw data
  # Assume there is a number at the end of the string
  # (since the extension has already been removed)
  # Leading zeroes are dropped

  if ($self->raw =~ /(\d+)$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}


# Private method for removing file extensions from the filename strings

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot
  $name =~ s/\..*//;
  
  return $name;

}


1;

