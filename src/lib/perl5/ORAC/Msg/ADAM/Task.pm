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
use Starlink::AMS::Task;
 
$VERSION = undef;
$VERSION = '0.01';


# Local definition of DTASK__ACT_COMPLETE. Probably should
# try to get it from Starlink::ADAM but currently broken

$DTASK__ACTCOMPLETE = 142115659;

$SAI__OK = &Starlink::ADAM::SAI__OK;


# Cannot subclass methods since I need to change most of them
# anyway.

=item new

Create a new instance of a ORAC::Msg::ADAM::Task object.
 
  $obj = new ORAC::Msg::ADAM::Task;
  $obj = new ORAC::Msg::ADAM::Task("name_in_message_system","monolith");
 
If supplied with arguments (matching those expected by load() ) the
specified task will be loaded upon creating the object. If the load()
fails then undef is returned (which will not be an object reference).

=cut


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
 
  my $task = {};  # Anon hash
 
  # Since we are really simply handling another object
  # Create the new object (Starlink::AMS::Task) and store it.
  $task->{Obj} = new Starlink::AMS::Task;  # Name in AMS
 
  # Bless task into class
  bless($task, $class);

  # If we have arguments then we are trying to do a load
  # as well
  if (@_) { $task->load(@_); };
 
  return $task;
}


# Private method for handling the Starlink::AMS::Task object

sub obj {
  my $self = shift;
  if (@_) { $self->{Obj} = shift; }
  return $self->{Obj};
}


=item load

Load a monolith and set up the name in the messaging system.
This task is called by the 'new' method.

  $status = $obj->load("name","monolith_binary");

If the second argument is omitted it is assumed that the binary
is already running and can be called by "name".   

If a path to a binary with name "name" already exists then the monolith
is not loaded.

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


=item obeyw

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


=item get

Obtain the value of a parameter

 ($status, @values) = $obj->get("task", "param");

Note that this is a different order to that returned by the
Standard ADAM interface and follows the ORAC definition.

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

  my $arg = $task .":" . $param;

  my ($result, $status) = $self->obj->get($arg);

  # Convert $result to an array
  my @values = ();

  # an array of values if we have a square bracket at the start
  # something and a square bracket at the end 

  if ($result =~ /^\s*\[.*\]\s*$/) {
    # Remove the brackets
    $result =~ s/^\s*\[(.*)]\s*/$1/;
  
    # Now split on comma
    @values = split(/,/, $result);

  } else {
    push(@values, $result);
  }

  # Convert from ADAM to ORAC status
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return ($status, @values);
}

=item set

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

  my $arg = $task .":" . $param;

  my $status = $self->obj->set($arg, $value);

  # Convert from ADAM to ORAC status
  # Probably should put in a subroutine
  if ($status == $SAI__OK) {
    $status = ORAC__OK;
  }

  return $status;
}


=item control

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

=item resetpars

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


=item cwd

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


=item contactw

This method will not return unless the monolith can be contacted.
It only returns with a timeout. Returns a '1' if we contacted okay
and a '0' if we timed out. It will timeout if it takes longer than
specified in ORAC::Msg::ADAM::Control->timeout.

=cut


sub contactw {
  my $self = shift;
  return $self->obj->contactw;
}


=item contact

This method can be used to determine whether the object can
contact a monolith. Returns a 1 if we can contact a monolith and
a zero if we cant.

=cut

sub contact {
  my $self = shift;
  return $self->obj->contact;
}

=back

=head1 REQUIREMENTS

This module requires the Starlink::AMS::Task module.

=head1 SEE ALSO

L<Starlink::AMS::Task>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou (frossie@jach.hawaii.edu)    

=cut

# private methods


1;
