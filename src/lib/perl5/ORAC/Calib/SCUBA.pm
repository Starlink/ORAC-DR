package ORAC::Calib::SCUBA;

=head1 NAME

ORAC::Calib::SCUBA - SCUBA calibration object

=head1 SYNOPSIS

  use ORAC::Calib::SCUBA;

  $Cal = new ORAC::Calib::SCUBA;

  $gain = $Cal->gain($filter);


=head1 DESCRIPTION

This module returns (and can be used to set) calibration information
for SCUBA. SCUBA calibrations are used for extinction correction
(the sky opacity) and conversion of volts to Janskys.

=cut


# Calibration object for the ORAC pipeline

use strict;
use Carp;
use vars qw/$VERSION %DEFAULT_GAINS %PHOTFLUXES @PLANETS $DEBUG/;

use Cwd;          # Directory change
use File::Path;   # rmtree function

# Derive from standard Calib class (even though nothing in common
# for now)
use ORAC::Calib;  # We are a Calib class
use ORAC::Index;  # Use index file
use ORAC::Print;  # Standardised printing
use ORAC::Constants; # ORAC__OK

use ORAC::Msg::ADAM::Control;  # For fluxes monolith - messaging
use ORAC::Msg::ADAM::Task;     # For fluxes monolith


use JCMT::Tau;    # Tau conversion

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Calib::SCUBA::ISA = qw/ORAC::Calib/;
use base qw/ORAC::Calib/;

$DEBUG = 0; # Turn off debugging mode
 
# Define default SCUBA gains

%DEFAULT_GAINS = (
		  '2000' => 650,
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
	       'HLTAU' => {
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


# The planets that we can retrieve fluxes for
@PLANETS = qw/ MARS JUPITER SATURN URANUS NEPTUNE /;


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

  $obj->{Gains} = undef;
  $obj->{GainsNoUpdate} = 0;
  $obj->{GainsIndex} = undef;
  $obj->{TauSys} = undef;
  $obj->{TauSysNoUpdate} = 0;
  $obj->{SkydipIndex} = undef;
  $obj->{FluxesObj} = undef;      # Fluxes monolith
  $obj->{FluxesTmpDir} = undef;
  $obj->{AMS} = undef;         # ADAM messaging object

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=item fluxes_tmp_dir

Name of temporary directory created for the fluxes monolith.
(set or retrieve)

=cut

sub fluxes_tmp_dir {
  my $self = shift;
  if (@_) { $self->{FluxesTmpDir} = shift; }
  return $self->{FluxesTmpDir};
}



=item fluxes_mon

Retrieves the ORAC::Msg::ADAM::Task object associated with
the Starlink fluxes monolith.

A new object is created if the value is undefined.

Relies on the Adam messaging system being available.
ADAM messaging is initialised if not present.

Currently this routine also assumes that no other fluxes
objects are started by this process (since there are a number
of things that must be configured before starting the monolith).

=cut

sub fluxes_mon {
  my $self = shift;
  my $status;

  unless (defined $self->{FluxesObj}) {
    # Start AMS
    $self->{AMS} = new ORAC::Msg::ADAM::Control;
    $status = $self->{AMS}->init;
    croak 'ORAC::Calib::SCUBA::fluxes_mon: Error starting ADAM messaging system'
      unless $status == ORAC__OK;

    # Start FLUXES - this requires some environment variables to be defined
    # This should use a $FLUXES_DIR env variable
    $ENV{FLUXES} = '/star/bin/fluxes';

    # Should chdir to /tmp, create the soft link, launch fluxes
    # and then chdir back to wherever we happen to be.

    my $cwd = cwd; # Store current dir

    # Create temp directory - this is needed in case another
    # oracdr is running fluxes and we want to make sure that
    # the JPLEPH file is not removed when THAT oracdr finishes!
    my $tmpdir = "/tmp/fluxes_$$";
    mkdir $tmpdir,0777 || croak "Could not make directory $tmpdir: $!";

    chdir($tmpdir) || croak "Could not change directory to $tmpdir: $!";

    # Hard-wire in the location of JPLEPH - note that 
    # we assume /star is available as /star!!!!
    # Probably could do with $JPL_DIR as well.
    # Create soft link to JPLEPH

    # If the JPLEPH file is there already then assume it is okay
    unless (-f "JPLEPH") {
      unlink "JPLEPH";
      symlink "/star/etc/jpl/jpleph.dat", "JPLEPH"
	|| croak "Could not create link to JPL ephemeris";
    }

    # Set FLUXPWD variable
    $ENV{'FLUXPWD'} = cwd;

    # Now we can try and launch fluxes
    my $obj = new ORAC::Msg::ADAM::Task("fluxes_$$",
				       "$ENV{FLUXES}/fluxes");

    # Now we can chdir back to our real working directory
    chdir $cwd || croak "Could not change back to $cwd: $!";

    # Wait and See if we can contact
    if ($obj->contactw) {
      # Store the object
      $self->{FluxesObj} = $obj;
      $self->fluxes_tmp_dir($tmpdir);
    } else {
      croak 'Error launching fluxes monolith. Aborting.';
    }

  }

  return $self->{FluxesObj};

}



=item tausys

Set (or retrieve) the name of the system to be used for
tau determination. Allowed values are 'CSO', 'SKYDIP',
'850SKYDIP' or a number. Currently the number is assumed to be the 
CSO tau since this number is independent of wavelength.
'INDEX' is an allowed synonym for 'SKYDIP'. '850SKYDIP'
mode uses the results of 850 micron skydips from index
files to derive the opacity for the requested wavelength.

Currently there is no way to specify an actual 850 micron
tau value (the number is treated as a CSO value). In the future
this may change (or a tausys of 850=value will be used??)

If tausys has not been set it defaults to 'CSO'

=cut

sub tausys {
  my $self = shift;
  if (@_) { $self->{TauSys} = uc(shift) unless $self->tausysnoupdate; }
  $self->{TauSys} = 'CSO' unless (defined $self->{TauSys});
  return $self->{TauSys};
}

=item tausysnoupdate

Flag to prevent the tau system from being modified during data
processing.

=cut

sub tausysnoupdate {
  my $self = shift;
  if (@_) { $self->{TauSysNoUpdate} = shift };
  return $self->{TauSysNoUpdate};
}


=item skydipindex

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

=item tau(filt)

Returns the tau associated with the supplied filter.

This routine works as follows. First tausys() is queried to determine
the system to use to calculate the tau. If this is CSO, the current
frame is queried for the CSO tau value stored and the tau calculated
for FILTER. If tausys() returns a number it is assumed
to be the actual CSO tau to use. If it is set to Skydip (or index) then
the selected wavelength is updated in the frame header (Key=FILTER)
and the skydip index is queried for the skydip that matched the criterion
and is closest in time.

At some point we may want to add a feature where the tau values either
side of the frame are reported and used to find the current tau.

Also, we might want to add a system where the high frequency tau is derived
from the closest low-frequency skydip.....

undef is returned if an error occurred [eg the CSO is so high that the
tau can not be calculated using the linear relationship].

=cut

sub tau {
  my $self = shift;

  croak 'Usage: tau(filter)' if (scalar(@_) != 1);

  # Get the filter (this could be sub-instrument but it is probably
  # easier to use filter than to query the header for the sub name).
  my $filt = uc(shift);

  # Declare local variables
  my ($tau, $status);

  # Now query tausys
  my $sys = $self->tausys;

  # Check tausys
  if ($sys eq 'CSO') {

    # Read the value from the header of thing
    my $csotau = $self->thing->{'TAU_225'};

    ($tau, $status) = get_tau($filt, 'CSO', $csotau);

    orac_warn("Error converting a CSO tau of $csotau to an opacity for filter $filt\n") if $status == -1;

  } elsif ($sys =~ /^\d+\.?\d*$/) {
    # We check for a number - note that this pattern does not match
    # numbers that start with a decimal point.

    ($tau, $status) = get_tau($filt, 'CSO', $sys);

    # Check status
    orac_warn("Error converting a CSO tau of $sys to an opacity for filter $filt\n") if $status == -1;

    
  } elsif ($sys eq 'SKYDIP' || $sys eq 'INDEX') {

    # Skydips have been selected. 
    # Given that a skydip is never current (because each time we change
    # filter the 'current' is no longer valid) ask for one every time.
    # This assumes that people do not want to specify a skydip that
    # should be used by the system. (usually a hard-wired CSO is enough)

    # First add/modify the FILTER keyword in the current frame
    $self->thing->{FILTER} = $filt;

    # Now ask for the best skydip
    # (Closest in time)
    # Note that the reduction stops if a skydip can not be found...
    my $best = $self->skydipindex->choosebydt('ORACTIME', $self->thing);

    # Now retrieve the index entry itself
    my $entref = $self->skydipindex->indexentry($best);

    if (defined $entref) {
      $tau = $entref->{TAUZ};
    } else {
      orac_err("Error reading entry $best from Skydip index");
      $tau = undef;      
    }


  } elsif ($sys eq '850SKYDIP') {

    # We are reqeusting that the tau of the current filter
    # is retrieved by looking at the tau from an 850 skydip

    # Get a copy of the header hash
    my %hdr = %{$self->thing};

    # First need to make sure that we are looking for a 850 skydip value
    $hdr{FILTER} = '850';

    # Now ask for the best skydip
    # (Closest in time)
    # Note that the reduction stops if a skydip can not be found...
    my $best = $self->skydipindex->choosebydt('ORACTIME', \%hdr);

    # Now retrieve the index entry itself
    my $entref = $self->skydipindex->indexentry($best);

    if (defined $entref) {
      $tau = $entref->{TAUZ};

      orac_print "Using 850 tau of $tau to generate tau for filter $filt\n";

      # Now convert this tau to the requested filter
      ($tau, $status) = get_tau($filt, '850', $tau);

      orac_warn("Error converting a 850 tau of $tau to an opacity for filter $filt\n") if $status == -1;

    } else {
      orac_err("Error reading entry $best from Skydip index");
      $tau = undef;      
    }


  } else {
    orac_err(" tausys is non-standard ($sys)\n");
    $tau = undef;
  }


  # Now we have a tau value so return it
  return $tau;

}


=item gains

Determines whether gains are derived from the default values
(DEFAULT) or from the index files (INDEX). Default is to
use the index files.

=cut

sub gains {
  my $self = shift;
  if (@_) { $self->{Gains} = uc(shift) unless $self->gainsnoupdate; }
  $self->{Gains} = 'DEFAULT' unless (defined $self->{Gains});
  return $self->{Gains};
}


=item gainsnoupdate

Flag to prevent the gains selection from being modified during data
processing.

=cut

sub gainsnoupdate {
  my $self = shift;
  if (@_) { $self->{GainsNoUpdate} = shift };
  return $self->{GainsNoUpdate};
}


=item gainsindex

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


=item gain(filt)

Method to return the current gain for the specified filter that
is usable for the current frame.

If gains() is set to DEFAULT then this method will simply return
the current canonical gain for this filter.

If gains() is set to INDEX the index will be searched for a calibration
observation that matches the observation mode (ie Chop throw, sample
mode, observing mode agree). 

The current index system refuses to continue if a calibration can
not be found. In future this may well be changed so that the
DEFAULT values are used if no calibration is available.

Returns the gain (undef if no gain could be found or error).

It may also be useful if the gains either side of current observation
are retrieved so that the gain can be interpolated.

This would use the same method call that may be added for handling
skydips either side. (chooseeithersidebydt?)

=cut

sub gain {
  my $self = shift;

  croak 'Usage: gain(filter)' if (scalar(@_) != 1);

  # Get the filter (this could be sub-instrument but it is probably
  # easier to use filter than to query the header for the sub name).
  my $filt = uc(shift);

  # Query the gain system to use
  my $sys = $self->gains;

  my $gain;

  if ($sys eq 'DEFAULT') {
    
    if (exists $DEFAULT_GAINS{$filt}) {
      $gain = $DEFAULT_GAINS{$filt};
    } else {
      orac_err "No gain exists for the specified filter ($filt)\n";
      $gain = undef;
    }

  } elsif ($sys eq 'INDEX') {

    # Now look in the index file

    # Need to configure the header such that the FILTER keyword
    # is set
    $ {$self->thing}{FILTER} = $filt;

    # Now ask for the 'best' gain observation
    # This means closest in time
    my $best = $self->gainsindex->choosebydt('ORACTIME', $self->thing);

    # Now retrieve the entry itself
    my $entref = $self->gainsindex->indexentry($best);

    if (defined $entref) {
      $gain = $$entref{GAIN};
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

  # If we match a planet straightaway then it is a calibrator
  # regardless of filter (unless the filter is not available in fluxes)

  return 1 if grep /$source/, @PLANETS;


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

Returns undef if the flux could not be determined.

=cut

sub fluxcal {

  my $self = shift;
  my $source = uc(shift);
  my $filter = shift;

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

    ($status, $flux) = $self->fluxes_mon->get("","F_BEAM");
    if ($status != ORAC__OK || $flux == -1) {
      orac_err "Error retrieving flux for filter $filter and planet $source\n";
      return undef;
    }

  }

  return $flux;


}



=item skydiptaus

Method to store and retrieve the reference to a hash containing the
current tau information derived from skydips.
The hash should be indexed by SCUBA filter.

  $Cal->skydiptaus(\%hdr);
  $hashref = $Cal->skydiptaus;

=cut

sub skydiptaus {

  my $self = shift;
 
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{SkydipTaus} = $arg;
  }

  return $self->{SkydipTaus};
}




=item skydiptau

Allow a single skydip tau value  to be retrieved for a specific filter.

  $tau = $Cal->skydiptau("850");
  
Can also be used to set a value

  $Cal->skydiptau("850", number);

=cut

sub skydiptau {

  my $self = shift;
 
  my $keyword = shift;
 
  if (@_) { ${$self->skydiptaus}{$keyword} = shift; }
 
  return ${$self->skydiptaus}{$keyword};

} 


=item DESTROY

Removes any directories that may have been created by this
calibration class (eg by starting fluxes).

Assumes that only this object is interested in the fluxes monolith
associated with this object since we are about to remove the
temporary directory containing the JPL ephemeris file.

=cut

sub DESTROY {
  my $self = shift;
  if ($self->fluxes_tmp_dir) {
    rmtree $self->fluxes_tmp_dir;    
    orac_print "Removing temporary directory containing JPLEPH\n"
      if $DEBUG;
  }
}



=back

=head1 SEE ALSO

L<ORAC::Calib> 

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut
 
1;
