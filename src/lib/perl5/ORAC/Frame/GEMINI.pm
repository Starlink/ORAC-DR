package ORAC::Frame::GEMINI;

=head1 NAME

ORAC::Frame::GEMINI - class for dealing with GEMINI observation files in ORAC-DR

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to GEMINI. It provides a class derived from B<ORAC::Frame::UKIRT>.

=cut

use 5.006;
use strict;
use warnings;

use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

# standard error module and turn on strict
use Carp;

# These are maybe the Gemini generic lookup tables
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "DEC",
            EQUINOX             => "EQUINOX",
	    INSTRUMENT          => "INSTRUME",
            NUMBER_OF_EXPOSURES => "NSUBEXP",
            OBJECT              => "OBJECT",
            RA_BASE             => "RA",
	    UTDATE              => "DATE-OBS"
        );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Frame::GEMINI->_generate_orac_lookup_methods( \%hdr );

=head1 AUTHORS

Paul Hirst <p.hirst@jach.hawaii.edu>

=cut

 
1;
