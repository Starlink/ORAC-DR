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
use vars qw/$VERSION %DEFAULT_FCFS %PHOTFLUXES @PLANETS $DEBUG %FCFS/;

use Cwd;          # Directory change

# Derive from standard Calib class (even though nothing in common
# for now)
use ORAC::Calib;  # We are a Calib class
use ORAC::Index;  # Use index file
use ORAC::Print;  # Standardised printing
use ORAC::Constants; # ORAC__OK
use ORAC::Msg::EngineLaunch; # To launch fluxes monolith

# External modules

use JCMT::Tau;         # Tau conversion
use JCMT::Tau::CsoFit; # Fits to CSO data

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Calib::SCUBA::ISA = qw/ORAC::Calib/;
use base qw/ORAC::Calib/;

$DEBUG = 0; # Turn off debugging mode

# Define default SCUBA gains
# These vary with a number of things including filter, and observing
# mode. Map calibration can also be done using Jy/arcsec2 or Jy/beam.
# Additionally there is the possibility of time dependent changes
# due to improvements in throughput (not necessarily a change in filter)

# These are currently photometry Jy/beam/V FCFs

%DEFAULT_FCFS = (
		 BEAM => {
			  '2000' => 650,
			  '1350' => 130,
			  '1100' => 1,  # This filter has never worked
			  '850'  => 240,
			  '750'  => 310,
			  '450'  => 800,
			  '350'  => 1200,
			  '850N' => 240,
			  '450N' => 800,
			  '850W' => 197,
			  '450W' => 384,
			 },
		 ARCSEC => {
			    '450W' => 3.16,
			    '450N' => 6.89,
			    '850W' => 0.84,
			    '850N' => 1.00,
			   }
		);


# FCF can vary with time. Index by filter and then ARCSEC/BEAM
# UT date is used for START and END. If none there then assume open
# ended. If only START assume currently applicable
# The arrays are populated in order
# START and END are inclusive

%FCFS = ('2000' => [
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
	 '850N' => [ # Asumed to be in date order
		    {
		     START => 19960101, # Beginning of SCUBA history
		     END   => 19980215,
		     ARCSEC=> 1.07,
		     BEAM  => 266.0,
		    },
		    {
		     START => 19960101, # Beginning of SCUBA history
		     ARCSEC=> 0.98,
		     BEAM  => 248.0,
		    },
		   ],
	 '850W' => [ # Asumed to be in date order
		    {
		     START => 19990901, # Filter installed
		     END   => 20000630,
		     ARCSEC=> 0.84,
		     BEAM  => 207.0,
		    },
		    {
		     START => 20000630, # Beginning of SCUBA history
		     END   => 20010515,
		     ARCSEC=> 0.88,
		     BEAM  => 216.0,
		    },
		    {
		     START => 20010516, # Strange increase in FCF
		     END => 20010601,
		     ARCSEC=> 1.13,
		     BEAM  => 280.0,
		    },
		    {
		     START => 20010602,
		     END   => 20020204,
		     ARCSEC=> 0.86,
		     BEAM  => 209.0,
		    },
		    {
		     START => 20020205,
		     END   => 20020630,
		     ARCSEC=> 0.88,
		     BEAM  => 224.0,
		    },
		    {
		     START => 20020701,
		     END   => 20021201,
		     ARCSEC=> 1.09,
		     BEAM  => 278.0,
		    },
		    {
		     START => 20021202,
		     END   => 20021231,
		     ARCSEC => 0.79,
		     BEAM => 194,
		    },
		    {
		     START => 20030101,
		     END   => 20030131,
		     ARCSEC=> 0.80,
		     BEAM  => 193,
		    },
		    {
		     START => 20030201,
		     END   => 20030209,
		     ARCSEC=> 0.89,
		     BEAM  => 204, # large error bars +/- 14
		    },
		    {
		     START => 20030210,
		     END   => 20030228,
		     ARCSEC=> 1.02,
		     BEAM  => 255.0,
		    },
		    {
		     START => 20030301,
		     END   => 20030407,
		     ARCSEC=> 0.98,
		     BEAM  => 230,
		    },
		    {
		     START => 20030508,
		     END   => 20030517,
		     ARCSEC=> 0.83,
		     BEAM  => 213,
		    },
		    {
		     START => 20030518,
		     END   => 20030630,
		     ARCSEC=> 0.87,
		     BEAM  => 212,
		    },
		    {
		     START => 20030701,
		     END   => 20030726,
		     ARCSEC=> 0.83,
		     BEAM  => 206,
		    },
		    {
		     START => 20030727,
		     END   => 20030822,
		     ARCSEC=> 0.86,
		     BEAM  => 218,
		    },
		    {
		     START => 20030823,
		     END   => 20030916,
		     ARCSEC=> 0.79,
		     BEAM  => 196,
		    },
		    {
		     START => 20030917, # Open ended
		     ARCSEC=> 0.81,
		     BEAM  => 203,
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
		     ARCSEC => 2.77,
		     BEAM => 286,
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


%PHOTFLUXES = (
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


# The planets that we can retrieve fluxes for
@PLANETS = qw/ MARS JUPITER SATURN URANUS NEPTUNE /;


# Setup the object structure

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

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {
	     BadBols => undef,       # Bad bolometers
	     BadBolsNoUpdate => 0,
             EngineLaunch => new ORAC::Msg::EngineLaunch,
	     Gains => undef,         # Gains (flux conversion factors)
	     GainsIndex => undef,
	     GainsNoUpdate => 0,
	     SkydipIndex => undef,
	     TauSys => undef,        # Tau system
	     TauSysNoUpdate => 0,
             TauCache => {},         # Cache for tau result
	     Thing => {},            # Header of current frame
	     CsoFit => undef,        # Polynomial tau fits
	    };

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

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
  if (@_) { $self->{BadBols} = uc(shift) unless $self->badbolsnoupdate; }
  $self->{BadBols} = 'FILE' unless (defined $self->{BadBols});
  return $self->{BadBols};
}

=item B<badbolsindex>

Return (or set) the index object associated with the bad bolometers
index file. This index file is used if badbols() is set to index.

=cut

sub badbolsindex {

  my $self = shift;
  if (@_) { $self->{BadBolsIndex} = shift; }

  unless (defined $self->{BadBolsIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.badbols";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.badbols";
    $self->{BadBolsIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{BadBolsIndex};
}


=item B<badbolsnoupdate>

Flag to prevent the badbols system from being modified during data
processing.

=cut

sub badbolsnoupdate {
  my $self = shift;
  if (@_) { $self->{BadBolsNoUpdate} = shift };
  return $self->{BadBolsNoUpdate};
}

=item B<engine_launch_object>

Returns the C<ORAC::Msg::EngineLaunch> object that can be used
to initialise message systems as required by the particular
algorithm engines.

 $engobj = $self->engine_launch_object;

=cut

sub engine_launch_object {
  my $self = shift;
  return $self->{EngineLaunch};
}


=item B<fluxes_mon>

Retrieves the algorithm engine object associated with
the Starlink fluxes monolith.

A new object is created if the value is undefined.

Relies on the Adam messaging system being available.
ADAM messaging will be initialised if not present.

=cut

sub fluxes_mon {
  my $self = shift;
  my $status;

  my $obj = $self->engine_launch_object->engine('fluxes');

  if (defined $obj) {
    return $obj;
  } else {
    croak 'Error launching fluxes monolith. Aborting.';
  }

}


=item B<gains>

Determines whether gains are derived from the default values
(DEFAULT) or from the index files (INDEX). Default is to
use the default gains. The value is upper-cased.

=cut

sub gains {
  my $self = shift;
  if (@_) { $self->{Gains} = uc(shift) unless $self->gainsnoupdate; }
  $self->{Gains} = 'DEFAULT' unless (defined $self->{Gains});
  return $self->{Gains};
}

=item B<gainsindex>

Return (or set) the index object associated with the gains
index file. This index file is used if gains() is set to INDEX.

=cut

sub gainsindex {

  my $self = shift;
  if (@_) { $self->{GainsIndex} = shift; }

  unless (defined $self->{GainsIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.gains";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.gains";
    $self->{GainsIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{GainsIndex};
}

=item B<gainsnoupdate>

Flag to prevent the gains selection from being modified during data
processing.

=cut

sub gainsnoupdate {
  my $self = shift;
  if (@_) { $self->{GainsNoUpdate} = shift };
  return $self->{GainsNoUpdate};
}


=item B<skydipindex>

Return (or set) the index object associated with the skydip
index file. This index file is used if tausys() is set to skydip.

=cut

sub skydipindex {

  my $self = shift;
  if (@_) { $self->{SkydipIndex} = shift; }

  unless (defined $self->{SkydipIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.skydip";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.skydip";
    $self->{SkydipIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{SkydipIndex};
}


=item B<tausys>

Set (or retrieve) the name of the system to be used for
tau determination. Allowed values are 'CSO', 'SKYDIP',
'850SKYDIP' or a number. Currently the number is assumed to be the 
CSO tau since this number is independent of wavelength.
'INDEX' is an allowed synonym for 'SKYDIP'. '850SKYDIP'
mode uses the results of 850 micron skydips from index
files to derive the opacity for the requested wavelength.

Additionally, modes 'DIPINTERP' and '850DIPINTERP' can be 
used to interpolate the current tau from skydips taken
either side of the current observation.

Currently there is no way to specify an actual 850 micron
tau value (the number is treated as a CSO value). In the future
this may change (or a tausys of 850=value will be used??)

If tausys has not been set it defaults to '850SKYDIP'

=cut

sub tausys {
  my $self = shift;
  if (@_) { $self->{TauSys} = uc(shift) unless $self->tausysnoupdate; }
  $self->{TauSys} = '850SKYDIP' unless (defined $self->{TauSys});
  return $self->{TauSys};
}

=item B<tausysnoupdate>

Flag to prevent the tau system from being modified during data
processing.

=cut

sub tausysnoupdate {
  my $self = shift;
  if (@_) { $self->{TauSysNoUpdate} = shift };
  return $self->{TauSysNoUpdate};
}

=item B<taucache>

Internal cache providing access to previously calculated tau values.
This is a reference to a hash of hashes with keys of uppercased
C<tausys()>, ORACTIME and filter name.

 $cacheref = $Cal->taucache;

 $tau = $Cal->taucache->{TAUSYS}->{'19980515.453'}->{$filter};

Returns a hash reference.

=cut

sub taucache {
  my $self = shift;
  return $self->{TauCache};
}

=item B<csofit>

Object containing all the tau fitting information.
The object is configured the first time the information
is requested. The fitting data are located in
C<ORAC_DATA_CAL/csofit.dat>

=cut

sub csofit {
  my $self = shift;
  if (@_) { $self->{CsoFit} = shift; }

  unless (defined $self->{CsoFit}) {
    my $file = $ENV{ORAC_DATA_CAL}."/csofit.dat";
    $self->{CsoFit} = new JCMT::Tau::CsoFit($file);
  };

  return $self->{CsoFit};
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
    my $file = "$ENV{ORAC_DATA_OUT}/badbol.lis";
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



=item B<fluxcal>

Return the flux of a calibrator source

  $flux = $Cal->fluxcal("sourcename", "filter", $ismap);

The optional third argument is used to specify whether a map
flux (ie total integrated flux) is required (true), or 
simply a flux in beam (used for photometry). Default is to
return flux in beam. This should return the same answer if the
calibrator is a point source.

Currently, all secondary calibrators are assumed to be point like.

Returns undef if the flux could not be determined.

=cut

sub fluxcal {

  my $self = shift;
  my $source = uc(shift);
  my $filter = shift;
  my $ismap = shift;

  # Fluxes requires that the filter name does not include any non
  # numbers
  $filter =~ s/\D+//g;


  # Start off being pessimistic
  my $flux = undef;

  # Check in the fluxes hash for a value
  if (exists $PHOTFLUXES{$source}) {
    # Source exists in calibrator list

    if (exists $PHOTFLUXES{$source}{$filter}) {
      $flux = $PHOTFLUXES{$source}{$filter};
    }

  } elsif ( grep(/$source/, @PLANETS) ) {
    # Else if we have a planet name

    # Construct argument string for fluxes
    my $hidden = "pos=n flu=y screen=n ofl=n msg_filter=quiet outfile=fluxes.dat apass=n now=n";

    # Now we need to know the date for fluxes (the time is pretty
    # immaterial for the flux)
    # FLUXES needs the date in DD MM YY format
    # of course SCUBA uses YYYY:MM:DD format
    my $scudate = $self->thing->{'UTDATE'}; # the thing method is the header

    if (defined $scudate) {
      my ($y,$m,$d) = split(/:/, $scudate);
      $y = substr($y,2);
      $scudate = "$d $m $y";

    } else {
      $scudate = '0 1 1';
    }

    # Get the time as well - I'm pretty sure that the flux will hardly
    # change when I change the ut time
    my $scutime = $self->thing->{'UTSTART'};

    if (defined $scutime) {
      $scutime =~ tr/:/ /; # Translate colon to space
    } else {
      $scutime = '0 0 0';
    }

    my $status = $self->fluxes_mon->obeyw("","$hidden planet=$source date='$scudate' time='$scutime' filter=$filter");

    if ($status != ORAC__OK) {
      orac_err "The FLUXES program did not run successfully\n";
      return undef;
    }

    # At this point we dont know whether we want the flux in the beam
    # or the total flux

    if (defined $ismap && $ismap) {
      ($status, $flux) = $self->fluxes_mon->get("","F_TOTAL");
    } else {
      ($status, $flux) = $self->fluxes_mon->get("","F_BEAM");
    }
    if ($status != ORAC__OK || $flux == -1) {
      orac_err "Error retrieving flux for filter $filter and planet $source\n";
      return undef;
    }

  }

  return $flux;


}



=item B<gain>

Method to return the current gain (aka 'flux conversion factor') 
for the specified filter that is usable for the current frame.

C<undef> is returned if no gain can be determined.

  $gain = $Cal->gain($filter, $units);

The units must be either BEAM (for Jy/beam/V) or ARCSEC (for
Jy/arcsec**2/V). If no units are supplied the default is BEAM.

If gains() is set to DEFAULT then this method will simply return
the current canonical gain for this filter (first trying a specific
filter [eg C<450w>] then trying a generic filter name [eg C<450>]).
This value will not take into account observing mode (eg scan map
gain is lower than jiggle map gain).

If gains() is set to INDEX the index will be searched for a calibration
observation that matches the observation mode (ie Chop throw, sample
mode, observing mode agree). 

The current index system refuses to continue if a calibration can
not be found. In future this may well be changed so that the
DEFAULT values are used if no calibration is available.

It may also be useful if the gains either side of current observation
are retrieved so that the gain can be interpolated (as for tau
calculation).

=cut

sub gain {
  my $self = shift;

  croak 'Usage: gain(filter,[units])'
    if (scalar(@_) != 1 && scalar(@_) != 2);

  # Get the filter (this could be sub-instrument but it is probably
  # easier to use filter than to query the header for the sub name).
  my $filt = uc(shift);

  # Get the units if there
  my $units = ( @_ ? uc(shift) : 'BEAM');

  # Check units
  if ($units ne 'BEAM' && $units ne 'ARCSEC') {
    croak "Units must be BEAM or ARCSEC, not '$units'\n";
  }

  # Query the gain system to use
  my $sys = $self->gains;

  my $gain;

  if ($sys eq 'DEFAULT') {

    # Generate the generic filter name from the specific (eg 450w)
    # filter name in case one has not been specified.
    my $generic;
    ($generic = $filt ) =~ s/\D+$//;

    $gain = $self->_get_default_fcf( $filt, $units, $self->thing->{ORACUT});

    orac_err "No gain exists for the specified filter ($filt)\n"
      unless defined $gain;

  } elsif ($sys eq 'INDEX') {

    # Now look in the index file

    # We are going to modify the header so take a copy
    my %hdr = %{ $self->thing };

    # Set search parameters
    $hdr{FILTER} = $filt;
    $hdr{UNITS}  = $units;

    # Now ask for the 'best' gain observation
    # This means closest in time
    my $best = $self->gainsindex->choosebydt('ORACTIME', \%hdr, 0);

    unless (defined $best) {
      orac_err "No suitable gain calibration could be found for filter $filt ($units)\n";
      croak 'Aborting...';
    }

    # Now retrieve the entry itself
    my $entref = $self->gainsindex->indexentry($best);

    if (defined $entref) {
      $gain = $entref->{GAIN};
    } else {
      orac_err("Error reading entry $best from Gains index");
      $gain = undef;
    }

  } else {
    orac_err("Gains system non standard ($sys)\n");
    $gain = undef;
  }

  # Return the gain
  return $gain;

}


=item B<iscalsource>

Given the source name and filter, work out whether we have calibration
information on this source (ie we know the flux for this filter). If
information is availble return true (1) else return (0).

  $yesno = $Cal->iscalsource("source_name","filter");

If filter is not supplied, it is assumed we are simply asking
whether the source is a calibrator independent of whether we
actually have a calibration value for it....

=cut

# Can not yet handle planets or differing observing modes.

sub iscalsource {
  my $self = shift;
  my $source = uc(shift);
  my $filter;
  $filter = uc(shift) if @_;

  # If we match a planet straightaway then it is a calibrator
  # regardless of filter (unless the filter is not available in fluxes)

  return 1 if grep /$source/, @PLANETS;


  # Start off being pessimistic
  my $iscal = 0;
  if (exists $PHOTFLUXES{$source}) {
    # Source exists in calibrator list

    # If filter is defined check that it is in the list
    # if it is not defined simply return true
    if (!defined($filter) || exists $PHOTFLUXES{$source}{$filter}) {
      $iscal = 1;
    }

  }

  return $iscal;

}


=item B<tau>

Returns the tau associated with the supplied filter.

  $tau = $Cal->tau($filter);

This routine works as follows. First tausys() is queried to determine
the system to use to calculate the tau. If this is CSO, the current
frame is queried for the CSO tau value stored and the tau calculated
for FILTER. If tausys() returns a number it is assumed
to be the actual CSO tau to use. If it is set to Skydip (or index) then
the selected wavelength is updated in the frame header (Key=FILTER)
and the skydip index is queried for the skydip that matched the criterion
and is closest in time.

The tausys='850SKYDIP' mode uses the results of 850 micron skydips
from index files to derive the opacity for the requested wavelength.

Additionally, modes 'DIPINTERP' and '850DIPINTERP' can be used to
interpolate the current tau from skydips taken either side of the
current observation.

The skydip modes will default to using CSO if a suitable
skydip can not be found. Also, a warning is raised if a skydip
is found but was takan more than 3 hours before or after the
current observation.

undef is returned if an error occurred [eg the CSO is so high that the
tau can not be calculated using the linear relationship].

The value is cached for a given tausys and observation (ORACTIME is
used for uniqueness) to prevent delays in searching for a tau when the
observation has not changed. It is very unlikely that a tau calibration
will change during a data reduction of a single frame (and, in reality
it is required that if you use a particular tau for extinction correction
that you can retrieve the exact same tau that was used at a later date).
The tau value is not cached if it can not be determined.

=cut

sub tau {
  my $self = shift;

  croak 'Usage: tau(filter)' if (scalar(@_) != 1);

  # Get the filter name for this sub-instrument
  my $filt = uc(shift);

  # Declare local variables
  my ($tau, $status);

  # Now query tausys
  my $sys = $self->tausys;

  # Check to see whether the value is already cached.
  my $oractime = $self->thing->{'ORACTIME'};
  return $self->taucache->{$sys}->{$oractime}->{$filt}
    if exists $self->taucache->{$sys}->{$oractime}->{$filt};

  # Check tausys
  if ($sys eq 'CSO') {

    # Read the value from the header of thing
    my $csotau = $self->thing->{'TAU_225'};

    ($tau, $status) = get_tau($filt, 'CSO', $csotau);

    if ($status == -1) {
      orac_warn("Error converting a CSO tau of $csotau to an opacity for filter $filt\n");
      orac_warn("Setting tau to 0\n");
      $tau = 0.0;
    }


  } elsif ($sys =~ /^\d+\.?\d*$/) {
    # We check for a number - note that this pattern does not match
    # numbers that start with a decimal point.
    # This number is a specific CSO tau
    ($tau, $status) = get_tau($filt, 'CSO', $sys);

    # Check status
    if ($status == -1) {
      orac_warn("Error converting a CSO tau of $sys to an opacity for filter $filt\n");
      orac_warn("Setting tau to 0\n");
      $tau = 0.0;
    }

  } elsif ($sys =~ /DIP/ || $sys eq 'INDEX') { # Skydips

    # Skydips have been selected (using index files)

    # We always have to ask for the nearest skydip from the index
    # file. If one is not available, revert to CSO tau
    # If sys=850SKYDIP we derive the tau from nearest 850 skydip

    # First tak a copy of the header (we will need to change
    # this when looking for 850 skydips
    my %hdr = %{$self->thing};

    # Now set the filter name in this hash so that
    # we know what filter we are searching for
    # Special case for a 850 skydip only search
    # but we don't know whether we should be searching for 850W
    # or 850N. To overcome this we run once for 850W and again for 850N
    # unless the current filter is already 850 microns
    if ($filt =~ /850/) {
      $hdr{FILTER} = $filt;

      # Search for the requested filter
      $tau = $self->_search_skydip_index($sys, \%hdr);

    } elsif ($sys =~ /^850/) { # scale from 850 filter

      # Need to loop over all 850 filters until we find one that
      # returns a match. In principal, we should search for all filters
      # and then determine the closest (either by using a clever rules
      # file or by searching multiple times and storing the time 
      # difference). In practice, you very really mix 850W skydips with
      # 850N skydips within a single night.

      my $found;
      foreach my $f ( '850W', '850N' ) {
	$hdr{FILTER} = $f;

	# Search for the requested filter
	$tau = $self->_search_skydip_index($sys, \%hdr);

	# Jump out the loop if we have an answer
	if (defined $tau) {
	  $found = $f;
	  last;
	}

	orac_warn "Unable to find a valid skydip using filter $f\n";

      }

      # Now we need to translate the 850 tau to the required tau
      # One complication is that the JCMT::Tau module does not allow
      # for conversions between arbritrary filters. The solution is to
      # go through the CSO airlock but this should probably occur
      # inside get_tau rather than here.
      if (defined $tau) {

	orac_print "Using $found tau of ".sprintf("%6.3f",$tau)." to generate tau for filter $filt\n";

	# Now convert this tau to the requested filter
	# This must be changed to work for 850N as well
	($tau, $status) = get_tau($filt, $found, $tau);

	# If there is an error, try going through CSO
	if ($status == -1) {

	  (my $intermed_tau, $status) = get_tau('CSO', $found, $tau);

	  if ($status != -1) {
	    ($tau, $status) = get_tau($filt, 'CSO', $intermed_tau);

	    # On error - report conversion error then set tau to undef
	    # so that we can try to adopt a CSO value
	    if ($status == -1) {
	      orac_warn("Error converting a $found tau to an opacity for filter $filt\n");
	      $tau = undef;
	    }
	  }

	}

      }

    } else { # Just want to use the requested filter

      $hdr{FILTER} = $filt;
      $tau = $self->_search_skydip_index($sys, \%hdr);

    }


    # Need to configure the fallback options to enable the
    # adoption of a CSO tau to be optional
    # If $tau has not yet been set (ie the index lookup failed)
    # revert to a CSO tau lookup
    unless (defined $tau) {

      orac_print "No suitable skydip found - converting from CSO tau\n";
      # Find CSO
      my $csotau = $self->thing->{'TAU_225'};

      ($tau, $status) = get_tau($filt, 'CSO', $csotau);

      if ($status == -1) {
	orac_warn("Error converting a CSO tau of $csotau to an opacity for filter $filt\n");
	$tau = undef;
      }
    }
  } elsif ($sys eq 'CSOFIT') {

    # Retrieve the tau for the required time
    my $csotau = $self->csofit->tau( $self->thing->{ORACTIME});

    if (defined $csotau) {

      # Convert it to the required filter
      ($tau, $status) = get_tau($filt, 'CSO', $csotau);

      if ($status == -1) {
	orac_warn("Error converting a CSO tau of $csotau to an opacity for filter $filt\n");
	$tau = undef;
      }

    } else {
      orac_warn "No fit present for this date\n";
      $tau = undef;
    }

  } else {
    orac_err(" tausys is non-standard ($sys)\n");
    $tau = undef;
  }

  # Cache the result if it is defined
  $self->taucache->{$sys}->{$oractime}->{$filt} = $tau if defined $tau;

  # Now we have a tau value so return it
  return $tau;

}


=back

=head2 Destructor

=over 4

=item B<DESTROY>

Removes any directories that may have been created by this
calibration class (eg by starting fluxes).

Currently does nothing.

=cut

sub DESTROY {
  my $self = shift;
}



=back

=begin __PRIVATE_METHODS__

=head1 PRIVATE METHODS

Methods used internally by this class.

=over 4

=item B<_search_skydip_index>

Given a header, via a hash reference, and a interpolation type search
the skydip index file to see if a match can be found.  A separate
method so that it can be called with different filter names
efficiently (without having to do special-cased pattern matching for
850W and 850N. See the C<tau()> method for the different interpolation
methods for skydips.

  my $tau = $Cal->_search_skydip_index($method, \%hdr);

Returns the tau (undefined if no match). The tau will be for the selected
filter and will not be scaled to a reference filter.

=cut

sub _search_skydip_index {

  my $self = shift;

  # $sys is the interpolation system to use
  # $hdr is a ref to a hash containing all the headers
  my ($sys, $hdr) = @_;

  # This stores the answer
  my $tau;

  # Now we have to ask for the 'best' skydip matching these
  # criterion. For interpolation schemes we need to ask for
  # the nearest skydips either side in time from the current
  # frame. For normal querying we simply ask for the closest
  # in time.

  # ASIDE: Note that in the 850skydip case, querying the complete
  # index file is inefficient since the chances are quite good
  # that a verification of the current skydip alone would be okay

  # This variable sets the threshold value for age
  my $too_old = 3.0/24.0; # 3 hours as a day fraction

  # Check that SYS matches 'interp' (interpolation)
  # and ask for two index searches [inefficient???]
  # Might want to use a index routine that searches for high and
  # low at the same time
  if ($sys =~ /INTERP/) {
    my $high = $self->skydipindex->chooseby_positivedt('ORACTIME', $hdr, 0);
    my $low  = $self->skydipindex->chooseby_negativedt('ORACTIME', $hdr, 0);

    # Check to see
    # Now retrieve the actual entries
    my ($high_ent, $low_ent);
    $high_ent = $self->skydipindex->indexentry($high) if defined $high;
    $low_ent  = $self->skydipindex->indexentry($low) if defined $low;

    # The possibilities are:
    # - low and high are found, we interpolate
    # - low and high are found but some are older than 3 hours, warn
    #   and interpolate
    # - only high is found - use it [warn if too new]
    # - only low is found - use it [warn if too old]
    # - nothing found - revert to using CSO tau

    # Check the HIGH
    if (defined $high_ent) {
      # Okay - see how old it is
      my $age = abs($high_ent->{ORACTIME} - $hdr->{ORACTIME});
      if ($age > $too_old) {
	orac_warn(" the closest skydip (from above: $high) was too new [".sprintf('%5.2f',$age*24.0)." hours]\nUsing this value anyway...\n");
      }
    }

    # Check the LOW
    if (defined $low_ent) {
      # Okay - see how old it is
      my $age = abs($low_ent->{ORACTIME} - $hdr->{ORACTIME});
      if ($age > $too_old) {
	orac_warn(" the closest skydip (from below: $low) was too old [".sprintf('%5.2f',$age*24.0)." hours]\nUsing this value anyway...\n");
      }
    }

    # Now look for the tau values
    if (defined $low_ent && defined $high_ent) {
      # Interpolate TAU value

      # Find taus for each time
      my $highz = $high_ent->{TAUZ};
      my $hight = $high_ent->{ORACTIME};
      my $lowz  = $low_ent->{TAUZ};
      my $lowt  = $low_ent->{ORACTIME};

      my $framet = $hdr->{ORACTIME};

#	print "HIGH: $highz @ $hight\n";
#	print "LOW: $lowz  @ $lowt\n";
#	print "Now:  $framet\n";

      # Calculate tau at time $framet
      # This is not as good as returning both tau values
      # and times to the caller

      orac_print "Calculating interpolated tau value....\n";

      $tau = $lowz + ($framet - $lowt) * ($highz-$lowz) / ($hight - $lowt);

    } else {

      orac_warn "Cannot interpolate - can not find suitable skydips on both sides of this observation\nUsing a single value...\n";
	
      # If only one is defined, use that tau
      $tau = undef;
      $tau = $low_ent->{TAUZ} if defined $low_ent;
      $tau = $high_ent->{TAUZ} if defined $high_ent;

      # If none are defined - tau is undef anyway
	
    }


  } else { # No interpolation, just use nearest

    # Retrieve the closest in time
    my $nearest = $self->skydipindex->choosebydt('ORACTIME', $hdr,0);

    # Check return value
    if (defined $nearest) {

      # Now retrieve the entry
      my $entref = $self->skydipindex->indexentry($nearest);

      # Possibilities are:
      # - something found, use it, report if it is too old.
      # - nothing found - revert to using CSO tau

      # Check age
      if (defined $entref) {
	my $age = abs($entref->{ORACTIME} - $hdr->{ORACTIME});
	orac_warn("Skydip $nearest was taken ".sprintf('%5.2f',$age*24.0)." hours from this frame\nUsing this value anyway...\n")
	  if $age > $too_old;

	$tau = $entref->{TAUZ};

      } else {
	orac_warn "Error reading index entry $nearest\n";
      }
    }

  }

  # Return the answer
  return $tau;

}

=item B<_get_default_fcf>

Given a filter, FCF units (BEAM or ARCSEC) and the UT date (in ORACUT
format) returns the default FCF values as derived from an automated
reduction of the complete data archive.

  $fcf = $self->_get_default_fcf( $filter, 'ARCSEC', '19980215');

Returns undef if no FCF is available for the specified combination.

=cut

sub _get_default_fcf {

  my $self = shift;
  my ($filter, $units, $ut) = @_;

  $filter = uc($filter); # upper cased keys
  $units  = uc($units);
  $ut = int($ut);  # only changes on integer days

  # First check to see if the filter is present in the %FCFS hash
  return undef unless exists $FCFS{$filter};

  # Get the array
  my $details = $FCFS{$filter};

  # Now we step through the array until we find an entry that 
  # corresponds to the requested time
  my $match;
  my $infstart = 19900101; # infinity low and high
  my $infend   = 30000101;
  for my $h (@$details) {

    # Just force a start and end and then check to see whether
    # the reference date is inside
    my $start = (exists $h->{START} ? $h->{START} : $infstart);
    my $end   = (exists $h->{END}   ? $h->{END}   : $infend);

    if ($start <= $ut && $end >= $ut) {
      $match = $h;
      last;
    }

  }

  # If we did not match return undef
  return undef unless defined $match;

  # This is a little inefficient and repetitive but I want to retain
  # the ability to choose an aperture size for ARCSEC

  # We have a match so we now have to search for the correct units
  return undef unless exists $match->{$units};

  # Everything okay, return the answer
  return $match->{$units};

}


=back

=end __PRIVATE_METHODS__

=head1 SEE ALSO

L<ORAC::Calib>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
