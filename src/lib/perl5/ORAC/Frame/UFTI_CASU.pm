package ORAC::Frame::UFTI_CASU;

=head1 NAME

ORAC::Frame::UFTI_CASU - UFTI class for dealing with observation files in 
ORAC-DR (CASU version for FITS files)

=head1 SYNOPSIS

  use ORAC::Frame::UFTI_CASU;

  $Frm = new ORAC::Frame::UFTI_CASU("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to UFTI prior to ORAC delivery. It provides a class derived
from B<ORAC::Frame::SEF>. Some additional methods are supplied.

=cut

# A package to describe a UFTI group object for the
# ORAC pipeline

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Constants;
use ORAC::Frame::MEF;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::MEF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias pattern_from_bits as file_from_bits.
*pattern_from_bits = \&file_from_bits;

# standard error module and turn on strict
use Carp;
use strict;

# Translation tables for UFTI should go here. Had to merge in the keywords
# from the UKIRT.pm class as this latter was base classed to NDF and I didn't
# feel like creating another FITS based class.a
my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "DECBASE",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            DETECTOR_READ_TYPE  => "MODE",
            EQUINOX             => "EQUINOX",
            EXPOSURE_TIME        => "EXP_TIME",
            FILTER              => "FILTER",
            GAIN                 => "GAIN",
            INSTRUMENT          => "INSTRUME",
            NUMBER_OF_OFFSETS   => "NOFFSETS",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSERVATION_TYPE    => "OBSTYPE",
            RA_BASE             => "RABASE",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
  	    READNOISE           => "READNOIS",
            RECIPE              => "RECIPE",
            ROTATION            => "CROTA2",
            SPEED_GAIN          => "SPD_GAIN",
            STANDARD            => "STANDARD",
            UTDATE               => "DATE",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART",
            WAVEPLATE_ANGLE     => "WPLANGLE",
            X_LOWER_BOUND       => "RDOUT_X1",
            X_UPPER_BOUND       => "RDOUT_X2",
            Y_LOWER_BOUND       => "RDOUT_Y1",
            Y_UPPER_BOUND       => "RDOUT_Y2"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Frame::UFTI_CASU->_generate_orac_lookup_methods( \%hdr );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::SEF>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::UFTI_CASU> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::UFTI_CASU;
   $Frm = new ORAC::Frame::UFTI_CASU("file_name");
   $Frm = new ORAC::Frame::UFTI_CASU("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('f');
  $self->rawsuffix('.sdf');
  $self->rawformat('HDS');
  $self->format('FITS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME
  # For UFTI the keyword is simply UTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('UTSTART');
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # Calc ORACUT:
  my $ut = $self->hdr('DATE');
  $ut = 0 unless defined $ut;
  $ut =~ s/-//g;  #  Remove the intervening minus sign

  $self->hdr('ORACUT', $ut);
  $new{ORACUT} = $ut;

  return %new;
}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably for the UFTI_CASU subclass.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum
  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  # UFTI naming
  return $self->rawfixedpart . $prefix . '_' . $padnum . $self->rawsuffix;
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
UFTI.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the UFTI case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = $self->pattern_from_bits($prefix, $obsnum);

  # Replace the 'f' with a '.' and append '.ok'
  substr($raw,0,1) = '.';
  $raw .= '.ok';
}

# Supply a method to return the number associated with the observation

#=item B<number>

# Method to return the number of the observation. This is the
# number stored in the OBSNUM header

#   $number = $Frm->number;


### Note: this has been removed as it caused the -from -skip
### option combination to fail - FE

# =cut


# sub number {

#   my $self = shift;

#   my $number = $self->hdr('OBSNUM');

#   return $number;

# }


=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # pad with leading zeroes - 5(!) digit obsnum
  $num = '0'x(5-length($num)) . $num;

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}

sub readnoiseindex_exist {
    my $self = shift;
    my $rexist = (-e $ENV{ORAC_DATA_OUT}."/index.readnoise" ? 1 : 0);
    return($rexist);
}

=item B<hdrkeys>
 
Find out what the UFTI fits keyword for a particular ORAC header keyword is
 
    $header_keywords = $Frm->hdrkeys($orac_keyword);
 
=cut
 
sub hdrkeys {
    my $self = shift;
    my $key = shift;
 
    return($hdr{$key});
}
 

=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)
Jim Lewis (jrl@ast.cam.ac.uk)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
