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
            DECBASE             => "DECBASE",
            EQUINOX             => "EQUINOX",
            FILTER              => "FILTER",
            INSTRUMENT          => "INSTRUME",
            LBNDX               => "RDOUT_X1",
            LBNDY               => "RDOUT_Y1",
            NOFFSETS            => "NOFFSETS",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSTYPE             => "OBSTYPE",
            RABASE              => "RABASE",
            READMODE            => "MODE",
            ROTATION            => "CROTA2",
            SPD_GAIN            => "SPD_GAIN",
            STANDARD            => "STANDARD",
            UBNDX               => "RDOUT_X2",
            UBNDY               => "RDOUT_Y2",
            WPLANGLE            => "WPLANGLE"
          );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Group::UKIRT->_generate_orac_lookup_methods( \%hdr );

=begin __private

=head1 PRIVATE METHODS

=over 4

=item B<_from_*>

Methods to translate ORAC_ private headers to FITS headers
required by the instrument. This is the reverse of C<_to_*> called
from C<calc_orac_headers>.

These methods should only be called by C<translate_hdr>

Returns a hash containing the FITS key(s) and value(s).

   %fits = $Frm->_from_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=item B<_to_*>

Methods to translate standard FITS headers to ORAC_ headers.
These methods should be called just from C<orac_calc_headers>.

Returns the translated value.

  $val = $Frm->_to_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=cut

# For UKIRT the translation is simple
# Generate the methods automatically from a lookup table

# This method generates all the internal methods
# Expects a hash ref as argument and simply does a name
# translation without any data processing
# The hash is keyed by the ORAC_ name (without the ORAC_ prefix
# (although that will be removed if it appears)
# This is a class method (no object required)
sub _generate_orac_lookup_methods {
  my $class = shift;
  my $lut = shift;

  # Have to go into a different package
  my $p = "{\n package $class;\n";
  my $ep = "\n}"; # close the scope

  # Loop over the keys to the hash
  for my $key (keys %$lut) {

    # Get the original FITS header name
    my $fhdr = $lut->{$key};

    # Remove leading ORAC_ if it is there since the method
    # should not include it
    $key =~ s/^ORAC_//;

    # prepend ORAC_ for the actual key name
    my $ohdr = "ORAC_$key";

    # print "Processing $key and $ohdr and $fhdr\n";

    # First generate the code to generate ORAC_ headers
    my $subname = "_to_$key";
    my $sub = qq/ $p sub $subname { \$_[0]->hdr(\"$fhdr\"); } $ep /;
    eval "$sub";

    # Now the from 
    $subname = "_from_$key";
    $sub = qq/ $p sub $subname { (\"$fhdr\", \$_[0]->uhdr(\"$ohdr\")); } $ep/;
    eval "$sub";

  }

}

=back

=end __private

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;

