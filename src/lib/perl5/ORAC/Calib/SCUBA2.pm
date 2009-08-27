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

$DEBUG = 0;                     # Turn off debugging mode

# Define default SCUBA-2 gains

# FCF can vary with time. Index by filter and then ARCSEC/BEAM
# UT date is used for START and END. If none there then assume open
# ended. If only START assume currently applicable
# The arrays are populated in order
# START and END are inclusive

my %FCFS = ('850' => [             # Asumed to be in date order
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

my %PHOTFLUXES = (
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


# Setup the object structure
__PACKAGE__->CreateBasicAccessors( mask => {},
                                   resp => {},
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
  $self->tausys( "CSO" );

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


=head2 Support Methods

The "mask" and "resp" methods have support implementations to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

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
