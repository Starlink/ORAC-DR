package ORAC::Calib;

# Calibration object for the ORAC pipeline

use strict;
use Carp;
use vars qw/$VERSION/;

# Need to read the header from the file
use NDF;


$VERSION = undef; # -w protection
$VERSION = '0.10';




# Setup the object structure


# NEW - create new instance of Calib

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};  # Anon hash

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

sub dark {
  my $self = shift;
  if (@_) { $self->{Dark} = shift; }
  return $self->{Dark};
}

sub bias {
  my $self = shift;
  if (@_) { $self->{Bias} = shift; }
  return $self->{Bias};
}

sub flat {
  my $self = shift;
  if (@_) { $self->{Flat} = shift; }
  return $self->{Flat};
}

sub arc {
  my $self = shift;
  if (@_) { $self->{Arc} = shift; }
  return $self->{Arc};
}

sub standard {
  my $self = shift;
  if (@_) { $self->{Standard} = shift; }
  return $self->{Standard};
}

