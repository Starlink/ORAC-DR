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

# FCF can vary with time. Index by filter and then ARCSEC/BEAM
# UT date is used for START and END. If none there then assume open
# ended. If only START assume currently applicable
# The arrays are populated in order
# START and END are inclusive

my %FCFS = ('850' => [             # Assumed to be in date order
                   {
                    START => 20060101, # Beginning of SCUBA-2 history
                    ARCSEC=> 2.25,
                    BEAM  => 500,
                   }
                  ],
         '450' => [
                   {
                    START => 20060101, # Beginning of SCUBA-2 history
                    ARCSEC => 6.3,
                    BEAM   => 400,
                   }
                  ],
        );

# These NEPs are the specifications in the dark which the arrays are
# expected to meet
my %NEP = ( '850' => 7.0e-17, '450' => 2.1e-16 );

# Should probably put calibrator flux information in a different
# file

# Need to store fluxes for each filter
# Use Jy

my %PHOTFLUXES = (
               'HLTAU' => {
                           '850' => 2.36,
                           '450' => 10.4,
                          },
               'CRL618' => {
                            '850' => 4.7,
                            '450' => 11.8,
                           },
               'CRL2688' => {
                             '850' => 6.4,
                             '450' => 29.7,
                            },
               '16293-2422' => {
                                '850' => 22.9,
                                '450' => 169.6,
                               },
               'V883ORI' => {
                             '850' => 1.34,
                             '450' => 7.28,
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
                            '850' => 0.688,
                            '450' => 2.77,
                           },
              );


# Setup the object structure
__PACKAGE__->CreateBasicAccessors( mask => {},
                                   resp => {},
				   flat => {},
				   dark => {},
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
  $obj->{Beam} = {},           # Current best-fit beam parameters
  $obj->{FWHM} = undef,        # Current mean main-beam FWHM
  $obj->{SkyRefImage} = undef; # Name of current reference image

  # Specify default tausys
  $obj->tausys( "CSO" );

  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=item B<default_fcfs>

Return the default FCF lookup table indexed by filter.

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
    $fwhm = ( $thingref->{FILTER}  =~ /^85/ ) ? 14.0 : 7.5;
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

=item B<nep>

Method to return the NEP spec for the current wavelength

=cut

sub nep {

  my $self = shift;
  my $filter = $self->thingone->{FILTER};
  my $nepkey = ( $filter =~ /^85/ ) ? "850" : "450";

  return $NEP{$nepkey};
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
  return $self->GenericIndexAccessor( "mask", 0, 1, 0, 1, @_ );
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
  return $self->GenericIndexAccessor( "flat", 0, 1, 0, 1, @_ );
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
    @defaultbeam = (14.0, 14.0, 0.0); # 850 um
  } else {
    @defaultbeam = (7.5, 7.5, 0.0); # 450 um
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

=cut

sub makemap_config {
  my $self = shift;

  my $configfile = "dimmconfig";
  my @basedir = ($ENV{'STARLINK_DIR'}, "/share/smurf");

  my %args = @_;
  if ( %args ) {

    # Append labels in the following order: config_type and pipeline.
    if ( defined $args{config_type} ) {
      $configfile .= "_".$args{config_type}
        unless ( $args{config_type} eq "normal" );
    }

    # Check for SUMMIT or QL pipeline
    my $pipeline = (defined $args{pipeline}) ? lc($args{pipeline}) : "";
    if ($pipeline eq "ql" || $pipeline eq "summit") {
      # Note different base dir
      @basedir = ($ENV{'ORAC_DATA_CAL'});
      $configfile .= "_".$pipeline;
    }
  }

  $configfile .= ".lis";

  return File::Spec->catfile( @basedir, $configfile );
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
