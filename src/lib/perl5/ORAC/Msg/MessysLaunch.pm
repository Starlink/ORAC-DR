package ORAC::Msg::MessysLaunch;

=head1 NAME

ORAC::Msg::MessysLaunch - Generic interface for initialising message systems

=head1 SYNOPSIS

  use ORAC::Msg::MessysLaunch;

  $msl = new ORAC::Msg::EngineLaunch;

  $obj = $msl->messys( 'AMS' );
  %objs = $msl->messys_active;

=head1 DESCRIPTION

This class provides a generic interface to the messaging systems
supported by ORAC-DR. The knowledge of how to setup and initialise
all the supported messaging systems is included in this class.

The message systems are started on demand (that is, the first
time an object is requested by name). The message systems will
be C<ORAC::Msg::Control> objects (eg L<ORAC::Msg::Control::AMS>).

This interface allows message systems to be initialised only
when specific algorithm engines are required (rather than
starting every message system even if none are required).

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use ORAC::Constants qw/ :status /;
use ORAC::Inst::Defn qw/ orac_messys_description /;
use ORAC::Print;

use vars qw/ $DEBUG /;
$DEBUG = 0;

# Use package variable to store the object name so that
# it can be reused. This will of course delay object desctruction
# until interpreter shutdown.

use vars qw/ $THIS /;

=head1 METHODS

The following methods are provided:

=head2 Constructor

Object constructors.

=over 4

=item B<new>

Instantiate a new object ready for launching.

  $launch = new ORAC::Msg::MessysLaunch( $unique );

Since, in general, it is convenient for all parts of the code to have
access to previously started message systems (and in many cases it is
an error to start 2 identical message systems), the default behaviour
is for the constructor to return the same object reference each time
it is called. If it is required for a completely new object to be
created each time the argument must be set to true.

ORAC-DR usually requires that access is provided to all previously
initialised message systems so that the messaging layer can be
configured by any subsystem.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Read uniqueness argument
  my $unq = shift;

  my $obj;

  # If uniqueness flag is true we need a brand new object
  # We also need a new object is one has not been stored previously
  if ($unq || !defined $THIS) {

    $obj = {
	    MessageSystems => {},
	    ConfigOptions => {},
	    Preserve => 0,
	   };

    # bless into the correct class
    bless( $obj, $class);

    # If we are not unique, store the object
    $THIS = $obj unless $unq;

  } else {
    # We need to retrieve $THIS from the package variable
    $obj = $THIS;
  }

  return $obj;
}

=back

=head2 Accessor Methods


=over 4

=item B<config>

Allows the message system configuration to be stored. These options
are used to configure each message system that is initialised.

If it is required to configure message systems that are already
running use the C<configure_all> method.

Accepts a hash containing the names of the methods to invoke
on the message system object and the options to use.

  $msl->config( messages => 1,
                   timeout => 600,
                   ... );

Currently, all options are configured at once and any previous
options (even if they have different names) are lost.

Returns a hash with the current configuration.

=cut

sub config {
  my $self = shift;
  if (@_ ) { %{ $self->{ConfigOptions} } = @_; }
  return %{ $self->{ConfigOptions} };
}


=item B<messys>

Retrieve the object associated with the specified message system, initialising
it if required.

  $obj = $msl->messys("AMS");

C<undef> is returned if the message system could not be initialised.

The message system object can be stored if two arguments are used.  A
rudimentary check is made to make sure that the object is a
reference. It is not possible to check a true ISA relationship I<until
the class structure is reorganized>. If the
object does not satisfy this condition it is not stored and a warning
is raised with "-w".

  $msl->messys("AMS", $object);

Returns a hash reference containing all the currently launched engines
if called without arguments.

  $launched = $launch->messys;

See also C<messys_active>.

=cut

sub messys {
  my $self = shift;

  if (@_) {
    my $name = shift;

    # If we have a second argument we are expecting
    # to store a value
    if (@_) {
      my $obj = shift;

      # Store it - need to check ISA at some point
      if (defined $obj) {
	$self->{MessageSystems}->{$name} = $obj;
      } else {
	warnings::warnif("engine: Supplied object does not have a contactw method");
      }

    } elsif (exists $self->{MessageSystems}->{$name}) {
      # No other argument and we have already initialised it
      # before, return it
      return $self->{MessageSystems}->{$name};

    } else {
      # Need to init the message system
      # and store it in the object
      print "Initialising message system $name...\n" if $DEBUG;
      my $obj = $self->init_messys( $name );

      # Return it
      return $obj;
    }
  } else {
    return $self->{MessageSystems};
  }
}

=item B<messys_active>

Returns a hash containing all the message system objects
that have been created.

 %Messys = $msl->messys_active;

=cut

sub messys_active {
  my $self = shift;
  return %{ $self->messys };
}

=item B<preserve>

This method is used to set or retrieve the C<preserve> flag. The
C<preserve> flag controls whether the messys environment variables
should be left unchanged for initialisation or whether the system
should be initialised such that it does not interfere with 
non-ORAC-DR environments.

The default is that the message system should be initialised such
that it does not interfere with other external systems. This
is required if multiple ORAC-DR pipelines are to be run on the same
machine by the same user.

If preserve is set to true it may be possible for the pipeline to
interact with algorithm engines launched outside the context of the
pipeline. This is the case when ORAC-DR is configure to interact
with CGS4DR.

  $msl->preserve(1);
  $preserve = $msl->preserve;

=cut

sub preserve {
  my $self = shift;
  if (@_) { $self->{Preserve} = shift; }
  return $self->{Preserve};
}

=back


=head2 General Methods

=over 4

=item B<configure_all>

Configure all the current message systems using the configuration
options that have been set previously by use of the C<config>
method.

  $msl->configure_all;

=cut

sub configure_all {
  my $self = shift;
  my %messys = $self->messys_active;

  # loop over them all
  foreach my $name (keys %messys) {
    $self->configure_messys( $name );
  }

}

=item B<configure_messys>

Configures the named message system using the configuration
options that have been set previously by use of the C<config>
method.

  $msl->configure_messys( 'AMS' );

=cut

sub configure_messys {
  my $self = shift;
  my %config = $self->config;
  my $name = shift;

  my $messys = $self->messys( $name );

  for my $option (keys %config) {

    if ($messys->can($option)) {

      print "Configuring $name option $option: $config{$option}\n"
	if $DEBUG;
      $messys->$option( $config{$option});

    }

  }

}


=item B<init_messys>

Given a message system name (for example 'AMS') initialise the
message system so that it can be used by algorithm engines.

  $messys_obj = $msl->init_messys( 'AMS' );

Returns the object that was instantiated, or undef on error.

If the message system has been initialised previously that
object is returned.

=cut

sub init_messys {
  my $self = shift;

  my $name = shift;

  # Check to see if the object already exists.
  # Can not use the messys method directly since if the name does
  # exist, then nothing will happen, but if it doesn't exist
  # the messys method will launch this method which will then
  # check to see whether the engine exists, ad infinitum
  # Have to assume knowledge of the implementation of this object
  return $self->messys($name) if exists $self->messys->{$name};

  # Get parameters of the system initialisation
  my %pars = orac_messys_description( $name );

  # Check that we have something
  if ( %pars ) {

    # Make sure that the class is available
    eval "use $pars{CLASS}";
    if ($@) {
      orac_warn "Unable to load class $pars{CLASS} for message system $name\n";
      orac_throw( "$@" );
    }

    # Initialise it
    my $obj = $pars{CLASS}->new();

    if (defined $obj) {

      my $status = $obj->init( $self->preserve );
      if ($status == ORAC__OK) {

	# Store it
	$self->messys( $name, $obj );
	
	# Configure it
	$self->configure_messys( $name );

	# Return it
	return $obj;

      } else {
	orac_warn("Unable to initialise $name message system\n");
      }

    }

  } else {
    orac_throw("Do not know anything about message system: $name\n");
  }

  # Get here if nothing worked
  return undef;

}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2001-2005 Particle Physics and Astronomy Research
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

1;
