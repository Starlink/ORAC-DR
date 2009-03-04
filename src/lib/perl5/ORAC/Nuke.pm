package ORAC::Nuke;

=head1 NAME

ORAC::Nuke - routines to kill all pipeline related processes and shared memory

=head1 SYNOPSIS

  use ORAC::Nuke

  orac_proc_kill($pattern, $exclude);

  orac_ipcs_kill();

=head1 DESCRIPTION

This module contains the routines called from oracdr_nuke that handle the culling of all pipeline related processes, and cleaning of shared memory.

=head1 NOTES

=over 4

=item *

All shared memory owned by the current user is removed even if
it is not directly associated with an ORAC-DR process.

=item * 

Will not attempt to remove shared memory owned by another user.

=item *

Will attempt to kill processes owned by other users even though
this will not succeed unless the user has special privilege.

=item *

Does not attempt to clear out ADAM_USER directories. This is not
normally a problem for ORAC-DR since each ORAC-DR process works
in a different ADAM_USER directory.

=back

=cut

use strict;
use warnings;

# ORAC modules

# General modules
use Sys::Hostname;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_proc_kill orac_ipcs_kill/;

$VERSION = '1.0';

=head1 SUBROUTINES

The following subroutines are available:

=over 4

=item B<orac_proc_kill>

Subroutine to kill all processes that match the supplied pattern,
exluding those processing that match the exclude pattern.

   orac_proc_kill( $pattern, $exclude );

The exlusion pattern is optional and is only required when certain 
processes that match the more general pattern should be excluded. 

The PID of the nuke process will never be killed regardless of 
whether this process matches the required pattern!!!

Relies on knowing the format and location of the standard ps for 
all supported OSs. This is a pain -- Should be using 
Proc::ProcessTable instead

=cut

sub orac_proc_kill {

  my $pat = shift;

  my $exclude = '____NOTHING_TO_EXCLUDE___';
  if (@_) { $exclude = shift; }

  # The command to use for ps
  my $cmd; 
  # this is the position of the pid in the ps output
  my $pos;
  if ($^O eq 'linux') {
    $cmd = '/bin/ps axw';
    $pos = 0;
  } elsif ($^O eq 'solaris') {
    $cmd = '/usr/bin/ps -ef';
    $pos = 1;
  } elsif ($^O eq 'darwin') {
    $cmd = '/bin/ps -ax';
    $pos = 0;
  } else {
    # Digital Unix PS
    $cmd = '/bin/ps -ef';
    $pos = 1;
  }

  my @processes = `$cmd`;

  foreach my $line (@processes) {

    # Check to see if any part of the line matches the supplied pattern
    # Check the whole string -- only clash would be user id
    if ($line =~ /$pat/) {

      # Check the exclusion pattern
      if ($line !~ /$exclude/) {

	# Split on space to extract the pid
	$line =~ s/^\s+//;  # Strip leading blanks
	my @a = split(/\s+/, $line);
	
	my $pid = $a[$pos];

	# Check two things, first that the pid is a number
	# and secondly that the pid does not match $$ (the pid
	# of this nuke command)

	if ($pid =~ /^\d+$/) {

	  # Now kill the relevant PID
	  kill 'KILL', $pid
	    unless $pid == $$;

	} else {
	  die "Error, PID ($pid) does not seem to be a number\n";
	}

      }

    }

  }

}

=item B<orac_ipcs_kill>

This routine kills the shared memory segments owner by the user.

   orac_ipsc_kill();

it has no arguements and returns nothing.

This routine does nothing on Darwin systems.

=cut

sub orac_ipcs_kill {

  # Set up ipcrm command
  my $ipcrm;
  if ($^O eq 'linux') {
    $ipcrm = "ipcrm shm";
  } elsif ($^O eq 'solaris') {
    $ipcrm = "ipcrm -m";
  } else {
    # Assume ipcrm -m -- this is valid for an Alpha
    # but I don't know the value for $^O in a modern alpha installation
    $ipcrm = "ipcrm -m";
  }

  # Read all shared memory segment IDs
  my @ipcs = `ipcs -m`;

  # Return if ipcs failed -- probably because it doesn't exist on the
  # system (like for Darwin)
  return if $?;

  foreach my $line (@ipcs) {

    # Check to see if the line matches the current user name

    # Split on space
    my @a = split(/\s+/, $line);

    # The position of the USER name is different on solaris
    # and linux but we can ignore this if we are only trying to match

    if ($line =~ $ENV{'USER'}) {
      # Note that SHMID is in position 1 on both linux and solaris
      # and alpha
      system "$ipcrm $a[1]";
    }

  }

}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
