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
use vars qw/$VERSION %DEFAULT_GAINS %PHOTFLUXES/;

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

# Should probably put calibrator flux information in a different
# file

# Need to store fluxes for each filter
# Use Jy
# Note that the 350/750 fluxes are MADE UP NUMBERS using
# extrapolation from 450/850


%PHOTFLUXES = (
	       'IRC+10216' => {
			       '850' => 6.12,
			       '750' => 7.11,
			       '450' => 13.1,
			       '350' => 17.7,
			      },
	       'HL Tau' => {
			   '850' => 2.32,
			   '450' => 10.4,
			  },
	       'CRL618' => {
			    '850' => 4.57,
			    '450' => 11.9,
			   },
	       'CRL2688' => {
			     '850' => 5.88,
			     '450' => 24.8,
			    },
	       '16293-2422' => {
				'850' => 16.3,
				'450' => 78.1,
			       }
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


=item iscalsource

Given the source name and filter, work out whether we have calibration
information on this source (ie we know the flux for this filter). If
information is availble return true (1) else return (0).

  $yesno = $Cal->iscalsource("source_name","filter");

=cut

# Can not yet handle planets or differing observing modes.

sub iscalsource {
  my $self = shift;
  my $source = uc(shift);
  my $filter = shift;

  # Start off being pessimistic
  my $iscal = 0;
  if (exists $PHOTFLUXES{$source}) {
    # Source exists in calibrator list

    if (exists $PHOTFLUXES{$source}{$filter}) {
      $iscal = 1;
    }

  }

  return $iscal;

}

=item fluxcal

Return the flux of a calibrator source

  $flux = $Cal->fluxcal("sourcename", "filter");

Can not currently handle planets.

=cut

sub fluxcal {

  my $self = shift;
  my $source = uc(shift);
  my $filter = shift;

  # Start off being pessimistic
  my $flux = undef;

  if (exists $PHOTFLUXES{$source}) {
    # Source exists in calibrator list

    if (exists $PHOTFLUXES{$source}{$filter}) {
      $flux = $PHOTFLUXES{$source}{$filter};
    }

  }

  return $flux;


}


=back

=head1 SEE ALSO

L<ORAC::Calib> 

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut
 
1;
