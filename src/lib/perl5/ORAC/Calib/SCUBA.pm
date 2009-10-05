package ORAC::Calib::SCUBA;

=head1 NAME

ORAC::Calib::SCUBA - SCUBA calibration object

=head1 SYNOPSIS

  use ORAC::Calib::SCUBA;

  $Cal = new ORAC::Calib::SCUBA;

  $gain = $Cal->gain($filter);
  $tau  = $Cal->tau($filter);
  @badbols = $Cal->badbols;

=head1 DESCRIPTION

This module returns (and can be used to set) calibration information
for SCUBA. SCUBA calibrations are used for extinction correction
(the sky opacity) and conversion of volts to Janskys.

It can also be used to set and retrieve lists of bad bolometers generated
by noise observations.

This class does inherit from B<ORAC::Calib> although nearly all the
methods in the base class are irrelevant to SCUBA (this class only
uses the thing() method).

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION $DEBUG /;

use Cwd;          # Directory change

use ORAC::Index;  # Use index file
use ORAC::Print;  # Standardised printing

# External modules

use File::Spec;

$VERSION = '1.0';

# Let the object know that it is derived from ORAC::Frame;
use base qw/ORAC::Calib::JCMTCont/;

$DEBUG = 0; # Turn off debugging mode

# Define default SCUBA gains

# FCF can vary with time. Index by filter and then ARCSEC/BEAM
# UT date is used for START and END. If none there then assume open
# ended. If only START assume currently applicable
# The arrays are populated in order
# START and END are inclusive

my %FCFS = ('2000' => [
		    {
		     BEAM => 650, # No date
		    },
		   ],
	 '1350' => [
		    {
		     BEAM => 130, # No date
		    },
		   ],
	 '750'  => [
		    {
		     BEAM => 310, # No date
		    },
		   ],
	 '350'  => [
		    {
		     BEAM => 1200, # No date
		    },
		   ],
	 '200'  => [
		    {
		      BEAM => 1, # No date. Made up number
		    },
		   ],
	 '850N' => [ # Asumed to be in date order
		    {
		     START => 19960101, # Beginning of SCUBA history
		     END   => 19970825,
		     ARCSEC=> 1.00, # +/- 0.06 Uranus
		     BEAM  => 249.0,
		    },
		    {
		     START => 19970826,
		     END   => 19971102,
		     ARCSEC=> 1.11, # +/- 0.08 Mars/Uranus
		     BEAM  => 280.0,
		    },
		    {
		     START => 19971103,
		     END   => 19980305,
		     ARCSEC=> 1.02, # +/- 0.06 Mars/Uranus
		     BEAM  => 258.0,
		    },
		    {
		     START => 19980306,
		     END   => 19980428,
		     ARCSEC=> 0.93, # +/- 0.04 Mars/Uranus
		     BEAM  => 235.0,
		    },
		    {
		     START => 19980429,
		     END   => 19980825,
		     ARCSEC=> 1.02, # +/- 0.05 Mars/Uranus
		     BEAM  => 257.0,
		    },
		    {
		     START => 19980826,
		     END   => 19991123,
		     ARCSEC=> 0.96, # +/- 0.06 Mars/Uranus
		     BEAM  => 242.0,
		    },
		   ],
	 '850W' => [ # Asumed to be in date order
		    {
		     START => 19990901, # Filter installed
		     END   => 20000630,
		     ARCSEC=> 0.83,  # +/- 0.03 Mars/Uranus
		     BEAM  => 205.0,
		    },
		    {
		     START => 20000630,
		     END   => 20010515,
		     ARCSEC=> 0.87, # +/- 0.05 Uranus
		     BEAM  => 214.0,
		    },
		    {
		     START => 20010516, # Strange increase in FCF
		     END => 20010601,
		     ARCSEC=> 1.13,
		     BEAM  => 280.0,
		    },
		    {
		     START => 20010602,
		     END   => 20020630,
		     ARCSEC=> 0.88, # +/- 0.06 Mars/Uranus
		     BEAM  => 220.0,
		    },
		    {
		     START => 20020701,
		     END   => 20021201,
		     ARCSEC=> 1.06, # +/- 0.13
		     BEAM  => 270.0,
		    },
		    {
		     START => 20021202,
		     END   => 20030131,
		     ARCSEC => 0.82, # +/- 0.07 (Mars and Uranus differ slightly)
		     BEAM => 201,
		    },
		    {
		     START => 20030201,
		     END   => 20030209,
		     ARCSEC=> 0.86, # +/- 0.02 Mars
		     BEAM  => 197, # large error bars +/- 14
		    },
		    {
		     START => 20030210,
		     END   => 20030407,
		     ARCSEC=> 1.01,     # +/- 0.05 Mars
		     BEAM  => 253.0,
		    },
		    {
		     START => 20030408,
		     END   => 20030801,
		     ARCSEC=> 0.89, # +/- 0.04 Mars/Uranus
		     BEAM  => 228,
		    },
		    {
		     START => 20030802,
		     END   => 20031101,,
		     ARCSEC=> 0.81,  # +/- 0.04 Mars/Uranus
		     BEAM  => 201,
		    },
		    {
		     START => 20031102,
		     END   => 20040601,
		     ARCSEC=> 0.88, # +/- 0.06 Mars/Uranus
		     BEAM  => 228,
		    },
		    {
		     START => 20040602,
		     END   => 20040901,
		     ARCSEC=> 0.87, # +/- 0.03
		     BEAM  => 224,
		    },
		    {
		     START => 20040902,
		     END   => 20050124,
                     # Compromise from 0.91 from Mars and 1.00 from Uranus
                     # CRL618 also seems to favour 0.92. Go with 0.95 to split
                     # difference but with additional 5% to errors.
		     ARCSEC=> 0.95, # 0.91 +/- 0.05 Mars only. Uranus 1.00+/- 0.05
		     BEAM  => 234,
		    },
		    {
		     START => 20050125,
		     END   => 20050125,
		     ARCSEC=> 0.80, # +/- 0.02 Mars (no uranus)
		     BEAM  => 200,
		    },
		    {
		     START => 20050126,
		     ARCSEC=> 0.93, # +/- 0.04 Mars / Uranus
		     BEAM  => 233,
		    },
		   ],
	 '450N' => [
		    {
		     ARCSEC => 6.9,
		     BEAM   => 855,
		    },
		   ],
	 '450W' => [
		    {
		     END => 20003031,
		     ARCSEC => 3.2,
		     BEAM  => 340,
		    },
		    {
		     START => 20010101,
		     END => 20020601,
		     ARCSEC => 2.78,
		     BEAM   => 260,
		    },
		    {
		     START => 20020602,
		     END => 20021201,
		     ARCSEC => 4.13,
		     BEAM => 497,
		    },
		    {
		     START => 20021202,
		     END => 20021231,
		     ARCSEC => 2.73,
		     BEAM => 306,
		    },
		    {
		     START => 20030101,
		     END => 20030209,
		     ARCSEC => 2.45,
		     BEAM => 262,
		    },
		    {
		     START => 20030210,
		     END   => 20030228,
		     ARCSEC => 3.3,
		     BEAM => 400,
		    },
		    {
		     START  => 20030301,
		     END    => 20030407,
		     ARCSEC => 2.85,
		     BEAM => 330,
		    },
		    {
		     START  => 20030408,
		     END    => 20030517,
		     ARCSEC => 2.24,
		     BEAM => 270,
		    },
		    {
		     START  => 20030518,
		     END    => 20030630,
		     ARCSEC => 2.76,
		     BEAM => 302,
		    },
		    {
		     START  => 20030701,
		     END    => 20030726,
		     ARCSEC => 2.61,
		     BEAM => 284,
		    },
		    {
		     START  => 20030727,
		     END    => 20030822,
		     ARCSEC => 2.33,
		     BEAM => 245,
		    },
		    {
		     START  => 20030823,
		     END    => 20031019,
		     ARCSEC => 2.72,
		     BEAM => 316,
		    },
		    {
		     START  => 20031020,
		     END    => 20031231,
		     ARCSEC => 3.2,
		     BEAM => 379,
		    },
		    {
		     START  => 20040101,
		     END    => 20040212,
		     ARCSEC => 3.1,
		     BEAM => 414,
		    },
		    {
		     START  => 20040213,
		     END    => 20040404,
		     ARCSEC => 3.6,
		     BEAM => 528,
		    },
		    {
		     START  => 20040405, # SCUBA shutdown
		     ARCSEC => 2.72,
		     BEAM => 316,
		    },
		   ],
	);


# Treat 450 and 850 the same as 850N and 450N
$FCFS{'450'} = $FCFS{'450N'};
$FCFS{'850'} = $FCFS{'850N'};


# Should probably put calibrator flux information in a different
# file

# Need to store fluxes for each filter
# Use Jy
# Note that the 350/750 fluxes are MADE UP NUMBERS using
# extrapolation from 450/850


my %PHOTFLUXES = (
#	       'IRC+10216' => {
#			       '850' => 6.12,
#			       '750' => 7.11,
#			       '450' => 13.1,
#			       '350' => 17.7,
#			      },
	       'HLTAU' => {
			   '850' => 2.32,
			   '450' => 10.4,
			   '850W' => 2.32,
			   '450W' => 10.4,
			   '850N' => 2.32,
			   '450N' => 10.4,
			  },
	       'CRL618' => {
			    '850' => 4.57,
			    '450' => 11.9,
			    '850W' => 4.57,
			    '450W' => 11.9,
			    '850N' => 4.57,
			    '450N' => 11.9,
			   },
	       'CRL2688' => {
			     '850' => 5.88,
			     '450' => 24.8,
			     '850W' => 5.88,
			     '450W' => 24.8,
			     '850N' => 5.88,
			     '450N' => 24.8,
			    },
	       '16293-2422' => {
				'850' => 16.3,
				'450' => 78.1,
				'850W' => 16.3,
				'450W' => 78.1,
				'850N' => 16.3,
				'450N' => 78.1,
			       },
	       'OH231.8' => {
			     '850' => 2.52,
			     '450' => 10.53,
			     '850W' => 2.52,
			     '450W' => 10.53,
			     '850N' => 2.52,
			     '450N' => 10.53,
			    }
	      );


# Setup the object structure
__PACKAGE__->CreateBasicAccessors( badbols => {},
);

=head1 PUBLIC METHODS

The following methods are available in this class.
These are in addition to the methods inherited from B<ORAC::Calib>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Calib::SCUBA object.
The object identifier is returned.

  $Cal = new ORAC::Calib::SCUBA;

=cut

# NEW - create new instance of Calib

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new( @_ );
  # Specify default tausys
  $obj->tausys( "850SKYDIP" );

  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=item B<default_fcfs>

Return the default FCF lookup table indexed by filte.

 %FCFS = $cal->default_fcfs();

=cut

sub default_fcfs {
  return %FCFS;
}

=item B<secondary_calibrator_fluxes>

Return the lookup table of fluxes for secondary calibrators.

 %photfluxes = $cal->secondary_calibrator_fluxes();

=cut

sub secondary_calibrator_fluxes {
  return %PHOTFLUXES;
}

=item B<badbols>

Set or retrieve the name of the system to be used for bad bolometer
determination. Allowed values are:

=over 8

=item * index

Use an index file generated by noise observations
using the reflector blade. The bolometers stored in this
file are those that were above the noise threshold in 
the _REDUCE_NOISE_ primitive. The index file is generated
by the _REDUCE_NOISE_ primitive

=item * file

Uses the contents of the file F<badbol.lis> (contains a space
separated list of bolometer names in the first line). This
file is in ORAC_DATA_OUT. If the file is not found, no
bolometers will be flagged.

=item * 'list'

A colon-separated list of bolometer names can be supplied.
If badbols=h7:i12:g4,... then this list will be used
as the bad bolometers throughout the reduction.

=back

Default is to use the 'file' method.
The value is always upper-cased.

=cut

sub badbols {
  my $self = shift;
  # Use the automatically created method
  my $bb = $self->badbolscache(@_);
  return (defined $bb ? $bb : "FILE" );
}

=back

=head2 General methods

=over 4

=item B<badbol_list>

Returns list of bolometer names that should be turned off for the
current observation. The source of this list depends on the setting
of the badbols() parameter (controlled by the user).
Can be one of 'index', 'file' or actual bolometer list. See the
badbols() method documentation for more information.

=cut

sub badbol_list {
  my $self = shift;

  # Retrieve the badbols query system
  my $sys = $self->badbols;

  # Array to store the bad bolometers
  my @badbols = ();

  # Check system
  if ($sys eq 'INDEX') {
    # Look for bolometers in index file

    # look in the index file
    # and retrieve the closest in time that agrees with the rules
    my $best = $self->badbolsindex->choosebydt('ORACTIME', $self->thing,0);

    # Now retrieve the entry
    if (defined $best) {
      my $entref = $self->badbolsindex->indexentry($best);
      if (defined $entref) {
	my $list = $entref->{BADBOLS};
	@badbols = split(",",$list);
      } else {
	orac_err("Error reading entry $best from BadBols index");
      }
    }


  } elsif ($sys eq 'FILE') {
    # Look for bolometers in badbol.lis file
    my $file = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "badbol.lis");
    if (-e $file) {
      my $fh = new IO::File("< $file");

      if (defined $fh) {
	# read first line
	my $list = <$fh>;
	# close the file
	close $fh;
	# Split on spaces
	@badbols = split(/\s+/,$list);
      }

    }

  } else {
    # Look for bolometers in $sys itself
    # Split on colons - for now do not check whether the names
    # are sensible. If we were to do that we should do the check
    # outside this 'if' and before we return the list
    # Currently this check is done in the primitive at the same time
    # as the bolometer list is compared to the valid bolometers
    # stored in the Frame itself

    @badbols = split(/:/,$sys);

  }

  # Return the list
  return @badbols;

}

=head1 SEE ALSO

L<ORAC::Calib::JCMTCont>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
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
