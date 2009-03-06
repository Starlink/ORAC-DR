package ORAC::Calib::SCUBA2;

=head1 NAME

ORAC::Calib::SCUBA2 - SCUBA-2 calibration object

=head1 SYNOPSIS

  use ORAC::Calib::SCUBA2;

  $Cal = new ORAC::Calib::SCUBA2;

=head1 DESCRIPTION

This module returns (and can be used to set) calibration information
for SCUBA-2.

It can also be used to set and retrieve lists of bad bolometers generated
by noise observations.

This class does inherit from B<ORAC::Calib> although nearly all the
methods in the base class are irrelevant to SCUBA-2 (this class only
uses the thing() method).

Note that currently this module is mostly just a copy of the SCUBA
module, with extra SCUBA-2 specific methods. Some pruning/updating
WILL be necessary.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION %DEFAULT_FCFS %PHOTFLUXES @PLANETS $DEBUG %FCFS/;

use Cwd;                        # Directory change

# Derive from standard Calib class (even though nothing in common
# for now)
use ORAC::Calib;                # We are a Calib class
use ORAC::Index;                # Use index file
use ORAC::Print;                # Standardised printing
use ORAC::Constants;            # ORAC__OK
use ORAC::Msg::EngineLaunch;    # To launch fluxes monolith

# External modules

use JCMT::Tau;                  # Tau conversion
use JCMT::Tau::CsoFit;          # Fits to CSO data

use File::Spec;

$VERSION = '1.0';

# Let the object know that it is derived from ORAC::Frame;
#@ORAC::Calib::SCUBA2::ISA = qw/ORAC::Calib/;
use base qw/ORAC::Calib/;

$DEBUG = 0;                     # Turn off debugging mode

# Define default SCUBA gains
# These vary with a number of things including filter, and observing
# mode. Map calibration can also be done using Jy/arcsec2 or Jy/beam.
# Additionally there is the possibility of time dependent changes
# due to improvements in throughput (not necessarily a change in filter)

%DEFAULT_FCFS = (
                 BEAM => {      # Jy/pW/beam
                          '850'  => 435,
                          '450'  => 130,
                         },
                 ARCSEC => {
                            '450' => 1.00,
                            '850' => 1.00,
                           }
                );


# FCF can vary with time. Index by filter and then ARCSEC/BEAM
# UT date is used for START and END. If none there then assume open
# ended. If only START assume currently applicable
# The arrays are populated in order
# START and END are inclusive

%FCFS = ('850' => [             # Asumed to be in date order
                   {
                    START => 20060101, # Beginning of SCUBA-2 history
                    ARCSEC=> 1.0 ,
                    BEAM  => 435,
                   }
                  ],
         '450' => [
                   {
                    START => 20060101, # Beginning of SCUBA-2 history
                    ARCSEC => 1.0,
                    BEAM   => 130,
                   }
                  ],
        );

# Should probably put calibrator flux information in a different
# file

# Need to store fluxes for each filter
# Use Jy

%PHOTFLUXES = (
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
                               },
               'OH231.8' => {
                             '850' => 2.52,
                             '450' => 10.53,
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

Create a new instance of a ORAC::Calib::SCUBA2 object.
The object identifier is returned.

  $Cal = new ORAC::Calib::SCUBA2;

=cut

# NEW - create new instance of Calib

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {
             BadBols => undef,  # Bad bolometers
             BadBolsNoUpdate => 0,
             EngineLaunch => new ORAC::Msg::EngineLaunch,
             Gains => undef,    # Gains (Flux Conversion Factors)
             GainsIndex => undef,
             GainsNoUpdate => 0,
	     Mask => undef,	# Bad bolometer mask
	     MaskIndex => undef, # Index file for picking best bad bolo mask
	     MaskNoUpdate => 0,
	     Resp => undef,		# Responsivity solution
	     RespIndex => undef,       	# Index file for responsivities
	     RespStats => undef,	# RMS uncertainties for responsivity fit
             SkydipIndex => undef,
             TauSys => undef,   # Tau system
             TauSysNoUpdate => 0,
             TauCache => {},    # Cache for tau result
             Thing1 => {},      # Header of current frame
             Thing2 => {},      # Header of current frame
             CsoFit => undef,   # Polynomial tau fits
             Beam => {},        # Current best-fit beam parameters
             FWHM => undef,     # Current mean main-beam FWHM
             SkyRefImage => undef, # Name of current reference image
            };

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=item B<fwhm>

A simple method to set or retrieve the beam full-width-at-half-maximum
(FWHM). If the complete beam parameters are required, the B<beam>
method should be used instead. If the FWHM is undef then a hard-wired
default value, appropriate for the current wavelength, is returned.

  $Cal->fwhm( $fwhm );

  my $fwhm = $Cal->fwhm;

=cut

sub fwhm {
  my $self = shift;

  # Set
  if ( @_ ) {
    $self->{FWHM} = shift;
    return;
  }

  # Get
  my $fwhm = (defined $self->{FWHM}) ? $self->{FWHM} : 0;

  if ( $fwhm == 0 ) {
    my $thingref = $self->thingone;
    $fwhm = ( $thingref->{FILTER}  =~ /^85/ ) ? 15.0 : 8.0;
  }
  return $fwhm;
}

=item B<beampar>

A method to set or retrieve the full parameter set for the most recent
fit to the beam. If setting the beam parameters, all of the parameters
must be specified. The beam dimensions and orientation must be passed
as array references. A hash reference containing the beam parameters
is returned.

  $Cal->beampar( majfwhm => \@majfwhm, minfwhm => \@minfwhm, 
		 orient => \@orient, errfrac => $errfrac );

  my $beampar_ref = $Cal->beampar;

Conventionally the units of the FWHM are arcsec, but it is up to the
caller to ensure that the FWHM values are in the units of choice
before storing them here.

=cut

sub beampar {
  my $self = shift;

  # $self->beam is a hash reference. What should the keys be?
  # BMAJ => val
  # BMAJERR => val
  # BMIN => val
  # BMINERR => val
  # PA => val
  # PAERR => val
  # ErrFrac => val

  if ( @_ ) {
    my %beamargs = @_;

    # What if any of these is undef?
    $self->{Beam}->{Bmaj} = $beamargs{majfwhm}->[0];
    $self->{Beam}->{BmajErr} = $beamargs{majfwhm}->[1];
    $self->{Beam}->{Bmin} = $beamargs{minfwhm}->[0];
    $self->{Beam}->{BminErr} = $beamargs{minfwhm}->[1];
    $self->{Beam}->{Pa} = $beamargs{orient}->[0];
    $self->{Beam}->{PaErr} = $beamargs{orient}->[1];

    $self->{Beam}->{ErrFrac} = $beamargs{errfrac};

    # Store geometric mean as FWHM
    $self->fwhm( sqrt($beamargs{majfwhm}->[0] * $beamargs{minfwhm}->[0]) );

    return;
  }

  return $self->{Beam};

}

=item B<refimage>

Method to store or retrieve current reference image. The method
requires two arguments: the group name and the name of the reference
image. Currently, the group name is not used, but that may change in
the future.

  $Cal->refimage( $group_name, $refimage );

  my $refimage = $Cal->refimage;

=cut

sub refimage {
  my $self = shift;

  if ( @_ ) {
    my ( $group, $refimage ) = @_;
    $self->{SkyRefImage} = $refimage;
    return;
  }

  return $self->{SkyRefImage};
}

=item B<maskname>

Return (or set) the name of the current bad pixel mask

  $mask = $Cal->maskname;

The C<mask()> method should be used if a test for suitability of the
mask is required.

=cut


sub maskname {
  my $self = shift;

  if (@_) { $self->{Mask} = shift unless $self->masknoupdate; }
  return $self->{Mask};
}

=item B<mask>

Return (or set) the name of the current bad bolometer mask.

  $mask = $Cal->mask;

This method is subclassed for SCUBA-2 because we have one mask per
subarray and not one standard mask. Note that the user must set the
subarray with the Frame class C<subarray()> method before a suitable
calibration entry can be found. This is due to the fact that it is not
possible to search the Frame subheaders when evaluating the rules.

=cut

sub mask {
  my $self = shift;
  if( @_ ) {
    return $self->maskname( shift );
  }

  my $ok = $self->maskindex->verify( $self->maskname, $self->thing, 0 );

  # Happy ending. Current entry is OK.
  if( $ok ) { return $self->maskname; }

  croak( "Override mask is not suitable! Giving up" ) if $self->masknoupdate;

  if( defined( $ok ) ) {
    my $mask = $self->maskindex->choosebydt( 'ORACTIME', $self->thing, 0 );
    orac_warn "No suitable mask was found in index file\n"
      unless defined $mask;
    $self->maskname( $mask );
    return $self->maskname;
  } else {
    croak( "Error in mask calibration checking - giving up" );
  }
}

=item B<maskindex>

Return or set the index object associated with the bad pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {
  my $self = shift;

  if (@_) { $self->{MaskIndex} = shift; }
  unless ( defined $self->{MaskIndex} ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" );
    my $rulesfile = $self->find_file("rules.mask");
    $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{MaskIndex};
}

=item B<masknoupdate>

Stops object from updating itself with more recent data.
Used when overriding the mask file from the command-line.

=cut

sub masknoupdate {

  my $self = shift;
  if (@_) { $self->{MaskNoUpdate} = shift; }
  return $self->{MaskNoUpdate};

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
  if (@_) {
    $self->{Gains} = uc(shift) unless $self->gainsnoupdate;
  }
  $self->{Gains} = 'DEFAULT' unless (defined $self->{Gains});
  return $self->{Gains};
}

=item B<gainsindex>

Return (or set) the index object associated with the gains
index file. This index file is used if gains() is set to INDEX.

=cut

sub gainsindex {

  my $self = shift;
  if (@_) {
    $self->{GainsIndex} = shift;
  }

  unless (defined $self->{GainsIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "index.gains");
    my $rulesfile = $self->find_file("rules.gains");
    $self->{GainsIndex} = new ORAC::Index($indexfile,$rulesfile);
  }
  ;

  return $self->{GainsIndex};
}

=item B<gainsnoupdate>

Flag to prevent the gains selection from being modified during data
processing.

=cut

sub gainsnoupdate {
  my $self = shift;
  if (@_) {
    $self->{GainsNoUpdate} = shift;
  }
  ;
  return $self->{GainsNoUpdate};
}


=item B<skydipindex>

Return (or set) the index object associated with the skydip
index file. This index file is used if tausys() is set to skydip.

=cut

sub skydipindex {

  my $self = shift;
  if (@_) {
    $self->{SkydipIndex} = shift;
  }

  unless (defined $self->{SkydipIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "index.skydip");
    my $rulesfile = $self->find_file("rules.skydip");
    $self->{SkydipIndex} = new ORAC::Index($indexfile,$rulesfile);
  }
  ;

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

If tausys has not been set it defaults to 'CSO'.

=cut

sub tausys {
  my $self = shift;
  if (@_) {
    $self->{TauSys} = uc(shift) unless $self->tausysnoupdate;
  }
  $self->{TauSys} = 'CSO' unless (defined $self->{TauSys});
  return $self->{TauSys};
}

=item B<tausysnoupdate>

Flag to prevent the tau system from being modified during data
processing.

=cut

sub tausysnoupdate {
  my $self = shift;
  if (@_) {
    $self->{TauSysNoUpdate} = shift;
  }
  ;
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
  if (@_) {
    $self->{CsoFit} = shift;
  }

  unless (defined $self->{CsoFit}) {
    my $file = $self->find_file("csofit.dat");
    $self->{CsoFit} = new JCMT::Tau::CsoFit($file);
  }
  ;

  return $self->{CsoFit};
}


=back

=head2 General methods

=over 4

=item B<pixelscale>

Method to retrieve default values of the pixel scale for output
images. The numbers are returned in ARCSEC. These numbers are
hard-wired here and should always be retrieved with this
method.

=cut

sub pixelscale {
  my $self = shift;

  my $pixelscale = ( $self->{Thing1}->{FILTER}  =~ /^85/ ) ? 5.80 : 3.09;

  return $pixelscale;
}

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
    # of course SCUBA-2 uses YYYY:MM:DD format

    # Use ORACTIME and ORACUT for these since there are sometimes
    # dodgy headers that the header translation code has to deal with
    my $scudate = $self->thing->{'ORACUT'}; # the thing method is the header

    if (defined $scudate) {
      # ORACUT is in YYYYMMDD format
      my $y = substr($scudate, 2, 2);
      my $m = substr($scudate, 4, 2);
      $m =~ s/^0//;
      my $d = substr($scudate, 6, 2);
      $d =~ s/^0//;

      $scudate = "$d $m $y";

    } else {
      $scudate = '1 1 1';
    }

    # Get the time as well - I'm pretty sure that the flux will hardly
    # change when I change the ut time
    # Use ORACTIME since we need to handle sometimes dodgy UT header
    my $scutime = $self->thing->{'ORACTIME'};

    if (defined $scutime) {
      # we will ignore leap seconds
      my $frac = $scutime - int($scutime);
      my $dech = $frac * 24;
      my $h = int($dech);
      my $decm = ($dech - $h) * 60;
      my $m = int($decm);
      my $decs = int(($decm - $m) * 60);

      $scutime = "$h $m $decs";

    } else {
      $scutime = '0 0 0';
    }

    my $status = $self->fluxes_mon->obeyw("","$hidden planet=$source date='$scudate' time='$scutime' filter=$filter");

    if ($status != ORAC__OK) {
      orac_err "The FLUXES program did not run successfully\n";
      return;
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
      return;
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
  return (defined $gain ? $gain : 0);

}


=item B<iscalsource>

Given the source name and filter, work out whether we have calibration
information on this source (ie we know the flux for this filter). If
information is available return true (1) else return (0).

  $yesno = $Cal->iscalsource("source_name","filter");

If filter is not supplied, it is assumed we are simply asking
whether the source is a calibrator independent of whether we
actually have a calibration value for it.

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
    my $csotau = $self->thing->{'ORAC_TAU'};
    ($tau, $status) = get_tau($filt, 'CSO', $csotau);

    if ($status == -1) {
      orac_warn("Error converting a CSO tau of ".
                (defined $csotau ? $csotau : "<undef>").
                " to an opacity for filter '$filt'\n");
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
      orac_warn("Error converting a supplied CSO tau of ".
                (defined $sys ? $sys : "<undef>"). 
                " to an opacity for filter '$filt'\n");
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

    } elsif ($sys =~ /^850/) {  # scale from 850 filter

      # Need to loop over all 850 filters until we find one that
      # returns a match. In principal, we should search for all filters
      # and then determine the closest (either by using a clever rules
      # file or by searching multiple times and storing the time 
      # difference). In practice, you very really mix 850W skydips with
      # 850N skydips within a single night.

      my $found;
      foreach my $f ( '850' ) {
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
              orac_warn("Error converting a $found tau to an opacity for filter '$filt'\n");
              $tau = undef;
            }
          }

        }

      }

    } else {                   # Just want to use the requested filter

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
      my $csotau = $self->thing->{'ORAC_TAU'};
      ($tau, $status) = get_tau($filt, 'CSO', $csotau);

      if ($status == -1) {
        orac_warn("Error converting a CSO tau of ".
                  (defined $csotau ? $csotau : "<undef>"). 
                  " to an opacity for filter '$filt'\n");
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
        orac_warn("Error converting a fitted CSO tau of ".
                  (defined $csotau ? $csotau : "<undef>").
                  " to an opacity for filter '$filt'\n");
        $tau = undef;
      }

    } else {
      orac_warn "No fit present for this date\n";
      $tau = undef;
    }

  } elsif ($sys eq 'WVM') {
    # see if it has already been read
    my $wvm = $self->thing->{ORAC_WVM_TAU};
    my $wvm_err = $self->thing->{ORAC_WVM_TAU_STDEV};

    if ($wvm) {
      orac_print( sprintf("WVM data located in frame: %.4f +/- %.4f\n",
                          $wvm, $wvm_err));

      ($tau, $status) = get_tau($filt, 'CSO', $wvm);

      # Check status
      if ($status == -1) {
        orac_warn("Error converting a WVM tau of $sys to an opacity for filter '$filt'\n");
        orac_warn("Setting tau to 0\n");
        $tau = 0.0;
      }

    } else {
      # look up in archive
      orac_err( " WVM opacity calibration requested but no WVM data found. Unable to process request\n");
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

=item B<respname>

Return (or set) the name of the current responsivity solution.

  $resp = $Cal->respname;

The C<resp()> method should be used if a test for suitability is
required.

=cut


sub respname {
  my $self = shift;

  if (@_) { $self->{Resp} = shift; }
  return $self->{Resp};
}

=item B<resp>

Return (or set) the name of the current responsivity solution.

  $resp = $Cal->resp;

Note that unless the current Frame has been derived from a sub-group,
the user must set the subarray with the Frame class C<subarray()>
method before a suitable calibration entry can be found. This is due
to the fact that it is not possible to search the Frame subheaders
when evaluating the rules.

=cut

sub resp {
  my $self = shift;
  if( @_ ) {
    return $self->respname( shift );
  }

  my $ok = $self->respindex->verify( $self->respname, $self->thing, 0 );

  # Happy ending. Current entry is OK.
  if( $ok ) { return $self->respname; }

  if( defined( $ok ) ) {
    my $resp = $self->respindex->choosebydt( 'ORACTIME', $self->thing, 0 );
    orac_warn "No suitable responsivity solution was found in index file\n"
      unless defined $resp;
    $self->respname( $resp );
    return $self->respname;
  } else {
    croak( "Error in resp calibration checking - giving up" );
  }
}

=item B<respindex>

Return or set the index object associated with the responsivity.

  $index = $Cal->respindex;

An index object is created automatically the first time this method
is run.

=cut

sub respindex {
  my $self = shift;

  if (@_) { $self->{RespIndex} = shift; }
  unless ( defined $self->{RespIndex} ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.resp" );
    my $rulesfile = $self->find_file("rules.resp");
    $self->{RespIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{RespIndex};
}

=item B<respstats>

Get/set the statistics associated with the most recent flatfield
solution. If setting, the user must supply a subarray and hash
reference with the relevant statistics. No check is made to verify the
contents of the hash. The user may pass in an optional subarray
argument if retrieving the stored values, otherwise the entire hash
reference is returned. If so then a hash reference is returned whicih
contains only the relevant info for the given subarray. A value of
undef is returned if no data exist for that subarray.

  my %allrespstats = %{ $Cal->respstats };

  my $respstatsref = $Cal->respstats( $subarray );

  $Cal->respstats( $subarray, \%respstats );

=cut

sub respstats {
  my $self = shift;

  # If we have any arguments then we are storing a hash reference
  if ( @_ ) {
    my $subarray = shift;
    # Check subarray looks like a subarray designation
    orac_throw "Subarray argument, $subarray, is not a valid designation\n" 
      unless $subarray =~ /^s\d[a-d]/;
    # Now look for remaining arguments - must be a hash reference if present
    if ( @_ ) {
      my $respref = shift;
      if ( ref($respref) eq "HASH" ) {
	$self->{RespStats} = { $subarray => $respref };
	return $self->{RespStats};
      } else {
	orac_throw "Error: second argument must be a hash reference";      
      }
    } else {
      # With just one argument, return info for given subarray if
      # defined, else return undef
      my $respref = $self->{RespStats};
      if ( defined $$respref{$subarray} ) {
	return $$respref{$subarray};
      } else {
	return undef;
      }
    }
  }

  # Returns hash reference
  return $self->{RespStats};
}

=item B<beam>

Returns the beamsize associated with the supplied array.

  @beam = $Cal->beam($arr);

The values returned are FWHM major axis, FWHM minor axis, PA. 

=cut

sub beam {
  my $self = shift;
  my $arr = shift;

  # Default beam sizes
  my @defaultbeam;
  if ($arr =~ /^850/ || $arr =~ /^L/) {
    @defaultbeam = (15.0, 15.0, 0.0); # 850 um
  } else {
    @defaultbeam = (8.0, 8.0, 0.0); # 450 um
  }
  my @beam = @defaultbeam;
  return @beam;
}

=item B<store_beam>

Stores the beam parameters for the given array

  $Cal->store_beam($arr, @beamparms);

Currently incomplete.

=cut

sub store_beam {
  my $self = shift;
  my $arr = shift;
  my @beamparameters = @_;

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
  my $too_old = 3.0/24.0;       # 3 hours as a day fraction

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


  } else {                      # No interpolation, just use nearest

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

  $filter = uc($filter);        # upper cased keys
  $units  = uc($units);
  $ut = int($ut);               # only changes on integer days

  # First check to see if the filter is present in the %FCFS hash
  return unless exists $FCFS{$filter};

  # Get the array
  my $details = $FCFS{$filter};

  # Now we step through the array until we find an entry that 
  # corresponds to the requested time
  my $match;
  my $infstart = 19900101;      # infinity low and high
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
  return unless defined $match;

  # This is a little inefficient and repetitive but I want to retain
  # the ability to choose an aperture size for ARCSEC

  # We have a match so we now have to search for the correct units
  return unless exists $match->{$units};

  # Everything okay, return the answer
  return $match->{$units};

}


=back

=end __PRIVATE_METHODS__

=head1 SEE ALSO

L<ORAC::Calib>

=head1 REVISION

$Id: SCUBA2.pm,v 1.47 2005/03/31 21:07:38 timj Exp $

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
