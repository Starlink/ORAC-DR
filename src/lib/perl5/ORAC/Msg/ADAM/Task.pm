package  ORAC::Msg::ADAM::Task;

=head1 NAME

ORAC::Msg::ADAM::Task - load and control ADAM tasks

=head1 SYNOPSIS

  use ORAC::Msg::ADAM::Task;

  $kap = new ORAC::Msg::ADAM::Task("kappa","/star/bin/kappa/kappa_mon");

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


use vars qw/$VERSION $DTASK__ACTCOMPLETE $SAI__OK/;

# Access the AMS task code
use Starlink::AMS::Task '1.00';
 
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# Local definition of DTASK__ACT_COMPLETE. Probably should
# try to get it from Starlink::ADAM but currently broken

$DTASK__ACTCOMPLETE = 142115659;

$SAI__OK = &Starlink::ADAM::SAI__OK;


# Cannot subclass methods since I need to change most of them
# anyway.


=item B<new>

Create a new instance of a ORAC::Msg::ADAM::Task object.

  $obj = new ORAC::Msg::ADAM::Task;
  $obj = new ORAC::Msg::ADAM::Task("name_in_message_system","monolith");
  $obj = new ORAC::Msg::ADAM::Task("name_in_message_system","monolith"
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
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return $status;
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
  if ($status == $DTASK__ACTCOMPLETE) {
    $status = ORAC__OK;
  }
  return $status;

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
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return ($status, @values);
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
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return $status;
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
    # Probably should put in a subroutine
    if ($status == $SAI__OK) {
      $status = ORAC__OK;
    }
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
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return $status;

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
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }
  return $status;

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

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou (frossie@jach.hawaii.edu)    

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

# private methods


1;
