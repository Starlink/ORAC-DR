package ORAC::Calib;

=head1 NAME

ORAC::Calib - base class for selecting calibration frames in ORACDR

=head1 SYNOPSIS

  use ORAC::Calib;

  $Cal = new ORAC::Calib;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Calib
objects. This class should be used for selecting calibration frames.

Unless specified otherwise, a calibration frame is selected by first,
the nearest reduced frame; second, explicit specification via the
-calib command line option (handled by the pipeline); third, by search
of the appropriate index file.

Note this version: Index files not implemented

=cut


# Calibration object for the ORAC pipeline

use strict;
use Carp;
use vars qw/$VERSION/;


$VERSION = undef; # -w protection
$VERSION = '0.10';




# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Obs = new ORAC::Calib;

=cut

# NEW - create new instance of Calib

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};  # Anon hash reference

  $obj->{Bias} = undef;
  $obj->{Dark} = undef;
  $obj->{Flat} = undef;
  $obj->{Arc} = undef;
  $obj->{Standard} = undef;

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}


# Methods to access the data

=item dark

Return (or set) the name of the current dark.

  $dark = $Cal->dark;


=cut

sub dark {
  my $self = shift;
  if (@_) { $self->{Dark} = shift; }
  return $self->{Dark};
}

=item bias

Return (or set) the name of the current bias.

  $bias = $Cal->bias;

=cut


sub bias {
  my $self = shift;
  if (@_) { $self->{Bias} = shift; }
  return $self->{Bias};
}

=item flat

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

=cut


sub flat {
  my $self = shift;
  if (@_) { $self->{Flat} = shift; }
  return $self->{Flat};
}


=item arc

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

=cut

sub arc {
  my $self = shift;
  if (@_) { $self->{Arc} = shift; }
  return $self->{Arc};
}

=item standard

Return (or set) the name of the current standard.

  $standard = $Cal->standard;

=cut


sub standard {
  my $self = shift;
  if (@_) { $self->{Standard} = shift; }
  return $self->{Standard};
}

=back

=head1 SEE ALSO

L<ORAC::Group> and
L<ORAC::Frame> 

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu) and 
Frossie Economou (frossie@jach.hawaii.edu)


=cut
 
1;
