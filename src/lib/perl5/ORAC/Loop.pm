package ORAC::Loop;

=head1 NAME

ORAC::Loop - data loops for ORACDR

=head1 SYNOPSIS

  use ORAC::Loop;
 
  $frm = orac_loop_list($class, $utdate, \@list);

  $frm = orac_loop_inf($class, $utdate, \@list);

  $frm = orac_loop_wait($class, $utdate, \@list);

  $frm = orac_loop_flag($class, $utdate, \@list);

=head1 DESCRIPTION

This module provides a set of loop handling routines for ORACDR.
Each subroutine accepts the same arguments and returns the current
observation number (or undef if there was an error or if the loop
should be terminated).

A new  Frame object is returned of class $class that has been configured
for the new file (ie a $Frm->configure method has been run)

It is intended that this routine is called inside an infinite while
loop with the same @list array. This array is modified by the loop
routines so that they can keep track of the 'next' frame number.

If a filename can not be found (eg it doesnt exist) undef is 
returned.

=cut

use strict;
use Carp;

use ORAC::Print;
use ORAC::Convert;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA $CONVERT/;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_loop_list  orac_loop_wait orac_loop_inf
  orac_loop_flag
  /;


=head1 SUBROUTINES

The following loop facilities are available:

=over 4


=item orac_loop_list

Takes a list of numbers and returns back a frame object 
for each number (one frame object per call)

undef is returned on error or when all members of the
list have been returned.

=cut

sub orac_loop_list {
  
  croak 'Wrong number of args: orac_loop_list(class, ut, arr_ref)'
    unless scalar(@_) == 3; 

  my ($class, $utdate, $obsref) = @_;

  # Get the obsno
  my $obsno = shift(@$obsref);

  # If obsno is undef return undef
  return undef unless defined $obsno;

  my $Frm = link_and_read($class, $utdate, $obsno);

  # Return frame
  return $Frm;

}

=item orac_loop_inf

Checks for the frame stored in the first element of the supplied array
and returns the Frame object if the file exists. The number is incremented
such that the next observation is returned next time the routine is
called.

undef is returned on error or when there are no more data files
available.

=cut

sub orac_loop_inf {
  
  croak 'Wrong number of args: orac_inf(class, ut, arr_ref)'
    unless scalar(@_) == 3; 

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

=item orac_loop_wait

Waits for the specified file to appear in the directory.
A timeout of 10 minutes is hard-wired in initially -- undef
is returned if the timeout is exceeded.

The first member of the array is used to keep track of the
current observation number. This element is incremented so that
the following observation is returned when the routine is called
subsequently. This means that this loop is similar to using the
'-from' option in conjunction with the 'inf' loop except that
new data is expected.

The loop will return undef (i.e. terminate looping) if the
supplied array contains undef in the first entry.

=cut

sub orac_loop_wait {

  croak 'Wrong number of args: orac_loop_wait(class, ut, arr_ref)'
    unless scalar(@_) == 3; 

  my ($class, $utdate, $obsref) = @_;

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

  my $timeout = 3600;  # 60 minutes time out
  my $timer = 0.0;
  my $pause = 2.0;   # Pause for 2 seconds

  my $actual = $ENV{ORAC_DATA_IN} . "/$fname";

  my $old = 0;   # Initial size of the file

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

    }

    # Sleep for a bit
    $timer += sleep($pause);

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

  # The file has appeared
  # Link_and_read
  # A new $Frm is created and the file is converted to our base format (NDF).
  $Frm = link_and_read($class, $utdate, $obsno);

  # Now need to increment obsnum for next time round
  $$obsref[0]++;

  return $Frm;
}



=item orac_loop_flag

Waits for the specified file to appear in the directory
by looking for the appearance of the associated flag file.
A timeout of 60 minutes is hard-wired in initially -- undef
is returned if the timeout is exceeded.

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

  croak 'Wrong number of args: orac_loop_flag(class, ut, arr_ref)'
    unless scalar(@_) == 3;

  my ($class, $utdate, $obsref) = @_;

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

  my $timeout = 3600;  # 10 minutes time out
  my $timer = 0.0;
  my $pause = 2.0;   # Pause for 2 seconds

  my $actual = $ENV{ORAC_DATA_IN} . "/$fname";

  my $old = 0;   # Initial size of the file

  # Dont need to worry about file size
  while (! -e $actual) {

    # Sleep for a bit
    $timer += sleep($pause);

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



# General subroutine for converting ut and number into file
# and creating a Frame object
# undef is returned on error
# a configured Frame object is returned if everything is okay

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
  $fname = $CONVERT->convert($ENV{ORAC_DATA_IN} ."/$fname", { OUT => 'NDF', OVERWRITE => 0});


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


=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and 
Tim Jenness (t.jenness@jach.hawaii.edu)

=cut

1;
