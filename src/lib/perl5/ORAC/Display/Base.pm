package ORAC::Display::Base;

=head1 NAME

ORAC::Display::Base - base class for ORAC display interface

=head1 SYNOPSIS

  use ORAC::Display::Base;

=head1 DESCRIPTION

Provides the generic methods for handling ORAC Display devices.
The generic routines (those worth inheriting) deal with display
device name allocation (eg mapping a device number to a real device).


=cut

use 5.004;

use Carp;
use strict;

use ORAC::Print;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION $DEBUG/;

$VERSION = '1.0';
$DEBUG   = 0;

=head1 PUBLIC METHODS

=head2 Constructor

=over 4

=item B<new>

Base class constructor. Can be called as SUPER::new() from
sub-classes. Accepts a configuration hash as input in order to
initialise extra instance data components of the class that are
required by sub-classes.

  $a = new ORAC::Display(a => 'b', c => 'd');

This constructor does not attempt to launch a display device.
That is up to the sub-classes.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create new instance
  my $disp = {
	      Dev => {},
	      @_
	     };

  # Bless into class
  bless $disp, $class;

}

=back

=head2 Accessor Methods

=over 4

=item B<dev>

Method for handling the hash of device name mapping. ie Which 
device name (as required for each Display interface, eg '.rtd0',
'xwindows;$$') is associated with the ORAC name (eg '0','1','default').

The hash reference is returned when called with no arguments:

  $href = $self->dev;

The value associated with the supplied key is returned if one
argument is provided:

  $value = $self->dev('key');

The supplied value is stored in key if two arguments are supplied:

  $self->dev('key','value');

Undefined values are accepted.

=cut

sub dev {
  
  my $self = shift;

  # look for arguments
  if (@_) {
    # read the key
    my $key = shift;

    # look for a value
    if (@_) {  
      $self->{Dev}->{$key} = shift; 
    }

    # Return the value - stop it creating undef keys 
    if (exists $self->{Dev}->{$key}) {
      return $self->{Dev}->{$key};
    } else {
      return;
    }
  }

  # Else no arguments so return the hash ref
  return $self->{Dev};
}

=back

=head2 General Methods

=over 4

=item B<window_dev>

Returns the device id (eg GWM device name or RTD window name)
associated with window 'win'. If 'win' is undefined a new
window is launched, the id stored in the hash and the
new id returned. (see the launch_dev() method). If this
is the first time the routine is called (ie the only window
name present is 'default', the name of the default window
is associated with window win.). We go through this hoop
so that devices will open a window before the user has associated
their user-defined name with the actual window name.

  $name = $self->window_dev('win');

If the windows were launched with bad status we should 
set the device name to something recognisable as bad
since status is not returned.

=cut

sub window_dev {
  my $self = shift;
  
  croak 'Usage: window_dev(win)' unless scalar(@_) == 1;

  my $win = shift;

  my ($dev, $status);
  $status = ORAC__OK;
  
  # If the key exists already just return the value
  if (defined $self->dev($win)) {
    return $self->dev($win);
  }

  # Find out how many keys we have in the devices hash
  my $ndev = scalar keys %{$self->dev};

  # If there are zero keys (-1) we have to come up with a new name
  # if there is 1 key AND it is called 'default' then we need to return
  # this device and associate the new window with that device

  if ($ndev == 1) {
    # We already have a device open.
    # but this window does not map to it
    
    # If the 'default' exists then return that one and associate new
    # window with it
    if (defined $self->dev('default')){
      $self->dev($win, $self->dev('default'));
    } else {
      # get a new device and use that
      # New device
      $dev = $self->newdev($win);
      # Now set it in the object
      $self->dev($win, $dev);

      # and launch it...
      $status = $self->create_dev($win, $dev);

    }  
  } else {
    # Need to create a new device
    # New device
    $dev = $self->newdev($win);
    # Now set it in the object
    $self->dev($win, $dev);

    # and launch it..
    # We do not trap the error...
    $status = $self->create_dev($win, $dev);

  }

  return $self->dev($win);

}


# Null subroutine -- should be overriden as required.
# This method allows you to provide a name to the new instance
# of a display subsystem. For example, to name the GWM widget used
# ky KAPVIEW. Not all subclasses use this.

sub newdev {
  return;
}


=back

=head1 SEE ALSO

L<ORAC::Display::GAIA>, L<ORAC::Display::KAPVIEW>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
