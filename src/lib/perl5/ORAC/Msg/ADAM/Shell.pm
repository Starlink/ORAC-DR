package ORAC::Msg::ADAM::Shell;

=head1 NAME

ORAC::Msg::ADAM::Shell - Run ADAM tasks from unix shell

=head1 SYNOPSIS

  use ORAC::Msg::ADAM::Shell;

  $kap = new ORAC::Msg::ADAM::Task("kappa","/star/bin/kappa/kappa_mon");

  $status           = $kap->obeyw("task", "params");
  $status           = $kap->set("task", "param","value");
  ($value, $status) = $kap->get("task", "param");
  ($dir, $status)   = $kap->control("default","dir");
  $kap->control("par_reset");
  $kap->resetpars;
  $kap->cwd("dir");
  ($cwd, $status) = $kap->cwd;

=head1 DESCRIPTION

Run ADAM tasks from the unix shell. Does not use a messaging system
but does attempt to provide a standard ORAC messaging interface.
This is intended as a test system to show the flexibility of the 
interface and as a backup if ADAM messaging is unavailable for some
reason.

The main limitation is that status handling is very poor.
Can only check for shell bad status since Starlink tasks do 
not return bad status when run from the unix shell.

=head1 METHODS

The following methods are available:

=over 4

=cut

use strict;
use Carp;

# Need this to perform the get() function
use NDF; 

# Need to strip a path
use File::Basename;

# Safe current directory
use Cwd;

# Retrieve the status constants
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;
 

=item new

Create a new instance of a ORAC::Msg::ADAM::Shell object.

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
 
  # Need to store some information
  $task->{Name} = undef;
  $task->{Monolith} = undef;
  $task->{Path}  = undef;
  
  # Set to current directory when initialised
  $task->{Cwd} = getcwd;

  # Bless task into class
  bless($task, $class);

  # If we have arguments then we are trying to do a load
  # as well
  if (@_) { $task->load(@_); };
 
  return $task;
}


# Provide methods for accessing and setting instance data
# Most are private except for cwd() which is a published method

# Store and access the messaging name
# Not overly useful but keep it any way

sub name {  
  my $self = shift;
  if (@_) { $self->{Name} = shift; }
  return $self->{Name};
}

# Name of the monolith that we are trying to run
# Note that we do not run this monolith directly since we run through
# a link in the file system

sub mon {
  my $self = shift;
  if (@_) { $self->{Monolith} = shift; }
  return $self->{Monolith};
}


# Location of monolith in the file system

sub path {
  my $self = shift;
  if (@_) { $self->{Path} = shift; }
  return $self->{Path};
}

=item cwd

Set and retrieve the directory in which this monolith
should operate.

  ($cwd, $status) = $obj->cwd("newdir")
  ($cwd, $status) = $obj->cwd;

If the specified directory does not exist, bad status is 
returned and the cwd is not changed.

=cut

sub cwd {
  my $self = shift;
  my $status = ORAC__OK;

  # Supply an argument
  if (@_) { 
    my $cwd = shift;

    # Check that the directory exists
    if (-d $cwd) {
      $self->{Cwd} = $cwd; 
    } else {
      $status = ORAC__ERROR;
    }

  }

  # Need to return a status since this is part of the
  # standard interface
  return ($self->{Cwd}, $status);

}


=item load

Initialise the monolith into the object. What this really
does is store the directory of the monolith 
so that it can be run and so that we can determine
which tasks are linked to it.

In reality the second argument is mandatory for this
interface since I have no idea where the monolith
is otherwise.

=cut

sub load {
  my $self = shift;

  my $name = shift;
  $self->name($name);

  # A further argument (optional) will be the monolith name
  if (@_) { 
    my $monolith = shift;

    # Need to separate monolith name from the path
    my ($mon, $path, $junk) = fileparse($monolith);
    
    # Check for a path. If current directory
    # then expand since I have no other idea
    if ($path eq "./") {
      $path = getcwd;
    }

    $self->path($path);
    $self->mon($mon);

  }
  
  # Have to return a status
  return ORAC__OK;
}


=item obeyw

Execute an ADAM task via the unix shell.
Return the shell exit status.

  $status = obeyw("task", "arguments");

Full path to "task" is not required since this was setup 
when the object was initialised via load().

Note that currently we have no control over the output
messages. It is conceivable that I could at least
redirect to /dev/null if a flag was set in the 
ControlSH module.

=cut

sub obeyw {
  my $self = shift;

  my $task = shift;
  my $args = shift;

  my $command = $self->path . "/" . $task;

  # Check that we can actually execute the command
  return ORAC__ERROR unless (-x $command);

  # Change to the current working directory before running
  # This probably has some overhead
  my $cwd = getcwd;

  my ($mondir, $junk) = $self->cwd;
  chdir($mondir) || croak "Error changing directory to $mondir";

  my $exstat = system("$command $args");

  # Now change directory back again
  chdir($cwd) || croak "Error changing back to current directory\n";

  return ORAC__OK if $exstat == 0;
  return $exstat;

}


=item get

Retrieve the current value of a parameter

  ($value, $status) = $obj->get("task", "param");

Array parameters are returned "," separated. Should consider
reversing the order such that status is returned first 
and array values after.

=cut


sub get {
  my $self = shift;

  my $task = shift;
  my $param = shift;
  my $status = &NDF::SAI__OK;

  my (@values) = par_get($param, $task, \$status);

  my $values = join(",", @values);

  $status = ORAC__OK if ($status == &NDF::SAI__OK);

  return ($values, $status);
}


=item set

Set a parameter.
Currently not implemented

=cut

sub set {


  return ORAC__OK;

}


=item control

Control current working directory and parameter resets.  The type of
control message is specified via the first argument. Allowed values
are:

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
  my $self = shift;
  my ($status);

  my $type = shift;

  if ($type eq "default") {
    my $newdir = shift;
    
    # An argument was passed
    if (defined $newdir) {
      $self->cwd($newdir);
    } else {
      # no argument
      ($newdir, $status) = $self->cwd
    }
    return $newdir, $status;
  } elsif ($type eq "par_reset") {

    $status = $self->resetpars;
    return (undef, $status);

  } else {
    croak "Unrecognised control type. Should be \'default\' or '\par_reset\'";
  }
   
}


=item resetpars

Reset parameter values.
A simplistic version is implemented that tries to remove
parameter files from the current ADAM_USER directory
depending on whether a link exists in the monolith directory.

Do nothing for now!

=cut

sub resetpars {
  my $self = shift;
  
  
  return ORAC__OK;
}


=item contact and contactw

Check that we can contact the monolith.
This method simply makes sure that we know where the monolith
is and that it can be executed. There is no difference between
contactw. and contact(). Returns a '1' if the command can be executed
and '0' if it cannot.

=cut

sub contact {
  my $self = shift;

  my $command = $self->path . "/" . $self->mon;

  print "Command in $command\n";
  # Check that we can actually execute the command
  return 0 unless (-x $command);

  return 1;
}


sub contactw {
  my $self = shift;

  return $self->contact;

}


=back

=head1 AUTHOR

Tim Jenness (t.jenness@jach.hawaii.edu).
and Frossie Economou (frossie@jach.hawaii.edu)

=head1 REQUIREMENTS

Requires the C<NDF>, C<Cwd> and C<File::Basename> modules.

=head1 See Also

L<perl>, 
L<ORAC::Msg::ADAM::Task>

=cut


1;
