package ORAC::Msg::EngineLaunch;

=head1 NAME

ORAC::Msg::EngineLaunch - Launch engines on demand

=head1 SYNOPSIS

  use ORAC::Msg::EngineLaunch;

  $eng = new ORAC::Msg::EngineLaunch;

  $obj = $eng->get("polpack_mon");
  $eng->detach("polpack_mon");

  tie %Mon, "ORAC::Msg::EngineLaunch";
  $obj = $Mon{"polpack_mon"};
  delete $Mon{"polpack_mon"};

=head1 DESCRIPTION

This class provides a means of launching arbritrary algorithm
engines on demand. If an engine has not previously been
launched the class will start it, if it has been launched it
will retrieve the current object. The algorithm engines will
be C<ORAC::Msg> task objects (eg L<ORAC::Msg::ADAM::Task>).
This allows engines to be launched only when required to minimize
resource demand.

It is also possible to tie the class to a hash. This allows
for a non-object oriented approach where the engine can be launched
simply by accessing the engine through the hash.

=cut

use strict;
use Carp;

use vars qw/ $DEBUG /;
$DEBUG = 1;

# For now, the algorithm engine definitions are stored in
# ORAC::Inst::Defn. This is for historical reasons and to
# provide a single file for all instrument and engine
# definitions. This could be changed with minimal effort
# if required.

# Additionally, all engine launching should use this
# interface (not just recipe engines) and once more than
# one messaging interface is required this class should be
# modified to start the messaging interface on demand as
# well.

use ORAC::Inst::Defn qw/ orac_engine_description /;

=head1 METHODS

The following methods are provided:

=head2 Constructor

Object constructors.

=over 4

=item B<new>

Instantiate a new object ready for launching.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {
	     Engines => {},
	     EngineID => {},
	     };

  # bless into the correct class
  bless( $obj, $class);

  return $obj;
}


=back

=head2 Accessor Methods


=over 4

=item B<engine>

Retrieve the object associated with the specified engine, launching
it if required.

  $obj = $launch->engine("polpack_mon");

C<undef> is returned if the engine could not be launched.

The engine object can be stored if two arguments are used.
A rudimentary check is made to make sure that the object
is a reference and that the C<contactw> method is supported.
It is not possible to check a true ISA relationship. If the
object does not satisfy this condition it is not stored and
a warning is raised with "-w".

  $launch->engine("polpack_mon", $object);

Returns a hash reference containing all the currently launched engines
if called without arguments.

  $launched = $launch->engine;

=cut

sub engine {
  my $self = shift;

  if (@_) {
    my $name = shift;

    # If we have a second argument we are expecting 
    # to store a value
    if (@_) {
      my $obj = shift;

      # Store it
      if (defined $obj && UNIVERSAL::can($obj, "contactw")) {
	$self->{Engines}->{$name} = $obj;
      } else {
	warn "engine: Supplied object does not have a contactw method"
	  if $^W;
      }

    } elsif (exists $self->{Engines}->{$name}) {
      # No other argument and we have already launched it
      # before, return it
      return $self->{Engines}->{$name};

    } else {
      # Need to launch the engine
      # and store it in the object
      print "Launching engine $name...\n" if $DEBUG;
      my $obj = $self->launch( $name );

      # Return it
      return $obj;
    }
  } else {
    return $self->{Engines};
  }
}

=item B<engine_id>

The message system identifier. This is used by some message systems
(e.g. ADAM) to indicate a specific identifier that should be used
to name the engine in the message system. This allows, for example,
the pipeline to attach to an engine that has been launched
outside of the pipeline infrastructure. For engines launched
by the pipeline each new identifier must be unique for each pipeline
and for each repeat monolith launch (in the case where engines
die and are restarted).

This method is used to store the previous id for each engine so that
a new id can be generated.

  $id = $launch->engine_id( $engine );
  $launch->engine_id( $engine, $id );

The C<engine_inc> method should be used to generate a new id.

If no arguments are supplied a reference to the hash of IDs is
returned. C<undef> is returned if an id is requested for an
engine that has not been launched.

=cut

sub engine_id {
  my $self = shift;
  if (@_) {
    my $eng = shift;
    if (@_) {
      my $id = shift;
      $self->{EngineID}->{$eng} = $id;
      return $id;
    } elsif (exists $self->{EngineID}->{$eng}) {
      return $self->{EngineID}->{$eng};
    } else {
      return undef;
    }
  }
  return $self->{EngineID};
}

=back

=head2 General Methods

=over 4

=item B<detach>

Disassociate the named engine from the object. This can be used
if an engine has crashed and it is necessary to launch a new
engine next time.

  $launch->detach( $engine );

=cut

sub detach {
  my $self = shift;
  my $engine = shift;
  # engine IDs must remain intact so that they will be different
  # next time around
  delete $self->engine->{$engine};
}


=item B<launch>

Launch the specified monolith.

  $obj = $launch->launch( $engine );

The engine object is stored in the class.  Returns undef on error.

The routine does not return until the engine has completed loading
(i.e. the C<contactw> method returns successfully). This is less
efficient than launching all the monoliths and then waiting for
them but it is the price paid for launching on demand.

This overhead can be overcome by pre-launching engines that are
known to be required and launching optional engines on demand.
If the engines are launched outside this infrastructure they
can be registered with the object using the C<engine> method.

=cut

sub launch {
  my $self = shift;
  my $engine = shift;

  # Retrieve the engine parameters
  my %pars = orac_engine_description( $engine );

  # Check that we have something
  if ( %pars ) {

    # The hash specifies CLASS as object type
    # PATH as location to the particular monolith
    # (assumed to be an actual file on disk)
    # This assumption may have to be addressed in future
    # extensions

    # Make sure the messaging class is available
    eval "use $pars{CLASS}";
    if ($@) { 
      carp "Unable to load class $pars{CLASS} for engine $engine\n";
      croak "$@";
    }

    # Launch it if we can find the path
    # The object identifier should be different each time
    # this is called to protect against systems that can not
    # reuse system identifiers
    my $obj = $pars{CLASS}->new($self->engine_inc( $engine ),
				$pars{PATH} )
      if ( -e $pars{PATH} );

    # check that we have something
    if (defined $obj) {

      # Make sure we can talk to it
      return undef unless $obj->contactw;

      # Store the result
      $self->engine( $engine, $obj);

    } else {
      return undef;
    }

  } else {
    return undef;
  }
}

=item B<engine_inc>

Return a new ID for the specified engine.

  $id = $self->engine_inc( $engine );

The current ID is updated (see C<engine_id> for more details).

=cut

sub engine_inc {
  my $self = shift;
  my $eng = shift;
  my $id;
  if (defined $self->engine_id( $eng )) {
    # Retrieve current id
    $id = $self->engine_id( $eng );

    # Construct a new id by splitting this up and incrementing
    my @bits = split("_",$id);
    $bits[-1]++;
    $id = join("_", @bits);

  } else {
    # create a brand new id based on the pid and a number
    $id = $eng . "_$$". "_1";
  }
  # store the new id and return it
  $self->engine_id( $eng, $id );
  print "Generated ID for engine $eng: $id\n" if $DEBUG;
  return $id;
}

=back

=head1 TIED INTERFACE

This class also provides a means of tieing an object to
a standard perl hash allowing for transparent access to
engines.

A hash can be tied to an object by using the C<tie> function:

  tie %Mon, "ORAC::Msg::Engine::Launch";

It is also possible to tie a hash to an existing object:

  tie %Mon, ref($object), $object;

The following can be used to retrieve the object associated with
"polpack_mon" launching the engine if necessary:

  $object = $Mon{"polpack_mon"};

Engines can be dissassociated from the object using the
standard hash C<delete> command:

  delete $Mon{"polpack_mon"};

C<exists>, C<clear>, C<keys> and C<each> are supported.

In addition, it is possible to explicitly set entries in the hash. A
rudimentary check is made to check that the stored entry is an object
that can invoke a "contactw" method but it is not possible to check
that the object is of the correct type (since there is currently no
complete inheritance tree for engines). If the argument is not okay
the object a warning will be issued under "-w".

  $Mon{engine} = $some_object;

A reference to the hash still has access to the tied hash.  A copy of
the hash (e.g. C<%New = %Old>) will copy the contents of the hash
without copying the tie.  In order to copy the hash and retain the
tie, it is necessary to tie the new hash rather than copying it.

  $object = tied %Mon;
  tie %New, ref($object), $object;

=cut

sub TIEHASH {
  # Get the class name
  my $self = shift;

  my $obj;
  if (@_) {
    # use an existing object
    $obj = shift;
  } else {
    # create a new object
    $obj = new $self;
  }
  return $obj;
}

sub FETCH {
  my $self = shift;
  my $key = shift;
  return $self->engine( $key );
}

sub STORE {
  my $self = shift;
  my $key = shift;
  my $value = shift;
  $self->engine( $key, $value )
}


sub EXISTS {
  my $self = shift;
  my $key = shift;
  return exists $self->engine->{$key};
}

sub DELETE {
  my $self = shift;
  my $key = shift;
  $self->detach( $key );
}

sub CLEAR {
  my $self = shift;
  %{ $self->engine } = ();
}

sub FIRSTKEY {
    my $self = shift;
    my $a = keys %{$self->engine};          # reset each() iterator
    each %{$self->engine}
}

sub NEXTKEY  {
  my $self = shift;
  return each %{ $self->engine }
}


=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;


