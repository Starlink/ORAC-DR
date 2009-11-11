package ORAC::Inst;

=head1 NAME

ORAC::Inst - Base class for initialising instruments

=head1 SYNOPSIS

  use ORAC::Inst;

  $inst = new ORAC::Inst;

  %Mon = $inst->start_algorithm_engines;
  $status = $inst->wait_for_algorithm_engines;


=head1 DESCRIPTION

This class is responsible for instrument specific initialisations.
Currently this simply involves prestarting certain algorithm
engines and returning a tied hash contianing those objects.

This base class should be extended as required.

=cut

use 5.006;
use strict;
use warnings;
use Carp;

use ORAC::Constants qw/ :status /;
use ORAC::Print;
use ORAC::Msg::EngineLaunch;    # In order to dynamic load

use vars qw/ $DEBUG /;

$DEBUG = 0;

=head2 Constructors

The following constructors are provided:

=over 4

=item B<new>

Create a new instance of C<ORAC::Inst>.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $inst = {
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
by this object. Returns a hash reference. This reference may be
tied.

If this hash is tied it could be possible for it to contain
all active engines not just those that were started by this
class (it will include those launched dynamically).
It is possible that this hash will be

=cut

sub _algeng {
  my $self = shift;
  if (@_) {
    $self->{AlgEng} = shift;
  }
  return $self->{AlgEng};
}

=item B<retrieve_algorithm_engines>

Returns a hash of all the algorithm engine objects that are
currently active.

=cut

sub retrieve_algorithm_engines {
  return %{ $_[0]->_algeng };
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

Launches the specified algorithm engines.

  $hashref = $inst->_launch_algorithm_engines( @engines );

Returns a reference to a tied hash containing the engines
and associated objects. The method checks that all
engines are contactable and croaks if any can not be contacted.

=cut

sub _launch_algorithm_engines {
  my $self = shift;

  my @engines = @_;

  my %Mon;

  # Create new object for launching
  my $launch = new ORAC::Msg::EngineLaunch;

  # Launch all the engines at once for efficiency
  my %launched = $launch->launch( @engines );

  # Now we need to wait for them all
  my ($ok, $nok) = $launch->contact_all;

  # Raise an error if we were unable to launch them all
  if (@$nok) {
    my $fail = join(",", @$nok);
    croak "Unable to launch the following engines: $fail\n".
      "Aborting since these engines are required\n";
  }

  # Tie the hash to the launch object
  tie %Mon, ref($launch), $launch;

  # Store them in this object for backwards compatibility
  # Store the tied hash reference
  $self->_algeng(\%Mon);

  # Return the hash reference
  return \%Mon;
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
