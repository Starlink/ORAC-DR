package ORAC::Frame;

=head1 NAME

ORAC::Frame - base class for dealing with observation frames in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame;

  $Obs = new ORAC::Frame("filename");
  $Obs->file("prefix_flat");
  $num = $Obs->number;  


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Frame
objects. This class should be used when dealing with individual
observation files (frames).

=cut


use strict;
use Carp;
use vars qw/$VERSION/;

$VERSION = undef; # -w protection
$VERSION = '0.10';




# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of a ORAC::Frame object.
This method takes an optional argument containing the
name of the raw file associated with the observation. If the
filename is supplied the configure() method is run in
addition to new().
The object identifier is returned.

   $Obs = new ORAC::Frame;
   $Obs = new ORAC::Frame("file_name");


=cut


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
  $frame->{UserHeader} = {};

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


# Method to return/set the filename of the raw data
# Initially this is the same as {File}


=item raw

This method returns (or sets) the name of the raw data file
associated with this object.

  $Obs->raw("raw_data");
  $filename = $Obs->raw;

=cut

sub raw {
  my $self = shift;
  if (@_) { $self->{RawName} = shift; }
  return $self->{RawName};
}


# Return/set the current file name of the object
# Make sure that the extension is not present

=item file

This method sets or returns the current filename.  Note that the raw()
method is used for the raw (ie unprocessed) data file.
This method can be used to determine the current state of the
object. Primitive writers can set this to the current output
name whenever they process a data file associated with this object.
The stripfname method is invoked on the file. 

  $Obs->file("new_dark");
  $current = $Obs->file;

=cut

sub file {
  my $self = shift;
  if (@_) { $self->{File} = $self->stripfname(shift); }
  return $self->{File};
}



# Method to return group
# If an argument is supplied the group is set to that value
# If the group is undef then the findgroup method is invoked to set it


=item group

This method returns the group name associated with the observation.
If the object has a value of undef (ie a new object) the findgroup()
method is automatically invoked to determine the group. Subsequent
invocations of the group method will simply return the current value.
The group name can be set explicitly but in general the automatic
lookup should be used.

  $group_name = $Obs->group;
  $Obs->group("group");

=cut


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


=item recipe

This method returns the recipe name associated with the observation.
If the object has a value of undef (ie a new object) the findrecipe()
method is automatically invoked to determine the recipe. Subsequent
invocations of the method will simply return the current value.
The recipe name can also be set explicitly but in general this behaviour
would be superceded by ORAC::Group objects.

  $recipe_name = $Obs->recipe;
  $Obs->recipe("recipe");

=cut


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

=item header

Set or retrieve the hash associated with the header information
stored for the observation.

    $Obs->header(\%hdr);
    $hashref = $Obs->header;

This methods takes and returns a reference to a hash.

=cut


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

=item readhdr

A method that is used to read header information from an observation
file. This method returns an empty hash by default since the base
class does not know the format of the file associated with an
object.

=cut


sub readhdr {

  my $self = shift;

  return {};
  
}

# Supply a method to access individual pieces of header information
# Without forcing the user to access the hash directly

=item hdr

This method allows specific entries in the header to be accessed.
The header must be available (set by the "header" method).
The input argument should correspond to the keyword in the header
hash.

  $tel = $Obs->hdr("TELESCOP");
  $instrument = $Obs->hdr("INSTRUME");

Can also be used to set values in the header.

  $Obs->hdr("INSTRUME", "IRCAM");

=cut

sub hdr {
  my $self = shift;

  my $keyword = shift;

  if (@_) { ${$self->header}{$keyword} = shift; }

  return ${$self->header}{$keyword};
}



# Method to configure the object.
# Assumes that the filename is available

=item configure

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), header(), group() and recipe() methods are
invoked by this command. Arguments are not required.

=cut

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

  # Return something
  return 1;
}


# Supply a method to find the group name and set it

=item findgroup

Method to determine the group to which the observation belongs.
The default method is to look for a "GRPNUM" entry in the header.

  $group = $Obs->findgroup;

=cut

sub findgroup {
  my $self = shift;

  # Simplistic routine that simply returns the GRPNUM
  # entry in the header

  return $self->hdr('GRPNUM');

}


# Supply a method to find the recipe name and set it

=item findgroup

Method to determine the recipe name that should be used to reduce
the observation.
The default method is to look for a "RECIPE" entry in the header.

  $recipe = $Obs->findrecipe;

=cut


sub findrecipe {
  my $self = shift;

  # Simplistic routine that simply returns the RECIPE
  # entry in the header

  return $self->hdr('RECIPE');

}


# Supply a method to return the number associated with the observation

=item number

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Obs->number;

=cut


sub number {

  my $self = shift;

  my ($number);

  # Get the number from the raw data
  # Assume there is a number at the end of the string
  # (since the extension has already been removed)
  # Leading zeroes are dropped

  if ($self->raw =~ /(\d+)(\.\w+)?$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}


=item inout

Method to return the current input filename and the 
new output filename given a suffix.
For the base class the suffix is simply appended to the
input name.

Note that this method does not set the new 
output name in this object. This must still be done by the
user.

Returns $in and $out in an array context:

   ($in, $out) = $Obs->inout($suffix);

=cut

sub inout {

  my $self = shift;
 
  my $suffix = shift;
  
  my $infile = $self->file;
  my $outfile = $self->file . $suffix;

  return ($infile, $outfile);
}

=item template

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Obs->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}


=item userheader

Set or retrieve a hash containing general purpose information
about the frame. This is distinct from the Frame header
(see header()) that is associated with the FITS header.

    $Obs->userheader(\%hdr);
    $hashref = $Obs->userheader;

This methods takes and returns a reference to a hash.

=cut


sub userheader {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{UserHeader} = $arg;
  }


  return $self->{UserHeader};
}


=item uhdr

This method allows specific entries in the user specified header to 
be accessed. The header must be available (set by the "userheader" method).
The input argument should correspond to the keyword in the header
hash.

  $info = $Obs->uhdr("INFORMATION");

Can also be used to set values in the header.

  $Obs->uhdr("INFORMATION", "value");

=cut

sub uhdr {
  my $self = shift;

  my $keyword = shift;

  if (@_) { ${$self->userheader}{$keyword} = shift; }

  return ${$self->userheader}{$keyword};
}



# Private method for removing file extensions from the filename strings

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

L<ORAC::Group>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
Frossie Economou (frossie@jach.hawaii.edu)    

=cut

1;

