package ORAC::Msg::Task::DRAMA;

=head1 NAME

ORAC::Msg::Task::DRAMA - load and control DRAMA tasks

=head1 SYNOPSIS

  $task = new ORAC::Msg::Task::DRAMA("mytask","/path/to/mytask");

  $status = $task->obeyw("task", "params");
  $status = $task->set("param", "value");
  ($status,@values) = $task->get("param");

=head1 DESCRIPTION

Provide methods for loading and communicating with DRAMA tasks.
This module conforms to the ORAC messaging standard and is an ORAC interface
to the DRAMA perl module.

By default all tasks loaded by this module will be terminated
on exit from the pipeline (when the object goes out of scope).

=cut

use 5.006;
use warnings;
use strict;
use Carp;

# Import ORAC constants
use ORAC::Constants qw/:status/;

use ORAC::Msg::Control::DRAMA;
use Proc::Simple;
use DRAMA ();
use Sds::Tie;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=item B<new>

Create a new instance of a ORAC::Msg::Task::DRAMA object.

  $obj = new ORAC::Msg::Task::DRAMA;
  $obj = new ORAC::Msg::Task::DRAMA("name_in_message_system","binary");

If supplied with arguments (matching those expected by load()) the
specified task will be loaded upong creating the object. If the load()
fails then undef is returned rather than an object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # create the hash and object
  my $task = bless {
		    TASKNAME => undef,
		   }, $class;

  # If we have arguments then we are trying to do a load
  # as well
  if (@_) {
    my $status = $task->load(@_);
    if ($status != ORAC__OK) {
      warnings::warnif "Error loading new DRAMA task (Status=$status)";
      return;
    }
  }

  return $task;
}

=head2 Accessor Methods

=item B<taskname>

Retrieve the name of the task associated with this object.

  $task = $obj->taskname();

=cut

sub taskname {
  my $self = shift;
  if (@_) {
    $self->{TASKNAME} = shift;
  }
  return $self->{TASKNAME};
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Accessor Methods

=over 4

=item B<_pid>

Internal method to access the C<Proc::Simple> object associated with
this task.

 $pid = $obj->_pid();

=cut

sub _pid {
  my $self = shift;
  if (@_) {
    $self->{PID} = shift;
  }
  return $self->{PID};
}

=back

=head2 General Methods

=over 4

=item B<load>

Load a DRAMA task. Called automatically by the object constructor.

 $status = $obj->load("name", "/path/to/binary" );

The first argument is the name that task will use when registering
itself with the DRAMA message system. If the second argument is
omitted it is assumed that the binary is already running and can be
called by "name".

Returns status.

=cut

sub load {
  my $self = shift;
  my $task = shift;
  my $path = shift;

  my $status = ORAC__OK;
  if (defined $task) {
    # store the task name for later
    $self->taskname( $task );

    if ($path) {

      # get the message system (and initialise if needs be)
      my $ms = new ORAC::Msg::Control::DRAMA(1);

      # first we should attempt to reconnect to an existing
      # task using this name
      if (!$self->contact()) {

	# The DramaLoad system requires that IMP master networking
	# task is running. ORAC-DR does not (yet) need networking so
	# for now, we will run up the application ourself.
	my $pid = new Proc::Simple;

	my $status = $pid->start( $path );

	if ($status == 1) {
	  $status = ORAC__OK;
	  $self->_pid( $pid );
	} else {
	  $status = ORAC__ERROR;
	}
      }
    }
  }

  return $status;
}

=item B<obeyw>

Send an obey to a task and wait for a completion message.

  $status = $obj->obeyw("action","params");

Parameters are optional.

=cut

sub obeyw {
  my $self = shift;
  my $action = shift;
  my $params = shift; # optional

  # get the message system settings
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  my $timeout = $ms->timeout; # seconds

  # assume badness
  my $status = ORAC__ERROR;

  # run the obeyw
  # wrapping the parameters into an SDS structure
  DRAMA::obeyw( $self->taskname,
		$action,
		( defined $params ? _tosds( $params ) : () ),
		{
		 -info => \&cbinfo,
		 -success => sub { $status = ORAC__OK; },
		 -error => sub { 
		   # need to trap BadEng status
		   $status = _translate_err( $_[2] );
		   &cberror( $_[1] );
		 },
		 -timeout => $timeout,
		});
  return $status;
}

=item B<get>

Obtain the value of a parameter from a task. Unlike the AMS interface,
there is no concept of a monolith in DRAMA so there is one set of
parameters for the task independent of the number of actions the task
supports. This routine therefore takes a single argument naming the
parameter and that parameter can be hierarchical by using a "." to
separate the hierarchy (we could use the first argument to specify a
structure in the hierarchy and subsequent arguments going deeper into
the structure but it seems just as easy to require a single
dot-separated string).

When called from an array context the status and values are returned
(multiple values are returned in a list). When called from a scalar
context the values are returned: scalars as themselves, arrays and
structures as a reference. Note that DRAMA uses PDLs for arrays such
that the return value of a numeric array will be a scalar PDL rather
than a list.

 ($status, @values) = $obj->get("param");

or

  $value = $obj->get("param");

Single numbers will be returned as single numbers rather than PDLs.

=cut

sub get {
  my $self = shift;
  my $param = shift;

  # get the message system settings
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  my $timeout = $ms->timeout; # seconds

  my $status;
  my $result = DRAMA::pgetw( $self->taskname,
			     $param,
			     {
			      -info => \&cbinfo,
			      -error => sub { 
				$status = _translate_err( $_[2] );
				&cberror( $_[1] ); 
			      },
			      -timeout => $timeout,
			     });

  # error?
  return ( wantarray ? ( defined $status ? $status : ORAC__ERROR) : undef ) 
    if (defined $status || !defined $result);

  # reset the status
  $status = new DRAMA::Status;

  # We have a structured result already, so tie to a HASH for simplicity
  my %tie;
  tie %tie, "Sds::Tie", $result;

  # we are interested in the "$param" key
  return (wantarray ? (ORAC__ERROR) : undef ) if !exists $tie{$param};

  # now handle scalar vs list context
  if (!wantarray) {
    return $tie{$param};
  } else {
    my @retvals;
    if (ref($tie{$param}) eq 'HASH') {
      @retvals = %{ $tie{$param} };
    } elsif (ref($tie{$param}) eq 'ARRAY') {
      @retvals = @{ $tie{$param} };
    } else {
      @retvals = ( $tie{$param} );
    }
    return (ORAC__OK, @retvals);
  }
}

=item B<set>

Set a parameter in a remote task. DRAMA has no concept of monoliths so, similarly to C<get>,
there is no action parameter.

  $status = $task->set( $param, $value );

Returns ORAC__OK on success.

=cut

sub set {
  my $self = shift;
  my $param = shift;
  my $value = shift;

  # get the message system settings
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  my $timeout = $ms->timeout; # seconds

  my $status;
  DRAMA::pset( $self->taskname,
	       $param, $value,
	       {
		-wait => 1,
		-info => \&cbinfo,
		-timeout => $timeout,
		-error => sub { 
		  $status = _translate_err($_[2]);
		  &cberror( $_[1] );
		},
		-success => sub { }, # Hide default success message
	       });

  return (defined $status ? $status : ORAC__OK );
}

=item B<control>

Send control messages to the DRAMA task. Currently a no-op.

=cut

sub control {
  return;
}

=item B<forget>

Forget that this object launched the DRAMA task (if it did).
This will prevent it from being shutdown when the object goes out of scope.

=cut

sub forget {
  my $self = shift;
  $self->_pid( undef );
  return;
}

=item B<contact>

Returns boolean indicating whether the remote task can be contacted
or not.

=cut

sub contact {
  my $self = shift;
  my $task = $self->taskname;

  # get the message system (and initialise if needs be)
  # this makes sure we always have a message system
  my $ms = new ORAC::Msg::Control::DRAMA(1);

  my $con = 0;
  # we should really just use the TaskRunning functionality
  # but that is not yet implemented in perl/DRAMA
  # For non-perl or non-Jit tasks we cannot guarantee PING
  # availability so we will have to either switch technique or trap
  # UNKNOWN ACTION.
  DRAMA::obeyw $self->taskname, "PING", {
					 # do not care about output text
				         -info => sub { },
					 -success => sub { $con = 1 },
					 -error => sub { $con = 0 },
				 };
  return $con;
}


=item B<contactw>

Similar to the C<contact> method, except that this method continually
retries to make a connection with the remote task until the global timeout
has been exceeded. This allows this method to be used whilst a DRAMA
task is loading.

  $isloaded = $task->contactw();

Returns true as soon as a connection is made.

=cut

sub contactw {
  my $self = shift;

  # need to find the timeout
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  my $timeout = $ms->timeout; # seconds

  my $ref = time();
  while ( time() - $ref < $timeout) {
    my $con = $self->contact;
    return $con if $con; # abort if we can contact
    select undef,undef,undef,0.2;
  }
  # did not make contact
  return 0;
}

=item B<DESTROY>

When the object is destroyed, the remote drama task is shutdown if
it was started by this object.

=cut

sub DESTROY {
  my $self = shift;
#  print "IN DESTROY WITH : ". $self->taskname . " using ". 
#    (defined $self->_pid ? $self->_pid : "<NOT STARTED>") ."\n";
  if (defined $self->_pid) {
    my $pid = $self->_pid;
    # we started this task so trigger the EXIT
    # and if that fails set the kill_on_destroy() flag
    DRAMA::obeyw $self->taskname, "EXIT", {
					   -success => sub {
#					     print "shutdown cleanly\n";
					   },
					   -error => sub {
					     $pid->kill_on_destroy(1);
					   },
					  };

  }
  return;
}

=back

=begin __PRIVATE_FUNCTIONS__

=head2 Callbacks

This section implements standard callback handlers that respect the
settings specified in the message system object.

=over 4

=item B<cbinfo>

Info handler, pushing messages to the correct filehandle.
This routine expects an input list with all the info
messages to forward.

=cut

sub cbinfo {
  my @msgs = shift;

  # get the message system
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  return unless $ms->messages;

  my $stdout = $ms->stdout;
  return if !defined $stdout;

  for my $m (@msgs) {
    chomp($m);
    print $stdout "Inf: $m\n";
  }
  return;
}

=item B<cberror>

Error handler, pushes error messages to the correct error filehandle.
Usually not called directly by the DRAMA system since we need to
pass the bad error status to the caller.

This routine expects a list of error messages to be forwarded to the
correct location.

=cut

sub cberror {
  my @msgs = shift;

  # get the message system
  my $ms = new ORAC::Msg::Control::DRAMA(1);
  return unless $ms->errors;

  my $stderr = $ms->stderr;
  return if !defined $stderr;

  for my $m (@msgs) {
    chomp($m);
    print $stderr "Err:$m\n";
  }
  return;
}

=back

=head2 Internal Helper functions

=over 4

=item B<_tosds>

Takes a parameter "string" as provided by ORAC-DR and converts
it to an SDS structure.

Returns empty list if there is nothing to wrap (this allows
it to be used in the argument list for obeyw etc).

  $sds = _tosds( $param );

=cut

sub _tosds {
  my $param = shift;
  return ();
}

=item B<_translate_err>

Translates a DRAMA error code to an ORAC-DR error code.

  $orac_code = _translate_err( $drama );

Where the DRAMA code can be an integer or a DRAMA::Status object.

=cut

sub _translate_err {
  my $status = shift;
  $status = $status->GetStatus if ref($status);

  if ( $status == Dits::DITS__TASKDISC ||
       $status == 265322652 # UNKNTASK
     ) {
    return ORAC__BADENG;
  } else {
    return ORAC__ERROR;
  }
}

=back

=end __PRIVATE_FUNCTIONS__

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
