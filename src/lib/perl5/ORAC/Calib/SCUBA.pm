package ORAC::Calib::SCUBA;

=head1 NAME

ORAC::Calib::SCUBA - SCUBA calibration object

=head1 SYNOPSIS

  use ORAC::Calib::SCUBA;

  $Cal = new ORAC::Calib::SCUBA;

  $dark = $Cal->gain($filter);


=head1 DESCRIPTION

This module returns (and can be used to set) calibration information
for SCUBA.

=cut


# Calibration object for the ORAC pipeline

use strict;
use Carp;
use vars qw/$VERSION %DEFAULT_GAINS/;

# Derive from standard Calib class (even though nothing in common
# for now)
use ORAC::Calib::SCUBA;


$VERSION = undef; # -w protection
$VERSION = '0.10';

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Calib::SCUBA::ISA = qw/ORAC::Calib/;
 
# Define default SCUBA gains

%DEFAULT_GAINS = (
		  '2000' => 775,
		  '1350' => 130,
		  '1100' => 1,
		  '850'  => 240,
		  '750'  => 310,
		  '450'  => 800,
		  '350'  => 1200
		 );




# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=over 4

=item new

Create a new instance of a ORAC::Calib::SCUBA object.
The object identifier is returned.

  $Cal = new ORAC::Calib::SCUBA;

=cut

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
  $obj->{Gains} = \%DEFAULT_GAINS;

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}


# Methods to access the data

=item gains

Method to store and retrieve the reference to a hash containing the
gain information. The hash should be indexed by SCUBA filter.
Currently there is no difference between observation modes.

  $Cal->gains(\%hdr);
  $hashref = $Cal->gains;

=cut

sub gains {

  my $self = shift;
 
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Gains} = $arg;
  }
 
 
  return $self->{Gains};
}

=item gain

Allow a single gain to be retrieved for a specific filter.

  $gain = $Cal->gain("850");
  
Can also be used to set a value

  $Cal->gain("850", number);

=cut

sub gain {

  my $self = shift;
 
  my $keyword = shift;
 
  if (@_) { ${$self->gains}{$keyword} = shift; }
 
  return ${$self->gains}{$keyword};

}


=back

=head1 SEE ALSO

L<ORAC::Calib> 

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut
 
1;
