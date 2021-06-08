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
use vars qw/$VERSION $DEBUG /;

use Cwd;                        # Directory change

# Derive from standard Calib class (even though nothing in common
# for now)
use ORAC::Index;                # Use index file
use ORAC::Print;                # Standardised printing

# External modules
use File::Spec;

$VERSION = '1.0';

use base qw/ORAC::Calib::JCMTCont/;

# Use SCUBA-2 tau relations
use JCMT::Tau::SCUBA2;

$DEBUG = 0;                     # Turn off debugging mode

# Define default SCUBA-2 gains

# FCF can vary with time. Index by filter and then ARCSEC/BEAM UT date
# is used for START and END. If none there then assume open ended. If
# only START assume currently applicable The arrays are populated in
# order START and END are inclusive.

my %FCFS = ('850' => [             # Assumed to be in date order
                      {
                       START  => 20060101, # Beginning of SCUBA-2 history
                       END    => 20161118,
                       ARCSEC => 2.25, # +/- 0.13
                       BEAM   => 525, # +/- 37
                      },
                      {
                       START  => 20161119,
                       END    => 20180630,
                       ARCSEC => 2.13, # +/- 0.12
                       BEAM   => 516, # +/- 42
                      },
                      {
                       START  => 20180701,
                       ARCSEC => 2.07, # +/- 0.12
                       BEAM   => 495, # +/- 32
                      },
                     ],
            '450' => [
                      {
                       START  => 20060101, # Beginning of SCUBA-2 history
                       END    => 20180630,
                       ARCSEC => 4.61, # +/- 0.60
                       BEAM   => 531, # +/- 93
                      },
                      {
                       START  => 20180701,
                       ARCSEC => 3.87, # +/- 0.53
                       BEAM   => 472, # +/- 76
                      },
                     ],
           );

# These NEPs are the specifications in the dark which the arrays are
# expected to meet
my %NEP = ( '850' => 7.0e-17, '450' => 2.1e-16 );

# Should probably put calibrator flux information in a different
# file

# List of known secondary calibrator fluxes - one hash contains the
# total flux (ASECFLUXES) while the other contains the flux per beam
# (BEAMFLUXES). For most secondary calibrators these are very close to
# the same thing as they are unresolved.
my %ASECFLUXES = (
                  'HLTAU' => {
                              '850' => 2.30, # +/- 0.17 (STM 21)
                              '450' => 8.03, # +/- 1.84 (STM 21)
                             },
                  'CRL618' => {
                               '850' => 5.07, # +/- 0.31 (STM 21)
                               '450' => 13.28, # +/- 2.72 (STM 21)
                              },
                  'CRL2688' => {
                                '850' => 5.45, # +/- 0.31 (STM 21)
                                '450' => 24.36, # +/- 4.49 (STM 21)
                               },
                  '16293-2422' => {
                                   '850' => 22.9,
                                   '450' => 169.6,
                                  },
                  'V883ORI' => {
                                '850' => 2.00,
                                '450' => 11.0,
                               },
                  'ALPHAORI' => {
                                 '850' => 0.629,
                                 '450' => 1.39,
                                },
                  'TWHYA' => {
                              '850' => 1.37,
                              '450' => 3.9,
                             },
                  'ARP220' => {
                               '850' => 0.85, # +/- 0.06 (STM 21)
                               '450' => 5.64, # +/- 1.23 (STM 21)
                              },
                  'KKOPH' => {
                              '850' => 0.091,
                             },
                  'MWC349' => {
                               '850' => 2.19,
                               '450' => 3.20,
                              },
                  'PVCEP' => {
                              '850' => 1.35,
                              '450' => 10.6,
                             },
                  'HD135344' => {
                                 '850' => 0.53,
                                 '450' => 3.30,
                                },
                  'HD141569' => {
                                 '850' => 0.011,
                                 '450' => 0.065,
                                },
                  'HD142666' => {
                                 '850' => 0.333,
                                 '450' => 1.14,
                                },
                  'HD169142' => {
                                 '850' => 0.58,
                                 '450' => 2.78,
                                },
                  'BVP1' => {
                             '850' => 1.55,
                             '450' => 16.9,
                            },
              );
my %BEAMFLUXES = (
                  'HLTAU' => {
                              '850' => 2.41, # +/- 0.14 (STM 21)
                              '450' => 11.18, # +/- 1.59 (STM 21)
                             },
                  'CRL618' => {
                               '850' => 5.14, # +/- 0.27 (STM 21)
                               '450' => 14.21, # +/- 2.71 (STM 21)
                              },
                  'CRL2688' => {
                                '850' => 6.07, # +/- 0.26 (STM 21)
                                '450' => 29.78, # +/- 4.59 (STM 21)
                               },
                  '16293-2422' => {
                                   '850' => 15.1,
                                   '450' => 62.7,
                                  },
                  'V883ORI' => {
                                '850' => 1.55,
                                '450' => 7.80,
                               },
                  'ALPHAORI' => {
                                 '850' => 0.629,
                                 '450' => 1.39,
                                },
                  'TWHYA' => {
                              '850' => 1.37,
                              '450' => 3.9,
                             },
                  'ARP220' => {
                               '850' => 0.85, # +/- 0.09 (STM 21)
                               '450' => 6.59, # +/- 1.43 (STM 21)
                              },
                  'KKOPH' => {
                              '850' => 0.091,
                             },
                  'MWC349' => {
                               '850' => 2.21,
                               '450' => 3.12,
                              },
                  'PVCEP' => {
                              '850' => 0.82,
                              '450' => 5.7,
                             },
                  'HD135344' => {
                                 '850' => 0.46,
                                 '450' => 1.66,
                                },
                  'HD141569' => {
                                 '850' => 0.011,
                                 '450' => 0.065,
                                },
                  'HD142666' => {
                                 '850' => 0.333,
                                 '450' => 1.14,
                                },
                  'HD169142' => {
                                 '850' => 0.52,
                                 '450' => 2.21,
                                },
                  'BVP1' => {
                             '850' => 1.37,
                             '450' => 11.5,
                            },
              );

# Some early data had HLTau taken with an object name of HLTauB
$BEAMFLUXES{HLTAUB} = $BEAMFLUXES{HLTAU};
$ASECFLUXES{HLTAUB} = $ASECFLUXES{HLTAU};
# Similarly MWC349A
$BEAMFLUXES{MWC349A} = $BEAMFLUXES{MWC349};
$ASECFLUXES{MWC349A} = $ASECFLUXES{MWC349};

# JCMT beam parameters from SCUBA-2 calibration paper (STM 21).
# FRAC1 and FRAC2 are the proportion of the flux contained within
# the primary and error beams respectively.
my %BEAMPAR = ( '850' => {
                          FWHM1 => 11.0, # +/- 1.6
                          FWHM2 => 49.1, # +/- 8.4
                          AMP1 => 0.98, # +/- 0.01
                          AMP2 => 0.02, # +/- 0.01
                          FRAC1 => 0.74, # +/- 0.04
                          FRAC2 => 0.26, # +/- 0.04
                         },
                '450' => {
                          FWHM1 => 6.2, # +/- 1.0
                          FWHM2 => 18.8, # +/- 5.7
                          AMP1 => 0.89, # +/- 0.08
                          AMP2 => 0.11, # +/- 0.08
                          FRAC1 => 0.47, # +/- 0.12
                          FRAC2 => 0.53, # +/- 0.12
                         }
              );

# Default beam area
# (Values set to reproduce fhwm_eff of 14.4 and 10.0" at 850 and 450um
# from STM 2021 calibration paper).
my %BEAMAREA = ( '850' => 234.94,
                 '450' => 113.30,
               );

# SCUBA-2 secondary calibrators commonly observed at the wrong position.
# Supply the correct positions from the JCMT pointing catalog for use with
# position fudging.
my %CATALOG_POSITION = (
    'CRL618'    => ['04:42:53.672', '+36:06:53.17'],
    'CRL2688'   => ['21:02:18.75',  '+36:41:37.80'],
    'HLTAU'     => ['04:31:38.4',   '+18:13:59.0'],
    'ARP220'    => ['15:34:57.272', '+23:30:10.48'],
);

# Setup the object structure
__PACKAGE__->CreateBasicAccessors( mask => {},
                                   resp => {},
                                   fastflat => {},
                                   flat => {},
                                   dark => {},
                                   setupflat => {},
                                   noise => {},
                                   nep => {},
                                   zeropath => {},
                                   zeropath_fwd => {},
                                   zeropath_bck => {},
);

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
  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

  # This assumes we have a hash object
  if (defined $obj && ref($obj) eq "HASH") {
    $obj->{BeamFit} = undef;        # Current best-fit beam parameters (hash ref)
    $obj->{ErrBeamFit} = undef;     # Current fit to error beam (hash ref)
    $obj->{FWHMfit} = undef;        # Most recent fitted mean FWHM (scalar)
    $obj->{FWHMerr} = undef;        # Most recent fitted FWHM of error beam (scalar)
    $obj->{ErrFrac} = undef;        # Most recent estimate of error beam fraction
  }

  # Specify default tausys
  $obj->tausys( "CSO" );

  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=item B<beamcomp>

Return the number of components in the current fit to the beam. Will
be either 1 or 2 if a fit exists, otherwise undef.

  my $ncomp = $Cal->beamcomp();

=cut

sub beamcomp {
  my $self = shift;
  my $ncomp;
  if ($self->beamfit) {
    my $beamfit = $self->beamfit;
    $ncomp = $beamfit->{BeamComp};
  }
  return $ncomp;
}

=item B<beamfit>

A method to set or retrieve the full parameter set for the most recent
fit to the beam. If setting the beam parameters, all of the parameters
must be specified as a hash. The beam dimensions and orientation must
be passed as array references. A hash reference containing the beam
parameters is returned.

  $Cal->beamfit( majfwhm => \@majfwhm, minfwhm => \@minfwhm,
                 orient => \@orient, gamma => $gamma );

  $Cal->beamfit( %beamfit );

  my $beamfit_ref = $Cal->beamfit;

The returned hash reference has the following keys: C<BeamA>,
C<BeamAErr>, C<BeamB>, C<BeamBErr>, C<PA>, C<PAErr>, C<FWHM>, C<Gamma>
and C<BeamComp>. C<BeamA> and C<BeamB> are the major and minor axes
respectively of the first component of the fit. In the case of a
two-component fit, the FWHM of the second component (and its
uncertainty) is stored by the C<errbeam> method. The C<FWHM> entry
contains the geometric mean of the major and minor axes of the first
component. C<Gamma> will always be 2 if there are two components.

Conventionally the units of the FWHM are arcsec, but it is up to the
caller to ensure that the FWHM values are in the units of choice
before storing them here.

=cut

sub beamfit {
  my $self = shift;
  if ( @_ ) {
    my %beamargs = @_;
    my @majfwhm = @{$beamargs{majfwhm}} if (defined $beamargs{majfwhm});
    my %beamfit = ( BeamA => $majfwhm[0],
                    BeamAErr => $majfwhm[1],
                    BeamB => $beamargs{minfwhm}->[0],
                    BeamBErr => $beamargs{minfwhm}->[1],
                    BeamComp => (@majfwhm > 2) ? 2 : 1,
                    PA => $beamargs{orient}->[0],
                    PAErr => $beamargs{orient}->[1],
                    Gamma => $beamargs{gamma}
      );

    # Store fitted FWHM for main and error beams
    $beamfit{FWHM} = sqrt($beamfit{BeamA}*$beamfit{BeamB});
    $self->{BeamFit} = \%beamfit;
    $self->fwhm_fit($beamfit{FWHM});
    $self->errbeam({BeamA => $majfwhm[2], BeamAErr => $majfwhm[3]});
  }

  return $self->{BeamFit};
}

=item B<catalog_position>

Get the catalog position for a secondary calibrator if we have a catalog
position for it.

    my $position = $Cal->catalog_position($Frm->hdr('OBJECT'));

Returns undef if there is no catalog position stored for the given object.
Otherwise returns a reference to a RA, Dec array of sexagesimal strings.

=cut

sub catalog_position {
    my $self = shift;
    my $source = uc(shift);
    $source =~ s/\s//g;

    if (exists $CATALOG_POSITION{$source}) {
        return $CATALOG_POSITION{$source};
    }

    return undef;
}

=item B<errbeam>

The current estimated FWHM of the error beam (and its uncertainty) as
given in the C<beampar> results. Must be given and returns a hash
reference with the keys C<BeamA> and C<BeamAErr>.

  $Cal->errbeam({BeamA => $fwhm, BeamAErr => $fwhm_err});
  my $errbeam = $Cal->errbeam;

=cut

sub errbeam {
  my $self = shift;
  if (@_) {
    $self->{ErrBeamFit} = shift;
    $self->fwhm_err($self->{ErrBeamFit}->{BeamA});
  }
  return $self->{ErrBeamFit};
}

=item B<errfrac>

Fractional power in the error beam as determined from aperture photometry.

  $Cal->errfrac($errfrac);
  my $errfrac = $Cal->errfrac;

=cut

sub errfrac {
  my $self = shift;
  if (@_) {
    $self->{ErrFrac} = shift;
  }
  return $self->{ErrFrac};
}

=item B<fwhm_err>

Returns the FWHM of the current estimate of the error beam.

  $Cal->fwhm_err($fwhm_err);
  my $fwhm_err = $Cal->fwhm_err;

=cut

sub fwhm_err {
  my $self = shift;
  if (@_) {
    $self->{FWHMerr} = shift;
  }
  return $self->{FWHMerr};
}

=item B<fwhm_fit>

Retrieve the fitted beam full-width-at-half-maximum (FWHM). Returns
the geometric mean of the major/minor axes of the fit.

  my $fitted_fwhm = $Cal->fwhm_fit;
  $Cal->fwhm_fit($fwhm);

If the complete beam parameters are required, the B<beamfit>
method should be used instead. Returns undef if no fit parameters have
been stored.

=cut

sub fwhm_fit {
  my $self = shift;
  if (@_) {
    $self->{FWHMfit} = shift;
  }
  return $self->{FWHMfit};
}

=back

=head2 Instance methods

=over 4

=item B<beam>

Return the telescope beam parameters for the current wavelength. See
the C<beamfit> method for the results of the most recent fit to the
beam.

Returns a hash reference with the keys C<FWHM1>, C<FWHM2>, C<AMP1>,
C<AMP2>, C<FRAC1> and C<FRAC2>.

  my $telescope_beam = $Cal->beam;

=cut

sub beam {
  my $self = shift;
  return $BEAMPAR{$self->subinst};
}

=item B<beamamps>

Return the relative amplitudes of the telescope beam components at the
current wavelength. Returns either an array with two elements or array
reference depending on caller. The first element corresponds to the
main beam component.

  my $beamamps = $Cal->beamamps;
  my @beamamps = $Cal->beamamps;

=cut

sub beamamps {
  my $self = shift;
  my $beam = $self->beam;
  return (wantarray) ? ($beam->{AMP1}, $beam->{AMP2})
    : [$beam->{AMP1}, $beam->{AMP2}];
}

=item B<beamarea>

Returns the beam area in units of arcsec^2/beam. The nominal
values have been determined empirically from an ensemble
of calibration data.

  $beamarea = $Cal->beamarea();

The optional parameter is an aperture diameter in arcsec:

  $beamarea = $Cal->beamarea( $diam );

This value can be thought of as an ideal Gaussian of FWHM
sqrt(beamarea/1.133). It will be slightly bigger than the
nominal FWHM of the primary beam because error lobes are
included.

=cut

sub beamarea {
  my $self = shift;
  my $diam = shift;

  # Now the defaults
  # Note that this is actually a function of aperture diameter
  # but we currently do not have enough information for that.
  return $BEAMAREA{$self->subinst()};
}

=item B<beamfrac>

Return the fractional power in each component of the beam as an array
or array reference. May also take parameter to return either the main
or error beam fraction.

  my ($main, $err) = $Cal->beamfrac;
  my $err = $Cal->beamfrac("err");

=cut

sub beamfrac {
  my $self = shift;
  if (@_) {
    my $cpt = ($_[0] =~ /err/) ? "FRAC2" : "FRAC1";
    return $BEAMPAR{$self->subinst}->{$cpt};
  } else {
    my $main = $BEAMPAR{$self->subinst}->{FRAC1};
    my $err  = $BEAMPAR{$self->subinst}->{FRAC2};
    return (wantarray) ? ($main, $err) : [$main, $err];
  }
}

=item B<default_fcfs>

Return the default FCF lookup table indexed by filter.

 %FCFS = $cal->default_fcfs();

=cut

sub default_fcfs {
  return %FCFS;
}

=item B<fwhm>

Return the measured telescope beam FWHM for the two components at the
current wavelength. Returns either an array with two elements or array
reference depending on caller. The first element is the main beam
component.

  my $fwhm = $Cal->fwhm;
  my @fwhm = $Cal->fwhm;

=cut

sub fwhm {
  my $self = shift;
  my $beam = $self->beam;
  return (wantarray) ? ($beam->{FWHM1}, $beam->{FWHM2})
    : [$beam->{FWHM1}, $beam->{FWHM2}];
}

=item B<fwhm_eff>

Returns the FWHM (in arcsec) of a Gaussian with the same area as the
empirical telescope beam (see the B<beamarea> method below).

  $fwhm_eff = $Cal->fwhm_eff;

=cut

sub fwhm_eff {
  my $self = shift;
  # pi / (4 ln 2) = 1.133090
  return sqrt($self->beamarea/1.133);
}

=item B<nep_spec>

Method to return the NEP spec for the current wavelength

  my $nep_spec = $Cal->nep_spec;

=cut

sub nep_spec {
  my $self = shift;
  return $NEP{$self->subinst};
}

=item B<secondary_calibrator_fluxes>

Return the lookup table of fluxes for secondary calibrators. Takes an
optional parameter which returns the total fluxes rather than the `per
beam' values.

 %photfluxes = $cal->secondary_calibrator_fluxes( $ismap );

=cut

sub secondary_calibrator_fluxes {
  my $self = shift;
  my $ismap = shift if (@_);
  return (defined $ismap && $ismap) ? %ASECFLUXES : %BEAMFLUXES;
}

=back

=head2 Index Methods

=over 4

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
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "mask", 0, 1, 0, $warn, @_ );
}

=item B<dark>

Return (or set) the name of the current dark frame.

  $dark = $Cal->dark;

This method is subclassed for SCUBA-2 because we have dark frames for
each subarray. Note that the user must set the subarray with the Frame
class C<subarray()> method before a suitable calibration entry can be
found. This is due to the fact that it is not possible to search the
Frame subheaders when evaluating the rules.

=cut

sub dark {
  my $self = shift;
  return $self->GenericIndexAccessor( "dark", 0, 1, 0, 1, @_ );
}

=item B<flat>

Return (or set) the name of the current flatfield solution.

  $flat = $Cal->flat;

This method is subclassed for SCUBA-2 because we have one flatfield
per subarray. Note that the user must set the subarray with the Frame
class C<subarray()> method before a suitable calibration entry can be
found. This is due to the fact that it is not possible to search the
Frame subheaders when evaluating the rules.

=cut

sub flat {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "flat", -1, 1, 0, $warn, @_ );
}

=item B<fastflat>

Return (or set) the name of the current fast-ramp flatfield file(s).

  $fastflat = $Cal->fastflat;

There is one fast-ramp flatfield file per subarray. Note that the user
must set the subarray with the Frame class C<subarray()> method before
a suitable calibration entry can be found. This is due to the fact
that it is not possible to search the Frame subheaders when evaluating
the rules.

=cut

sub fastflat {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "fastflat", -1, 1, 0, $warn, @_ );
}


=item B<setupflat>

Return the name of the matching fast-ramp flatfield file from the most
recent C<SETUP> observation.

  $setupflat = $Cal->setupflat;

There is one fast-ramp flatfield file per subarray. Note that the user
must set the subarray with the Frame class C<subarray()> method before
a suitable calibration entry can be found. This is due to the fact
that it is not possible to search the Frame subheaders when evaluating
the rules.

=cut

sub setupflat {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "setupflat", -1, 1, 0, $warn, @_ );
}

=item B<noise>

Return the name of the matching noise observation.

  $noise = $Cal->noise;

There is one noise file per subarray. Note that the user must set the
subarray with the Frame class C<subarray()> method before a suitable
entry can be found. This is due to the fact that it is not possible to
search the Frame subheaders when evaluating the rules.

=cut

sub noise {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "noise", -1, 1, 0, $warn, @_ );
}

=item B<nep>

Return the name of the matching NEP file. This returns the name of the
top-level container file - the user must then select the
C<.more.smurf.nep> component within that file.

  $nep = $Cal->nep;

There is one noise file per subarray. Note that the user must set the
subarray with the Frame class C<subarray()> method before a suitable
entry can be found. This is due to the fact that it is not possible to
search the Frame subheaders when evaluating the rules.

=cut

sub nep {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( "nep", -1, 1, 0, $warn, @_ );
}


=item B<zeropath>

Return (or set) the name of the current zeropath file(s).

  $zeropath = $Cal->zeropath();

=cut

sub zeropath {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( 'zeropath', -1, 1, 0, $warn, @_ );
}

=item B<zeropath_fwd>

Return (or set) the name of the current forward zeropath file(s).

  $zeropath = $Cal->zeropath_fwd();

=cut

sub zeropath_fwd {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( 'zeropath_fwd', -1, 1, 0, $warn, @_ );
}

=item B<zeropath_bck>

Return (or set) the name of the current backward zeropath file(s).

  $zeropath = $Cal->zeropath_bck();

=cut

sub zeropath_bck {
  my $self = shift;
  # Do not warn about non-matching calibrations
  my $warn = 0;
  return $self->GenericIndexAccessor( 'zeropath_bck', -1, 1, 0, $warn, @_ );
}

=back

=head2 General Methods

=over 4

=item B<makemap_config>

Return the full path to a default makemap config file. Options to
return particular default configurations may be passed in as a
hash. Valid keys are C<config_type> and C<pipeline>. The config type
must be one of the supported values (see the contents of
$STARLINK_DIR/share/smurf for available options). If given, the
pipeline argument must be either C<ql> or C<summit> and causes this
method to look in the directory defined by the environment variable
ORAC_DATA_CAL.

  my $config_file = $Cal->makemap_config;
  my $config_file = $Cal->makemap_config( pipeline => "ql" );

The C<config_type> is usually stored as a uhdr entry for the current
Frame object.

The C<pipeline> argument is ignored if the config type is given as C<moon>.

=cut

sub makemap_config {
  my $self = shift;

  my $configfile = "dimmconfig";
  my @basedir = ($ENV{'STARLINK_DIR'}, "/share/smurf");

  my %args = @_;
  if ( %args ) {

    # Append labels in the following order: config_type and pipeline.
    my $config_type = lc($args{config_type}) if (defined $args{config_type});
    if ( $config_type ) {
      $configfile .= "_".$config_type
        unless ( $config_type eq "base" );
    }

    # Check for SUMMIT or QL pipeline
    my $pipeline = "";
    if (defined $args{pipeline}) {
      # Make exceptions for the moon and bright_compact
      $pipeline = lc($args{pipeline})
        unless ($config_type &&
                ($config_type eq "moon" || $config_type eq "bright_compact"));
    }
    if ($pipeline eq "ql" || $pipeline eq "summit") {
      # Note different base dir
      @basedir = ($ENV{'ORAC_DATA_CAL'});
      $configfile .= "_".$pipeline;
    }
  }

  $configfile .= ".lis";

  return File::Spec->catfile( @basedir, $configfile );
}

=item B<pixelscale>

Method to retrieve default values of the pixel scale for output
images. The numbers are returned in ARCSEC. These numbers are
hard-wired here and should always be retrieved with this
method.

Note this is intended for use with DREAM/STARE images, not SCAN data.

=cut

sub pixelscale {
  my $self = shift;

  my $pixelscale = ( $self->subinst() eq "850" ) ? 5.80 : 3.09;

  return $pixelscale;
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
  return $self->GenericIndexAccessor( "resp", 0, 0, 0, 1, @_ );
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

=item B<subinst>

The sub-instrument associated with this calibration object.
Returns either C<450> or C<850>.

  $subinst = $Cal->subinst();

=cut

sub subinst {
   my $self = shift;
   my $thingref = $self->thingone;
   return ( $thingref->{FILTER}  =~ /^85/ ? "850" : "450" );
}

=back

=head2 Support Methods

The "mask" and "resp" methods have support implementations to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

=begin __PRIVATE_METHODS__

=head1 PRIVATE METHODS

The following methods are for internal use only.

=cut

=over 4

=item B<_get_tau>

Wrapper for the C<get_tau> method in JCMT::Tau to ensure the correct
instrument-specific tau relation is used.

  my ($tau_out, $status) = $self->_get_tau( $filter, $tausys, $tau_in );

=cut

sub _get_tau {
  my $self = shift;
  # Have to split up @_ due to prototype definition in JCMT::Tau
  return get_tau($_[0], $_[1], $_[2]);
}

=back

=end __PRIVATE_METHODS__

=head1 SEE ALSO

L<ORAC::Calib::JCMTCont>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Science and Technology Facilities Council.
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
