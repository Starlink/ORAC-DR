package ORAC::Loop;

=head1 NAME

ORAC::Loop - data loops for ORACDR

=head1 SYNOPSIS

  use ORAC::Loop;
 
  $frm = orac_loop_list($class, $utdate, \@list, $skip);

  $frm = orac_loop_inf($class, $utdate, \@list);

  $frm = orac_loop_wait($class, $utdate, \@list, $skip);

  $frm = orac_loop_flag($class, $utdate, \@list, $skip);

=head1 DESCRIPTION

This module provides a set of loop handling routines for ORACDR.
Each subroutine accepts the same arguments and returns the current
observation number (or undef if there was an error or if the loop
should be terminated).

A new  Frame object is returned of class $class that has been configured
for the new file (ie a C<$Frm-E<gt>configure> method has been run)

It is intended that this routine is called inside an infinite while
loop with the same @list array. This array is modified by the loop
routines so that they can keep track of the 'next' frame number.

If a filename can not be found (eg it doesnt exist or the list has
been processed) undef is returned.

The skip flag is used to indicate whether the loop should skip
forward if the current observation number can not be found
but a higher numbered observation is present. Currently no loops
will go back to missing observations if they appear after a higher
number (eg observation 10 appears before observation 9!)

=cut

use strict;
use Carp;

use ORAC::Print;
use ORAC::Convert;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA $CONVERT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

@ISA = qw/Exporter/;
@EXPORT = qw/orac_loop_list  orac_loop_wait orac_loop_inf
  orac_loop_flag
  orac_check_data_dir
  /;

=head1 LOOP SUBROUTINES

The following loop facilities are available:

=over 4


=item B<orac_loop_list>

Takes a list of numbers and returns back a frame object 
for each number (one frame object per call)

  $Frm = orac_loop_list($class, $UT, \@array, $noskip);

undef is returned on error or when all members of the
list have been returned. If the 'skip' flag is true
missing files in the list will be ignored and the next
element of the list selected. If 'skip' is false
the loop will abort if the file is not present 

=cut

sub orac_loop_list {

  croak 'Wrong number of args: orac_loop_list(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4; 

  my ($class, $utdate, $obsref, $skip) = @_;

  # Initialise variables
  my $obsno;
  my $TestFrm = $class->new() if $skip; # Dummy Frame for file check

  # Shift files off the array until we get one that exists
  # or until we get to the end of the array [ie an undefined value]
  # If we dont worry about missing observations we immediately
  # jump out of the loop (ie just read the array once).
  # If we do care about the existence of the file we have to check
  # for the input file (-e) and loop round again if it isn't there.

  while (defined ($obsno = shift(@$obsref))) {

    # If we dont care whether the file is there or not (ie default mode)
    # we jump out of the loop immediately and rely on the link_and_read
    # routine to abort the main loop for us (by returning undef)
    last unless $skip; 

    # Ok - we are interested in finding out whether the file is there
    # or not. There is a slight overhead here in that we have to
    # do the -e test twice for any successful file. Once here and
    # once again in link_and_read -- presumably I could have a variant
    # on link_and_read that gets passed the file name directly
    # on the understanding that the file is there but for now
    # I will just do the -e in both places. Note that this relies
    # on the file being present in ORAC_DATA_IN. It will not look
    # in ORAC_DATA_OUT first (eg after a FITS conversion)
    # At some point we need to merge the link_and_read with this
    # so that this routine has the same robustness as link_and_read.

    my $fname = $TestFrm->file_from_bits($utdate, $obsno);

    last if -e "$ENV{ORAC_DATA_IN}/$fname";
    orac_warn("Input file $fname not found -- skipping\n");

  }

  # If obsno is undef return undef
  return undef unless defined $obsno;

  my $Frm = link_and_read($class, $utdate, $obsno);

  # Return frame
  return $Frm;

}

=item B<orac_loop_inf>

Checks for the frame stored in the first element of the supplied array
and returns the Frame object if the file exists. The number is incremented
such that the next observation is returned next time the routine is
called.

  $Frm = orac_loop_inf($class, $ut, \@array);

undef is returned on error or when there are no more data files
available.

This loop does not have a facility for skipping files when observations
are not present. This behaviour is obtained by combining 
orac_check_data_dir with the list looping option so that the last
observation number can be determined before running the loop. The skip
flag is ignored in this loop.

=cut

sub orac_loop_inf {
  
  croak 'Wrong number of args: orac_loop_inf(class, ut, arr_ref)'
    unless (scalar(@_) == 3 || scalar(@_) == 4);

  my ($class, $utdate, $obsref) = @_;

  # If obsno is undef return undef
  return undef unless defined $$obsref[0];

  # Get the obsno
  my $obsno = $$obsref[0];

  my $Frm = link_and_read($class, $utdate, $obsno);

  # Now need to increment the obsnum for next time around
  $$obsref[0]++;

  # Return frame
  return $Frm;

}

=item B<orac_loop_wait>

Waits for the specified file to appear in the directory.
A timeout of 60 minutes is hard-wired in initially -- undef
is returned if the timeout is exceeded.

  $frm = orac_loop_wait($class, $utdate, \@list, $skip);

The first member of the array is used to keep track of the
current observation number. This element is incremented so that
the following observation is returned when the routine is called
subsequently. This means that this loop is similar to using the
'-from' option in conjunction with the 'inf' loop except that
new data is expected.

The loop will return undef (i.e. terminate looping) if the
supplied array contains undef in the first entry.

The skip flag is used to indicate whether the loop should skip
forward if the current observation number can not be found
but a higher numbered observation is present.

If no data can be found, the directory is scanned every few seconds
(hard-wired into the routine). A dot is printed to the screen after
a specified number of scans (default is 1 dot per scan and one scan every
2 seconds).

=cut

sub orac_loop_wait {

  croak 'Wrong number of args: orac_loop_wait(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4;

  my ($class, $utdate, $obsref, $skip) = @_;

  # If obsno is undef return undef
  return undef unless defined $obsref->[0];

  # Get the obsno
  my $obsno = $obsref->[0];

  # Create a new frame in class
  my $Frm = $class->new;
  
  # Construct the filename from the observation number
  # Note that this loop MUST work on the raw data.
  # I am not going to try to write a data detection loop
  # that tries to guess at the name of the input file from multiple
  # options.
  my $fname = $Frm->file_from_bits($utdate, $obsno);

  # Now check for the file
  orac_print("Checking for next data file: $fname");

  # Now loop until the file appears

  my $timeout = 7200;  # 60 minutes time out
  my $timer = 0.0;
  my $pause = 2.0;   # Time between checks
  my $dot   = 1;     # Number of pauses for each dot printed

  my $actual = $ENV{ORAC_DATA_IN} . "/$fname";

  my $old = 0;   # Initial size of the file
  my $npauses = 0; # number of pauses so far (reset each time dot printed)

  # was looping with
  #  while (! -e $actual) {
  # Cant do a loop detecting $actual explicitly since this
  # doesnt allow for the copying time..
  while (1) {

    # Check if the file is there
    if (-e $actual) {

      # Now need to check the file size
      # This is needed as a kluge so that we will not try to 
      # open a file that is in the process of being copied.
      # This assumes that the file length will not stay constant
      # over the length of our sleep.
 
      my $length = (stat $actual)[7];

      last if ($length == $old && $length > 0);
      # store the previous value
      $old = $length;

    } elsif ($skip) {

      # Okay the file was not there -- if SKIP is true we should re-read
      # the directory to check whether the next file has appeared
      # In order to prevent the problem of observations n and n+1 appearing
      # in the time it takes us to read the directory we should make sure
      # that we are looking for observation n (which has not turned up
      # yet) rather than n+1. We do this by running orac_check_data_dir
      # with an observation number one less than we are interested in

      # Run in a scalar context since we are only interested in the next
      # observation. The flag argument is set to 0.
      my $next = orac_check_data_dir($class, $obsno - 1, 0);

      # Check to see if something was found
      if (defined $next) {

	# This indicates that an observation iss available
	# Now need to modify the name of the file that the loop is 
	# searching for ($actual) [this is done many times in the loop and 
	# twice in this routine!]. Do not need to reset the timer since
	# we already know that we have a file. 

	if ($next != $obsno) {
	  
	  orac_print ("\nFile $fname appears to be missing\n");

	  # Okay - it wasnt the expected observation number
	  $obsno = $next;
	  $obsref->[0] = $obsno;  # And set the array value

	  # Create new filename
	  $actual = $ENV{ORAC_DATA_IN}."/".
	    $Frm->file_from_bits($utdate, $next);

	  orac_print("Next available observation is number $obsno");

	  # Loop round
	  next;

	}
      
      }


    }

    # Sleep for a bit
    $timer += orac_sleep($pause);
    $npauses++;

    # Return bad status if timer hits timeout
    if ($timer > $timeout) {
      orac_print "\n";
      orac_err("Timeout whilst waiting for next data file: $fname\n");
      return undef;
    }

    # Show that we are thinking
    # Print a dot every time $npauses equals the number specified in $dot
    # This is so that the checking cycle can be different from the dot
    # drawing cycle
    if ($npauses >= $dot) {
      orac_print ".";
      $npauses = 0;
    }


  }
  orac_print "\nFound\n";

  # The file has appeared
  # Link_and_read
  # A new $Frm is created and the file is converted to our base format (NDF).
  $Frm = link_and_read($class, $utdate, $obsno);

  # Now need to increment obsnum for next time round
  $$obsref[0]++;

  return $Frm;
}



=item B<orac_loop_flag>

Waits for the specified file to appear in the directory
by looking for the appearance of the associated flag file.
A timeout of 60 minutes is hard-wired in initially -- undef
is returned if the timeout is exceeded.

  $frm = orac_loop_flag($class, $utdate, \@list, $skip);

The first member of the array is used to keep track of the
current observation number. This element is incremented so that
the following observation is returned when the routine is called
subsequently. This means that this loop is similar to using the
'-from' option in conjunction with the 'inf' loop except that
new data is expected.


The loop will return undef (i.e. terminate looping) if the
supplied array contains undef in the first entry.

=cut

sub orac_loop_flag {

  croak 'Wrong number of args: orac_loop_flag(class, ut, arr_ref, skip)'
    unless scalar(@_) == 4;

  my ($class, $utdate, $obsref, $skip) = @_;

  # If obsno is undef return undef
  return undef unless defined $obsref->[0];

  # Get the obsno
  my $obsno = $obsref->[0];

  # Create a new frame in class
  my $Frm = $class->new;
  
  # Construct the flag name from the observation number
  my $fname = $Frm->flag_from_bits($utdate, $obsno);

  # Now check for the file
  orac_print("Checking for next data file via flag: $fname");

  # Now loop until the file appears

  my $timeout = 7200;  # 120 minutes time out
  my $timer = 0.0;
  my $pause = 2.0;   # Pause for 2 seconds

  my $actual = $ENV{ORAC_DATA_IN} . "/$fname";

  my $old = 0;   # Initial size of the file

  # Dont need to worry about file size
  while (! -e $actual) {

    if ($skip) {

      # Okay the file was not there -- if SKIP is true we should re-read
      # the directory to check whether the next file has appeared
      # In order to prevent the problem of observations n and n+1 appearing
      # in the time it takes us to read the directory we should make sure
      # that we are looking for observation n (which has not turned up
      # yet) rather than n+1. We do this by running orac_check_data_dir
      # with an observation number one less than we are interested in

      # Run in a scalar context since we are only interested in the next
      # observation. The flag argument is set to true.
      my $next = orac_check_data_dir($class, $obsno - 1, 1);

      # Check to see if something was found
      if (defined $next) {

	# This indicates that an observation iss available
	# Now need to modify the name of the file that the loop is 
	# searching for ($actual) [this is done many times in the loop and 
	# twice in this routine!]. Do not need to reset the timer since
	# we already know that we have a file. 

	if ($next != $obsno) {
	  
	  orac_print ("\nFile $fname appears to be missing\n");

	  # Okay - it wasnt the expected observation number
	  $obsno = $next;
	  $obsref->[0] = $obsno;  # And set the array value

	  # Create new filename
	  $actual = $ENV{ORAC_DATA_IN}."/".
	    $Frm->flag_from_bits($utdate, $next);

	  orac_print("Next available observation is number $obsno");

	  # Finish loop since we have found a file
	  last;

	}
	
      }
    }

    # Sleep for a bit
    $timer += orac_sleep($pause);

    # Return bad status if timer hits timeout
    if ($timer > $timeout) {
      orac_print "\n";
      orac_err("Timeout whilst waiting for next data file: $fname\n");
      return undef;
    }

    # Show that we are thinking
    orac_print ".";

  }
  orac_print "\nFound\n";

  # The flag has appeared therefore we believe the file is there as well.
  # Link_and_read
  # A new $Frm is created and the file is converted to our base format (NDF).
  $Frm = link_and_read($class, $utdate, $obsno);

  # Now need to increment obsnum for next time round
  $$obsref[0]++;
  
  return $Frm;
  
}

=back

=head1 OTHER EXPORTED SUBROUTINES

=over 4

=item B<orac_check_data_dir>

Routine to check the input data directory (ORAC_DATA_IN) for
files in order to see whether files exist with a higher number
than the supplied number. The routine is supplied with a class name,
UT date and current observation number. An additional argument
is provided to determine whether data files or flag files should
be used for the directory search.

   $next = orac_check_data_dir($class, $current, $flag);
   ($next, $high) = orac_check_data_dir($class, $current, $flag);

If called in a scalar context, the return argument is the next 
observation in the sequence. If called in an array context, two
arguments are returned: the next observation number and the highest 
observation number.

undef (or undef,undef) is returned if no higher observations can be
found. If it is necessary to check for the existence of current
file as well (eg via a data detection loop) then simply decrement the
supplied argument by 1.

This routine is used in conjunction with the -from loop (where we
dont know the end) and the waiting loops where we are not sure whether
new data have been written to disk but missing the next observation.

This routine does NOT look in ORAC_DATA_OUT.

A global variables (@LIST) is used to speed up the sorting by storing
a list of observation numbers that have previously been shown to have a lower
number than required (NOT YET IMPLEMENTED).

=cut

sub orac_check_data_dir {

  local (*DATADIR);

  croak 'Usage check_data_dir(ClassName, CurrentObs, Flag)'
    unless scalar(@_) == 3;

  my ($class, $obsnum, $flag) = @_;

  # Create a new dummy Frame
  my $DummyFrm = $class->new();

  # Now retrieve the pattern
  # The most general implementation (and most robust) would
  # be to query the frame object for a pattern that can be used
  # to match files.
  # For now, we will make a guest at the pattern. This could
  # throw us off the scent in some special cases [eg the directory
  # contains more than one night of data, DR files which match
  # the generic pattern....]
  # If FLAG is true then we simply search for the dot files with 
  # a .ok at the end 

  my $pattern;

  if ($flag) {

    $pattern = '^\..*\.ok$';   # ' - dummy quote for emacs colour
  } else {

    # We are matching data files. Try to match a string that
    # contains the fixed part and ends with the suffix.
    # (something like UFTI with a single character fixed part
    # may be tricky). Cant match the UT date since I dont know
    # where the UT fits into the filename convention

    $pattern = $DummyFrm->rawfixedpart . '.*' . 
      $DummyFrm->rawsuffix . '$';  # ' dummy quote again

  }
  
  # Now open the directory
  opendir(DATADIR, "$ENV{ORAC_DATA_IN}") 
    or die "Error opening ORAC_DATA_IN: $!";

  # Read the directory, extract the number and sort the list
  # Note that I dont even keep the filenames, just the numbers.
  # Do this with a sort/map/grep combination

  my @sort = sort { $a <=> $b }
               map { $DummyFrm->raw($_); $DummyFrm->number }
                 grep { /$pattern/ } readdir(DATADIR);


  # Close data directory
  closedir DATADIR;

  # Now need to compare with the supplied observation number
  # Go through the sorted list until we find a number that is 
  # greater than the current observation. Cant simply take the
  # slice since the index in the sort array is not related to the
  # observation number

  my $next = undef;   # Next number up
  foreach (@sort) {
    if ($_ > $obsnum) {
      $next = $_;
      last;
    }
  }

  # If $next is defined, that means we have found the next observation
  # in the list. 

  # If we are in a scalar context we also need the highest number found
  # The highest value is the last member unless $next
  # is undef (meaning we got to the end of the list without finding
  # a higher value)

  if (wantarray) {
    my $highest = undef;
    $highest = $sort[-1] if defined $next;
    return ($next, $highest);

  } else {
    # We are in a scalar context - just return the next value
    return $next;
    
  }

}

=back


=head1 PRIVATE SUBROUTINES

The following subroutines are not exported.

=over 4

=item B<link_and_read>

General subroutine for converting ut and number into file
and creating a Frame object.

  $frm = link_and_read($class, $ut, $obsnum)l

undef is returned on error.
A configured Frame object is returned if everything is okay

=cut

sub link_and_read {

  croak 'Wrong number of args: link_and_read(class, ut, num)'
    unless scalar(@_) == 3; 

  my ($class, $ut, $num) = @_;

  # Create a new frame in class
  my $Frm = $class->new;
  
  # Construct the filename from the observation number
  my $fname = $Frm->file_from_bits($ut, $num);

  # Now we have to decide whether we have a FITS file or not
  # Just ask it for the NDF file name
  # If the converted file already exists  then do nothing.
  # If the input format matches the output format just return the
  # name.
  # Have to remember to do this everywhere we need $CONVERT since
  # we are not using a global constructor.
  unless (defined $CONVERT) { $CONVERT = new ORAC::Convert; }

  # Read the Input and Output formats from the Frame object
  my $infmt = $Frm->rawformat;
  my $outfmt = $Frm->format;

  # Ask for the filename (converted if required)
  $fname = $CONVERT->convert($ENV{ORAC_DATA_IN} ."/$fname", { IN => $infmt, 
							      OUT => $outfmt, 
							      OVERWRITE => 0
							    });

  # Check state of $fname
  unless (defined $fname) {
    orac_err("Error in data conversion tool\n");
    return undef;
  }

  # Try to do this in a more structured way so that we can tell
  # Why something fails

  # If the file exists in the current directory then we dont care
  # what happens (eg it has been converted or a link of the correct
  # name exists with a file at the other end

  # We have to make sure the file is here else the Frame configuration
  # will not work correctly.

  unless (-e $fname) {

    # Now check in the ORAC_DATA_IN directory to make sure it is there
    unless (-e $ENV{ORAC_DATA_IN} ."/$fname") {
      orac_err("Requested file ($fname) can not be found in ORAC_DATA_IN\n");
      return undef;
    }

    # Now if there is a link already in ORAC_DATA_OUT we need to
    # read it to find out where it is pointing (we will only get
    # to this point if the link does not point to anything at the
    # other end since -e follows links
    if (-l $fname) {
      my $nowhere = readlink($fname);
      unless (defined $nowhere) {
	orac_err("Error reading through link from ORAC_DATA_OUT/$fname:\n");
	orac_err("$!\n");
      } else {
	orac_err("File $fname does exist in ORAC_DATA_OUT but is a link\n");
	orac_err("pointing to nowhere. It points to: $nowhere\n");	
      }
     return undef;
    }
    
    # Now we should try to create a symlink and say something
    # if it fails
    symlink($ENV{ORAC_DATA_IN} . "/$fname", $fname) ||
      do {
	orac_err("Error creating symlink from ORAC_DATA_OUT to $ENV{ORAC_DATA_IN}/$fname\n");
	orac_err("$!\n");
	return undef;
      };

    # Note that -e checks through symlinks
    # This final check SHOULD work else something really wacky is 
    # going on
    unless (-e $fname) {
      orac_err("File ($fname) can not be found through link from\n");
      orac_err("ORAC_DATA_OUT to ORAC_DATA_IN\n");
      return undef;
    }

  }

  # Now configure the frame object
  # This will fail if the file can not be opened in the current directory.
  
  $Frm->configure($fname);

  # Return success
  return $Frm;

}

=item B<orac_sleep>

Pause the checking for new data files by the specified number of seconds.

  $time = orac_sleep($pause);

Where $pause is the number of seconds to wait and $time is the number
of seconds actually waited (see the sleep() command for more details).

If the Tk system is loaded this routine will actually do a Tk event loop
for the required number of seconds. This is so that the X screen will
be refreshed. Currently the only test is the Tk is loaded, not that
we are actually using Tk.....

=cut

sub orac_sleep {

  my $pause = shift;
  my $actual;

  if (defined &Tk::DoOneEvent) {
    # Tk friendly....
    my $now = time();
    while (time() - $now < $pause) {
      # Process events (Dont wait if there were none)
      &Tk::DoOneEvent(&Tk::DONT_WAIT);

      # Pause for a fraction of a second to stop us going into
      # a CPU intensive loop for no reason Not the best solution since
      # it does make the Tk events a bit unresponsive
      select undef,undef,undef,0.2;

    }
    # Calculate actual elapsed time
    $actual = time() - $now;

  } else {
    # Do a standard sleep
    $actual = sleep($pause);

  }

  return $actual;

}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and 
Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
