package ORAC::Display;

=head1 NAME

ORAC::Display - Top level interface to ORAC display tools

=head1 SYNOPSIS

  use ORAC::Display;

  $Display = new ORAC::Display;
  $Display->useshm(1);
  $Display->setupfile(filename);
  $Display->display('frame/group object');
  
=head1 DESCRIPTION

This module provides an OO-interface to the ORAC display manager.
The display object reads device information from a file or notice
board (shared memory), determines whether the supplied frame object
matches the criterion for display, if it does it instructs the 
relevant device object to send to the selected window (creating
a new device object if necessary)

=cut


use 5.004;
use Carp;
use strict;

use IO::File;    
use ORAC::Print;

use ORAC::Display::P4;
use ORAC::Display::KAPVIEW;
use ORAC::Display::GAIA;

use vars qw/$VERSION $DEBUG/;

$VERSION = '0.10';
$DEBUG = 0;

=head1 PUBLIC METHODS

=over 4

=item new()

Create a new instance of ORAC::Display.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $disp = {};  # Anonymous hash

  $disp->{FileName} = undef; # Name of file containing device info
  $disp->{UseNBS} = 0;       # Use shared memory
  $disp->{Tools} = {};       # List of display tool objects
  $disp->{ID}    = undef;    # Current ID string

  bless ($disp, $class);

}

=item toolref(\%hash)

Returns (or sets) the reference to the hash containing the current
mapping from display tool to display tool object.

  $Display->toolref(\%device);
  $hashref = $Display->toolref

=cut

sub toolref {
  my $self = shift;

  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Tools} = $arg;
  }

  return $self->{Tools};
}



=item display_tools(%hash)

Returns (or sets) a hash containing the current lookup of display tool
to display tool object. For example:

   $Display->display_tools(%tools);
   %tools = $Display->display_tools;
 
where %tools could look like:

     'GAIA' => Display::GAIA=HASH(object),
     'P4'   => Display::P4=HASH(object)

etc.

=cut

sub display_tools {
  my $self = shift;
  if (@_) {
    my %junk = @_;
    $self->toolref(\%junk);
  }
  return %{$self->toolref};
}

=item filename(name)

Set (or retrieve) the name of the file containing the display device
definition. Only used when usenbs() is false.

=cut

sub filename {
  my $self = shift;
  if (@_) { $self->{FileName} = shift; }
  return $self->{FileName};
}

=item usenbs(1/0)

Determine whether NBS (shared memory) should be used to read the
display device definition. Default is false.

=cut

sub usenbs {
  my $self = shift;
  if (@_) { $self->{UseNBS} = shift; }
  return $self->{UseNBS};
}

=item filename(name)

Set (or retrieve) the value of the string used for comparison
with the display device definition information (created by the
separate device allocation GUI).

=cut

sub idstring {
  my $self = shift;
  if (@_) { $self->{ID} = shift; }
  return $self->{ID};
}



=item display_data(object, [\%hash])

This is the main method to be used for displaying data.  The supplied
object must contain a method for determining the filename and the
display ID (so that it can be compared with the information stored in
the device definition file). The available methods are file()
and  gui_id()

=cut

sub display_data {
  my $self = shift;

  # Read the name of the supplied object
  my $frm = shift;
  
  # Check that $frm is an object
  unless (ref($frm)) {
    croak 'ORAC::Display::display_data: supplied argument is not a reference';
  }

  # Read the options hash
  my $optref = shift if (@_);

  # We are going to generalise here.
  # We intend to loop over all images stored in the current object
  # This is really to support SCUBA - hope Frossie wont notice!
  # Since SCUBA has multiple files per observation I need a gui_id
  # method that can support multiple images. Note that the base version
  # of gui_id() in ORAC::Frame does not take two arguments but simply
  # throws the second arg away.

  # Get the number of files
  my $nfiles;
  if ($frm->can('nfiles')) {
    $nfiles = $frm->nfiles;
  } else {
    croak "ORAC::Display::display_data: supplied object can not implement\n".
      " the nfiles() method.";
  }
  
  # Now loop over each input file
  for (my $n = 1; $n <= $nfiles; $n++) {

    # Get the name of the gui ID
    my $frm_suffix;
    if ($frm->can('gui_id')) {
      $frm_suffix = $frm->gui_id($n);
    } else {
      croak "ORAC::Display::display_data: supplied object can not implement\n".
	" the gui_id() method";
    }

    # Set the current suffix in the object
    $self->idstring($frm_suffix);

    orac_print("Checking display definition for entry matching $frm_suffix\n",'blue');

    # Now we need to search through the display definition and
    # decide whether our suffix can be displayed anywhere.
    # Expect to have an array of hashes where each hash corresponds
    # to a matching line
    # This allows a single file to be displayed on multiple
    # devices
  
#    my %display_info = $self->definition;
    my @defn = $self->definition;

    # Now need to loop over all members of @defn
    # This will just jump out if there are no matches stored in the array
    foreach my $defref (@defn) {

      # Create a new hash for convenience
      my %display_info = %$defref;

      # Next if we dont have a key describing the display tool
      next unless exists $display_info{'TOOL'};

      # Make sure that the tool name is uppercased
      $display_info{'TOOL'} = uc($display_info{'TOOL'});

      # print the result
      if ($DEBUG) {
	foreach (keys %display_info) {
	  orac_print("$_ : $display_info{$_}\n",'cyan');
	}
      }

      # Now I suppose we need to decide whether the display tool is 
      # already open to us.
      # Query the tools hash

      my $current_tool;
      unless (exists $ {$self->toolref}{$display_info{TOOL}}) {
	orac_print("Creating new object for $display_info{TOOL}\n",'blue');

	my $obj = 'ORAC::Display::' . $display_info{TOOL};
	#    my $obj = 'ORAC::Display';

	# Check to see that we can create a new display object to
	# connect to the current tool (maybe that it is simply not
	# available)
	if (UNIVERSAL::can($obj, 'new')) {
	  
	  $current_tool = $obj->new;	

	  # If the returned value is undef then we had a problem creating
	  # the tool
	  unless (defined $current_tool) {
	    orac_err("Error launching $display_info{TOOL}.\n");
	    return;
	  } 

	} else {
	  orac_err("Cant create a $obj object. Maybe an interface to this display\ntool does not exist in ORACDR\n");
	  return;
	}


	$ {$self->toolref}{$display_info{TOOL}} = $current_tool;

      } else {
	orac_print("Tool $display_info{TOOL} already running\n",'cyan')
	  if $DEBUG;
	$current_tool = $ {$self->toolref}{$display_info{TOOL}};
      }

      # Now ask the tool to display the filename using the
      # display method specified in 'TYPE'
      # Lower case TYPE
      $display_info{TYPE} = lc($display_info{TYPE});

      orac_print("Current tool: $current_tool\n",'cyan') if $DEBUG;
      if ($current_tool->can($display_info{TYPE})) {
	# now we pass the buck
	my $method = $display_info{'TYPE'};

	# Find the name of the file to be displayed
	# Note that because the base class of Frame/Group can not
	# handle multiple file specifiers I can only pass in the
	# file number if $n is greater than one
	# Change this so that the file methods know to discard numbers
	# The base classes have been modified....
	my $fname;
#	if ($n == 1) {
#	  $fname = $frm->file;
#	} else {
	  $fname = $frm->file($n);
#	}

	# May want to pass in a merged hash at this point
	# ie a mixture of the display_info options as defined
	# in the device definition file and the options hash
	# supplied by the caller.
	$current_tool->$method($fname, \%display_info);

      } else {
	orac_err("Can't display type '$display_info{TYPE}' on $display_info{TOOL}");
      }

    }   

  }

}


=item definition(suffix)

Method to read a display definition, compare it with the idstring 
stored in the object (this is usually a file suffix)
and return back an array of  hashes containing all the relevant entries
from the definition. If an argument is given, the object updates
its definition of current idstring.

   @defn = $display->definition;


An empty array is returned if the suffix can not be matched.

=cut

sub definition {
  my $self = shift;
 
  if (@_) {
    my $id = shift;
    $self->idstring($id);
  }

  my @defn;

  # Now need to decide whether we are using NBS or a file
  if ($self->usenbs) {
    @defn = $self->parse_nbs_defn;
  } else {
    @defn = $self->parse_file_defn;
  }

  return @defn;
}


=item parse_nbs_defn

Using the current idstring, read the relevant information from
a noticeboard and return it in a hash. This routine takes no
arguments (idstring is read from the object) and should only
be used if the usenbs() flag is true.

  %defn = $self->parse_nbs_defn;

Currently not implemented.

=cut

sub parse_nbs_defn {
  my $self = shift;
  return ();

}


=item parse_file_defn

Using the current idstring, read the relevant information from
the text file (name stored in filename()) and return it in an array
of  hashes. There will be one hash per entry in the file that
matches the given suffix.
This routine takes no arguments (idstring is read from the object).

The input file is assumed to contain one line per ID of the following
format:

  ID  key=value key=value key=value..........\n

=cut

sub parse_file_defn {

  my $self = shift;

  # Initialise the defintion hash
  my @defn = ();
  my $id = $self->idstring;

  # Try to open file
  my $file = $self->filename;
  my $fh = new IO::File "< $file";

  if (defined $fh) {

    foreach my $line (<$fh>) {

      # Strip leading space
      $line =~ s/^\s+//;

      # Next if the line is empty
      next if length($line) == 0;

      # next if the line starts with a #
      next if $line =~ /^\#/;

      # Split on space
      my @junk = split(/\s+/,$line);

      # Compare first entry with id string
      # case insensitive
      my $test = lc($junk[0]);

      # There is a special case for numbers.
      # Numbers usually indicate RAW data
      # so the test is also true if $test= 'NUM' and $id is a \d+
      # RAW is an allowed synonym
      my $RAW = 0;
      if ($test eq 'num' || $test eq 'raw') {
	# Now if id is a number then the test is true
	if ($id =~ /^\d+$/) {
	  $test = $id;  # fool the following test
	}
	$RAW = 1;
      }

      # Do test
      if ($test eq $id) {

	# If NUM was selected then we want a slighlt differen
        # informational message
	if ($RAW == 1) {
	  orac_print("Display device determined (NUM:$test)\n",'blue');
	} else {
	  orac_print("Display device determined ($test)\n",'blue');	  
	}

	orac_print("ID:$id LINE:$line\n",'cyan') if $DEBUG;

	# Create a new hash
	my %defn = ();

	# Go through each entry in the line, split on = and
	# set in hash
	shift(@junk);  # Remove first entry;
	foreach my $keyval (@junk) {
	  my ($key, $val) = split(/=/,$keyval);
	  $key  = uc($key);
	  $defn{$key} = $val;
	}

	# Store the hash
	push(@defn, \%defn);

      }
    }


  }  else {
    orac_err("Error opening device definition:$!");
  }
  return @defn;
  
}



=back
 
=head1 SEE ALSO

Related ORAC display devices (eg L<ORAC::Display::P4>)

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=cut


1;




