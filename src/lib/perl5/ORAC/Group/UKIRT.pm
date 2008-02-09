package ORAC::Group::UKIRT;

=head1 NAME

ORAC::Group::UKIRT - Base class for dealing with groups from UKIRT instruments

=head1 SYNOPSIS

  use ORAC::Group::UKIRT;

  $Grp = new ORAC::Group::UKIRT;

=head1 DESCRIPTION

This class provides UKIRT specific methods for handling groups.

=cut

use 5.006;
use strict;
use warnings;
our $VERSION;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Group::NDF;

use base qw/ ORAC::Group::NDF /;

# These are the UKIRT generic lookup tables
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "DECBASE",
            DETECTOR_READ_TYPE  => "MODE",
            EQUINOX             => "EQUINOX",
            FILTER              => "FILTER",
            NUMBER_OF_OFFSETS   => "NOFFSETS",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSERVATION_TYPE    => "OBSTYPE",
            ROTATION            => "CROTA2",
            SPEED_GAIN          => "SPD_GAIN",
            STANDARD            => "STANDARD",
            WAVEPLATE_ANGLE     => "WPLANGLE",
            X_LOWER_BOUND       => "RDOUT_X1",
            X_UPPER_BOUND       => "RDOUT_X2",
            Y_LOWER_BOUND       => "RDOUT_Y1",
            Y_UPPER_BOUND       => "RDOUT_Y2"
          );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Group::UKIRT->_generate_orac_lookup_methods( \%hdr );

sub _to_TELESCOPE {
  return "UKIRT";
}

sub _to_RA_BASE {
  my $self = shift;
  return ($self->hdr->{RABASE} * 15.0);
}

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;

