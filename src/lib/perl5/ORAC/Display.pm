package ORAC::Display;

=head1 NAME

ORAC::Display - Top level interface to ORAC display tools

=head1 SYNOPSIS

  use ORAC::Display;

  $Display = new ORAC::Display;
  $Display->usenbs(1);
  $Display->filename(filename);
  $Display->display_data('frame/group object');
  $Display->display_data('frame/group object',{WINDOW=>1});

=head1 DESCRIPTION

This module provides an OO-interface to the ORAC display manager.  The
display object reads device information from a file or notice board
(shared memory) [NBS not implemented], determines whether the supplied
frame object matches the criterion for display, if it does it
instructs the relevant device object to send to the selected window
(creating a new device object if necessary)

=cut


use 5.006;
use Carp;
use strict;
use warnings;

use IO::File;
use ORAC::Print;

# These classes are available. They are loaded on demand
#use ORAC::Display::P4;
#use ORAC::Display::KAPVIEW;
#use ORAC::Display::GAIA;

use vars qw/$VERSION $DEBUG/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$DEBUG = 0;

=head1 PUBLIC METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance of B<ORAC::Display>. No arguments are
required.

  $Display = new ORAC::Display;

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

=back

=head1 Accessor Methods

=over 4

=item B<display_tools>

Returns (or sets) a hash containing the current lookup of display tool
to display tool object. For example:

   $Display->display_tools(%tools);
   %tools = $Display->display_tools;

where %tools could look like:

     'GAIA' => Display::GAIA=HASH(object),
     'P4'   => Display::P4=HASH(object)

etc. The current contents are overwritten when a new hash is supplied.

When called from an array context, returns the full hash contents.
When called from a scalar context, returns the reference to the hash.

=cut

sub display_tools {
  my $self = shift;
  if (@_) {
    %{ $self->{Tools} } = @_;
  }
  if (wantarray()) {
    return %{$self->{Tools}};
  } else {
    return $self->{Tools};
  }
}

=item B<filename>

Set (or retrieve) the name of the file containing the display device
definition. Only used when usenbs() is false.

  $file = $Display->file;
  $Display->file("new_file");

=cut

sub filename {
  my $self = shift;
  if (@_) { $self->{FileName} = shift; }
  return $self->{FileName};
}


=item B<idstring>

Set (or retrieve) the value of the string used for comparison
with the display device definition information (created by the
separate device allocation GUI).

  $Display->idstring($id);
  $id = $Display->idstring;

=cut

sub idstring {
  my $self = shift;
  if (@_) { $self->{ID} = shift; }
  return $self->{ID};
}

=item B<usenbs>

Determine whether NBS (shared memory) should be used to read the
display device definition. Default is false.

  $usenbs = $Display->usenbs;
  $Display->usenbs(0);

=cut

sub usenbs {
  my $self = shift;
  if (@_) { $self->{UseNBS} = shift; }
  return $self->{UseNBS};
}


=back

=head2 General Methods

=over 4

=item B<definition>

Method to read a display definition, compare it with the idstring 
stored in the object (this is usually a file suffix)
and return back an array of  hashes containing all the relevant entries
from the definition. If an argument is given, the object updates
its definition of current idstring (and then searches).

   @defn = $display->definition;
   @defn = $display->definition($id);

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



=item B<display_data>

This is the main method to be used for displaying data.  The supplied
object must contain a method for determining the filename and the
display ID (so that it can be compared with the information stored in
the device definition file). It should support the file(), nfiles()
and gui_id() methods.

The optional hash can be used to supply extra entries in the
display definition file (or in fact do away with the definition file
completely). Note that the contents of the options hash will be used
even if no display definition can be found to match the current 
gui_id.

  $Display->display_data($Frm) if defined $Display;
  $Display->display_data($Frm, { TOOL => 'GAIA'});
  $Display->display_data($Frm, { TOOL => 'GAIA'}, $usedisp);

A third optional argument can be used in conjunction with the
options hash to indicate whether these options should be used
instead of the display definition file (false) or in addition
to (true - the default) 

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
  my $optref;
  my $usedisp = 1;
  if (@_) {
    $optref = shift;
    croak 'Options were not supplied as a hash reference'
      unless ref($optref) eq 'HASH';
    $usedisp = shift if @_;
  }


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
  for my $n (1..$nfiles) {

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

    orac_print("Checking display definition for entry matching $frm_suffix\n",'blue') if $DEBUG;

    # Now we need to search through the display definition and
    # decide whether our suffix can be displayed anywhere.
    # Expect to have an array of hashes where each hash corresponds
    # to a matching line
    # This allows a single file to be displayed on multiple
    # devices
  
    # Do not read the disp.dat if we are only using the supplied 
    # values
    my @defn;
    @defn = $self->definition if $usedisp;

    # push additional entries onto the definition array
    push (@defn,$optref) if (defined $optref);

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
      unless (exists $self->display_tools->{$display_info{TOOL}}) {
	orac_print("Creating new object for $display_info{TOOL}\n",'blue');

	# Dynamically load the required display class
	# Very useful when some sites do not have access
	# to all display systems

	# Class name
	my $class = 'ORAC::Display::' . $display_info{TOOL};
	eval "use $class";

	if ($@) {
	  orac_err "Error loading class $class. Can not even attempt to start this display\n$@";
	  return;
	}

	# Check to see that we can create a new display object to
	# connect to the current tool (maybe that it is simply not
	# available)
	if (UNIVERSAL::can($class, 'new')) {

	  $current_tool = $class->new;	

	  # If the returned value is undef then we had a problem creating
	  # the tool
	  unless (defined $current_tool) {
	    orac_err("Error launching $display_info{TOOL}.\n");
	    return;
	  }

	} else {
	  orac_err("Cant create a $class object. Maybe an interface to this display\ntool does not exist in ORACDR\n");
	  return;
	}


	$self->display_tools->{$display_info{TOOL}} = $current_tool;

      } else {
	orac_print("Tool $display_info{TOOL} already running\n",'cyan')
	  if $DEBUG;
	$current_tool = $self->display_tools->{$display_info{TOOL}};
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
        $fname = $frm->file($n);

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



=item B<parse_nbs_defn>

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


=item B<parse_file_defn>

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
  my $id = lc($self->idstring);

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

	# If NUM was selected then we want a slightly different
        # informational message
	if ($DEBUG) {
	  if ($RAW == 1) {
	    orac_print("Display device determined (NUM:$test)\n",'blue');
	  } else {
	    orac_print("Display device determined ($test)\n",'blue');
	  }
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

Related ORAC display devices (eg L<ORAC::Display::KAPVIEW>)

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;




