package ORAC::Frame::UKIRT;

=head1 NAME

ORAC::Frame::UKIRT - UKIRT class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to UKIRT. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::UKIRT> objects.

=cut


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
ORAC::Frame::UKIRT->_generate_orac_lookup_methods( \%hdr );


# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.004;
use vars qw/$VERSION/;
use ORAC::Frame::NDF;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::NDF;
use base qw/ORAC::Frame::NDF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


# standard error module and turn on strict
use Carp;
use strict;


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using 
this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;


  if ($self->hdr('GRPMEM')) {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do about
    # it except for the case of certain calibration objects that
    # we know are the only members of their group (eg DARK)

#    if ($self->hdr('OBJECT') eq 'DARK') {
       $hdrgrp = 0;
#    }

  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findrecipe>

Find the recipe name. If no recipe can be found from the
'DRRECIPE' FITS keyword'QUICK_LOOK' is returned by default.

The recipe name stored in the object is automatically updated using 
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('DRRECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if (!defined($recipe) or $recipe !~ /./) {
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}


=back

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

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
