package ORAC::Calib::IRCAM;

=head1 NAME

ORAC::Calib::IRCAM;

=head1 SYNOPSIS

  use ORAC::Calib::IRCAM;

  $Cal = new ORAC::Calib::IRCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying IRCAM-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use ORAC::Calib;			# use base class

@ORAC::Calib::IRCAM::ISA = qw/ORAC::Calib/; # set up inheritance

# standard error module and turn on strict
use Carp;
use strict;


=item rotation

Return (or set) the name of the rotation transformation matrix

  $rotation = $Cal->rotation;

For IRCAM this is set to $ORAC_DATA_CAL/ircam3_rotate2eq by default

=cut


sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }

  unless (defined $self->{Rotation}) {
    $self->{Rotation} = $ENV{ORAC_DATA_CAL}."/ircam3_rotate2eq";
  };


  return $self->{Rotation}; 
};

=item mask

Return (or set) the name of the rotation transformation matrix

  $mask = $Cal->mask;

For IRCAM this is set to $ORAC_DATA_CAL/bpm by default

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }

  unless (defined $self->{Mask}) {
    $self->{Mask} = $ENV{ORAC_DATA_CAL}."/bpm";
  };


  return $self->{Mask}; 
};
