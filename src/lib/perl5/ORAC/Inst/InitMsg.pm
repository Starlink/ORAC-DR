package ORAC::Inst::InitMsg;

=head1 NAME

ORAC::Inst::InitMsg - Base class for initialising instrument message system

=head1 SYNOPSIS

  use ORAC::Inst::InitMsg;

  $inst = new ORAC::Inst::InitMsg;

  $inst->start_msg_sys;
  $inst->start_algorithm_engines;
  $inst->wait_for_algorithm_engines;

  @messobj = retrieve_msg_objects;
  %Mon  = retrieve_algorithm_engines;


=head1 DESCRIPTION

This class initialises the messaging system for an ORAC instrument.
In practice the specifics are dealt with in a sub class and this
class only provides a generic interfacce.

=cut

use strict;
use Carp;

use ORAC::Constants qw/ :status /;
use ORAC::Print;

use vars qw/ $DEBUG /;

$DEBUG = 0;

=head2 Constructors

The following constructors are provided:

=over 4

=item B<new>

Create a new instance of B<InitMsg>.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $inst = {
	      MsgSys => [],
	      AlgEng => {},
	     };

  bless($inst, $class);

  return $inst;
}


=back

=head2 Accessor Methods

The following accessor methods are provided:

=over 4

=item B<_algeng>

Low level access to the algorithm engine objects instantiated
by this object. Returns a hash reference.

=cut

sub _algeng {
  return $_[0]->{AlgEng};
}

=item B<_msgsys>

Low level access to the message system objects instantiated
by this object. Returns an array reference.

=cut

sub _msgsys {
  return $_[0]->{MsgSys};
}

=item B<retrieve_algorithm_engines>

Returns a hash of all the algorithm engine objects instantiated
by this class.

=cut

sub retrieve_algorithm_engines {
  return %{ $_[0]->_algeng };
}

=item B<retrieve_msg_objects>

Returns an array of all the message system objects instantiated
by this class.

=cut

sub retrieve_msg_objects {
  return @{ $_[0]->_msgsys };
}


=back

=head2 General Methods

This section describes the general methods.

=over 4

=item B<start_algorithm_engines>

Start the algorithm engines required by the current instrument.
A sub-class is responsible for defining which algorithms are 
required and launching them. Returns a hash containing the
name of the algorithm engine and the corresponding object.

  %Mon = $inst->start_algorithm_engines;

Returns an empty list on error. The base class does nothing.

=cut

sub start_algorithm_engines {
  return ();
}


=item B<start_msg_sys>

Starts the message system and returns an array of objects
(one for each message system that was started).

Returns an empty list on error. The base class does nothing.

=cut

sub start_msg_sys {
  return ();
}

=item B<wait_for_algorithm_engines>

This method checks that each of the algorithm engines launched
are contactable. This relies on each object having a C<contactw>
method. Since each engine is checked and since each check
blocks until it is contactable or timeouts, this method
may take a long time to complete.

Returns ORAC__OK if all the engines can be contacted
and ORAC__ERROR if any can not be contacted.

  $status = $inst->wait_for_algorithm_engines;

This method checks that any engines that have already been
started are contactable. This means the method is valid
even if nothing has yet been started and the engines are
to be launched on demand.

=cut

sub wait_for_algorithm_engines {
  my $self = shift;

  my %engines = $self->retrieve_algorithm_engines;

  # Loop over each engine
  for my $eng (keys %engines) {

    orac_print "Waiting for engine $eng\n"
      if $DEBUG;

    # Wait for this engine to start. Return ERROR
    # if we timeout
    return ORAC__ERROR unless $engines{$eng}->contactw;

  }

  # If we make it to here everything is okay
  return ORAC__OK;

}


=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

These methods are usable by the class or sub-classes internally
but are not part of the external published interface.

=over 4

=item B<_launch_algorithm_engines>

Launches the algorithm engines as specified in a hash with the
 structure:


  %algeng = (
	     kappa_mon => {
			   CLASS => 'ORAC::Msg::ADAM::Task',
			   PATH  => "$ENV{KAPPA_DIR}/kappa_mon"
			   REQUIRED => 1,
			  },
	     ccdpack_reg => {
			     ...
			    }
	    );

The C<REQUIRED> flag indicates whether a fatal error should be
raised if the engine could not be launched.

  %Mon = _launch_algorithm_engines( %EngDef );

Returns a hash containing the object. The method dies if a required
engine could not be launched.

=cut

sub _launch_algorithm_engines {
  my $self = shift;

  my %Mon;
  my %EngDef = @_;

  for my $eng (keys %EngDef ) {

    my $info = $EngDef{$eng};

    # Launch it if we can find the path
    my $obj = $info->{CLASS}->new($eng . "_$$",
				  $info->{PATH} )
      if ( -e $info->{PATH} );

    # If $obj is not defined but required we hae a fatal error
    croak "Unable to launch engine $eng using ".$info->{PATH} .
      "\nAborting since this engine is required\n"
      if ($info->{REQUIRED} && ! defined $obj);

    # Store the object
    $Mon{$eng} = $obj if defined $obj;

  }

  # Store the hash
  %{ $self->_algeng } = %Mon;

  # Return the hash
  return %Mon;

}

=back

=end __PRIVATE_METHODS__

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
