package ORAC::Calib::CGS4;

=head1 NAME

ORAC::Calib::CGS4;

=head1 SYNOPSIS

  use ORAC::Calib::CGS4;

  $Cal = new ORAC::Calib::CGS4;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying CGS4-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use ORAC::Calib;			# use base class

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);
# @ORAC::Calib::CGS4::ISA = qw/ORAC::Calib/; # set up inheritance

# standard error module and turn on strict
use Carp;
use strict;



=item B<mask>

Return (or set) the name of the rotation transformation matrix

  $mask = $Cal->mask;

For CGS4 this is set to $ORAC_DATA_CAL/bpm by default

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }

  unless (defined $self->{Mask}) {
    $self->{Mask} = $ENV{ORAC_DATA_CAL}."/fpa46_long";
  };


  return $self->{Mask}; 
};

=item B<flat>


=cut


sub flat {
  my $self = shift;
  if (@_) { $self->{Flat} = shift; }

  unless (defined $self->{Flat}) {
    $self->{Flat} = "flat26";
  };


  return $self->{Flat}; 
};





=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)

=cut


1;
