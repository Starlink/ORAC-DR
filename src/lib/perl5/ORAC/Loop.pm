package ORAC::Loop;

=head1 NAME

ORAC::Loop - data loops for ORACDR

=head1 SYNOPSIS

  use ORAC::Loop;
 
  $frm = orac_list($class, $utdate, \@list);

  $frm = orac_inf($class, $utdate, \@list);

  $frm = orac_data($class, $utdate, \@list);

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

require Exporter;

use vars qw/$VERSION @EXPORT @ISA/;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_list /;


=head1 SUBROUTINES

The following loop facilities are available:

=over 4

=item orac_list

Takes a list of numbers and returns back a frame object 
for each number (one frame object per call)

undef is returned on error or when all members of the
list have been returned.

=cut

sub orac_list {
  
  croak 'Wrong number of args: orac_list(class, ut, arr_ref)'
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

=item orac_inf

Takes a list of numbers and returns back a frame object 
for each number (one frame object per call)

undef is returned on error or when all members of the
list have been returned.

=cut

sub orac_inf {
  
  croak 'Wrong number of args: orac_inf(class, ut, arr_ref)'
    unless scalar(@_) == 3; 

  my ($class, $utdate, $obsref) = @_;

  # Get the obsno
  $$obsref[0]++;
  my $obsno = $$obsref[0];

  # If obsno is undef return undef
  return undef unless defined $obsno;

  my $Frm = link_and_read($class, $utdate, $obsno);

  # Return frame
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

  # Create a symlink
  # Dont check whether it worked or not
  symlink($ENV{ORAC_DATA_IN} . "/$fname", $fname);

  # Now we need to see if the file exists in $ORAC_DATA_IN
  # in the current directory. Note that this also checks to see
  # whether the symlink worked.
  # have to do it this way around since the frame configuration
  # routine does not report back that there was a failure in reading
  # the header from the file

  # Note that the -e operator does look through the symlink to make
  # sure that a file exists at the other end.

  unless (-e "$fname") {
    # Oops the file is not available
    # Print a message and return undef
    print "Oops. Input file ($fname) could not be found in ORAC_DATA_IN\n";
    return undef;
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
