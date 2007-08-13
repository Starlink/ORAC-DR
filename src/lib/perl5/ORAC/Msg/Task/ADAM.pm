package  ORAC::Msg::Task::ADAM;

=head1 NAME

ORAC::Msg::Task::ADAM - load and control ADAM tasks

=head1 SYNOPSIS

  use ORAC::Msg::Task::ADAM;

  $kap = new ORAC::Msg::Task::ADAM("kappa","/star/bin/kappa/kappa_mon");

  $status           = $kap->obeyw("task", "params");
  $status           = $kap->set("task", "param","value");
  ($status, @values) = $kap->get("task", "param");
  ($dir, $status)   = $kap->control("default","dir");
  $kap->control("par_reset");
  $kap->resetpars;
  $kap->cwd("dir");
  $cwd = $kap->cwd;

=head1 DESCRIPTION

Provide methods for loading and communicating with ADAM monoliths.
This module conforms to the ORAC messaging standard. This is an
ORAC interface to the Starlink::AMS::Task module.

By default all tasks loaded by this module will be terminated
on exit from perl.

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=cut

use strict;
use Carp;

# Import ORAC constants
use ORAC::Constants qw/:status/;

# I need to import good Starlink status from the ADAM module
use Starlink::ADAM ();


use vars qw/$VERSION $DTASK__ACTCOMPLETE $SAI__OK $DEBUG/;

$DEBUG = 0;

# Access the AMS task code
use Starlink::AMS::Task '1.00';

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# Local copies of important Starlink constants.
$DTASK__ACTCOMPLETE = &Starlink::ADAM::DTASK__ACTCOMPLETE;
$SAI__OK = &Starlink::ADAM::SAI__OK;


# Cannot subclass methods since I need to change most of them
# anyway.


=item B<new>

Create a new instance of a ORAC::Msg::Task::ADAM object.

  $obj = new ORAC::Msg::Task::ADAM;
  $obj = new ORAC::Msg::Task::ADAM("name_in_message_system","monolith");
  $obj = new ORAC::Msg::Task::ADAM("name_in_message_system","monolith"
                                    { TASKTYPE => 'A'} );

If supplied with arguments (matching those expected by load() ) the
specified task will be loaded upon creating the object. If the load()
fails then undef is returned (which will not be an object reference).

=cut


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $task = {};  # Anon hash

  my $status; # Status from load
  $status  = ORAC__OK; # Default good status

  # Since we are really simply handling another object
  # Create the new object (Starlink::AMS::Task) and store it.
  $task->{Obj} = new Starlink::AMS::Task;  # Name in AMS

  # Bless task into class
  bless($task, $class);

  # If we have arguments then we are trying to do a load
  # as well
  if (@_) { $status = $task->load(@_); };

  if ($status != ORAC__OK) {
    carp "Error creating new object (Status=$status)";
  }

  return $task;
}


# Private method for handling the Starlink::AMS::Task object

sub obj {
  my $self = shift;
  if (@_) { $self->{Obj} = shift; }
  return $self->{Obj};
}

=back

=head2 General Methods

=over 4

=item B<load>

Load a monolith and set up the name in the messaging system.
This task is called by the 'new' method.

  $status = $obj->load("name","monolith_binary",{ TASKTYPE => 'A' });

If the second argument is omitted it is assumed that the binary
is already running and can be called by "name".

If a path to a binary with name "name" already exists then the monolith
is not loaded.

Options (in the form of a hash reference) can be supplied
in order to configure the monolith. Currently supported options
are

  TASKTYPE  - can be 'A' for A-tasks or 'I' for I-tasks

=cut

sub load {

  my $self = shift;
  # initialise
  my $status = $SAI__OK;

  if (@_) { $status = $self->obj->load(@_); }

  # Convert from ADAM to ORAC status
  # Probably should put in a subroutine
  return $self->_to_orac_status($status);
}


=item B<obeyw>

Send an obey to a task and wait for a completion message

  $status = $obj->obeyw("action","params");

=cut

sub obeyw {
  my $self = shift;

  my $status;

  # Pass arguments directly to the object
  if (@_) { $status = $self->obj->obeyw(@_); }

  # Should now change status from the obeyw (DTASK__ACTCOMPLETE)
  # to good ORAC status
  return $self->_to_orac_status($status,1);
}


=item B<get>

Obtain the value of a parameter

 ($status, @values) = $obj->get("task", "param");

=cut

sub get {
  # Check number of arguments
  if (scalar(@_) != 3) { 
    croak 'get: Wrong number of arguments. Usage: $task->get(\'task\', \'param\')';
  }

  my $self = shift;

  # Now need to construct the arguments for the AMS layer

  my $task = shift;
  my $param = shift;

  my ($status,@values) = $self->obj->get($task, $param);

  # Convert from ADAM to ORAC status
  return ($self->_to_orac_status($status),@values);
}

=item B<set>

Set the value of a parameter

  $status = $obj->set("task", "param", "newvalue");

=cut

sub set {
  # Check number of arguments
  if (scalar(@_) != 4) { 
    croak 'get: Wrong number of arguments. Usage: $task->set(\'task\', \'param\', \'newvalue\')';
  }

  my $self = shift;

  # Now need to construct the arguments for the AMS layer

  my $task = shift;
  my $param = shift;
  my $value = shift;

  my $status = $self->obj->set($task, $param, $value);

  # Convert from ADAM to ORAC status
  return $self->_to_orac_status($status);
}


=item B<control>

Send CONTROL messages to the monolith. The type of control
message is specified via the first argument. Allowed values are:

  default:  Return or set the current working directory
  par_reset: Reset all parameters associated with the monolith.

  ($current, $status) = )$obj->control("type", "value")

"value" is only relevant for the "default" type and is used
to specify a new working directory. $current is always returned
even if it is undefined.

These commands are synonymous with the cwd() and resetpars()
methods.

=cut

sub control {

  my ($value, $status);
  my $self = shift;

  if (@_) { 
    ($value, $status) = $self->obj->control(@_);

    # Convert from ADAM to ORAC status
    $status = $self->_to_orac_status($status);
  }
  return ($value, $status);
}

# Stop the monolith from being killed on exit

sub forget {
  my $self = shift;
  $self->obj->forget;
}

=item B<resetpars>

Reset all parameters associated with a monolith

  $status = $obj->resetpars;

=cut

sub resetpars {
  my $self = shift;

  my ($junk, $status) = $self->obj->control("par_reset");

  # Convert from ADAM to ORAC status
  return $self->_to_orac_status($status);
}


=item B<cwd>

Set and retrieve the current working directory of the monolith

  ($cwd, $status) = $obj->cwd("newdir");

=cut

sub cwd {
  my $self = shift;
  my $newdir = shift;

  my ($value, $status) = $self->obj->control("default", $newdir);

  # Convert from ADAM to ORAC status
  return ($value, $self->_to_orac_status($status));
}


=item B<contactw>

This method will not return unless the monolith can be contacted.
It only returns with a timeout. Returns a '1' if we contacted okay
and a '0' if we timed out. It will timeout if it takes longer than
specified in C<ORAC::Msg::ADAM::Control-E<gt>timeout>.

=cut


sub contactw {
  my $self = shift;
  return $self->obj->contactw;
}


=item B<contact>

This method can be used to determine whether the object can
contact a monolith. Returns a 1 if we can contact a monolith and
a zero if we cant.

=cut

sub contact {
  my $self = shift;
  return $self->obj->contact;
}


=item B<pid>

Returns process id of forked task.
Returns undef if there is no external task.

=cut

sub pid {

  my $self = shift;
  my $pid = $self->obj->pid;

  # If it is a scalar then simply return
  if (not ref($pid)) {
    return $pid;
  } else {
    return $pid->{'pid'};
  }

}


=back

=head1 REQUIREMENTS

This module requires the Starlink::AMS::Task module.

=head1 SEE ALSO

L<Starlink::AMS::Task>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
and Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

# private methods

# internal routine to translate returned status to ORAC status
# Two arguments:
#   - the Starlink status
#   - whether this was from an obey (optional)

# Currently, good status (SAI__OK) are translated to ORAC__OK
# Status due to engine death are translated to ORAC__BADENG
# All others remain unchanged since ORAC-DR will treat them
# as bad anyway and the actual status value is sometimes useful

# Need to insert these error codes into Starlink::ADAM

sub _to_orac_status {
  my $self = shift;
  my $status = shift;
  my $isobey = shift;

  print "ADAM Status: $status\n" if $DEBUG;

  # Check good status
  if ($status == $SAI__OK) {
    # standard okay
    print "ORAC_STATUS OK\n" if $DEBUG;
    return ORAC__OK;
  } elsif ($isobey && $status == $DTASK__ACTCOMPLETE) {
    # An obey completed successfully
    print "ORAC STATUS FROM OBEY OKAY\n" if $DEBUG;
    return ORAC__OK;
  } elsif ($status == 141460275 || # MESSYS__NOTFOUND
	   $status == 141460291 || # MESSYS__TIMEOUT
	   $status == 141460379 || # MESSYS__TOOLONG
	   $status == 199786514 || # MSP__BADQUEUE
	   $status == 199786546 || # MSP__NOTFOUND
	   $status == 199786562 || # MSP__RECLEN
	   $status == 199786570 || # MSP__SENDLEN
	   $status == 199786578 || # MSP__SOCKFAIL
	   $status == 199786586 || # MSP__SOCKINIT
	   $status == 159809544 ) {  # SOCK__READSOCK
    print "BAD ENGINE STATUS\n" if $DEBUG;
    return ORAC__BADENG;
  }
  print "Generic bad status\n" if $DEBUG;
  return $status;
}


1;
