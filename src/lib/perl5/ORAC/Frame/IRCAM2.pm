package ORAC::Frame::IRCAM2;

=head1 NAME

ORAC::Frame::IRCAM2 - IRCAM class for dealing with new ORAC files

=head1 SYNOPSIS

  use ORAC::Frame::IRCAM2;

  $Frm = new ORAC::Frame::IRCAM2("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to IRCAM post ORAC delivery. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::IRCAM2>
objects.

=cut

# A package to describe a UFTI group object for the
# ORAC pipeline

use 5.004;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::UFTI;
use base qw/ORAC::Frame::UKIRT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# standard error module and turn on strict
use Carp;
use strict;

# Translation tables for UFTI shouldr go here
my %hdr = (
            DEC_SCALE            => "PIXELSIZ",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            DETECTOR_BIAS        => "DET_BIAS",
            EXPOSURE_TIME        => "DEXPTIME",
            GAIN                 => "DEPERDN",
            RA_SCALE             => "PIXELSIZ",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTDATE               => "DATE",
            UTEND                => "RUTEND",
            UTSTART              => "RUTSTART"
	  );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
# Have to use the inherited version so that the new subs appear in 
# this class
ORAC::Frame::IRCAM2->_generate_orac_lookup_methods( \%hdr );


=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::IRCAM2> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::UFTI;
   $Frm = new ORAC::Frame::UFTI("file_name");
   $Frm = new ORAC::Frame::UFTI("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'i' prefix although these can be overriden with the 
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
  $self->rawfixedpart('i');
  $self->rawsuffix('.sdf');
  $self->rawformat('HDS');
  $self->format('NDF');
 
  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;
 
  return $self;

}

=back

=head2 General Methods

=over 4

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For TUFTI/IRCAM3 the raw filename is of the form:

  iYYYYMMDD_NNNNN.sdf

where the number is 0 padded.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;


  # Zero pad the number
  $obsnum = sprintf("%05d", $obsnum);

  # CGS4 form is  FIXED PREFIX _ NUM SUFFIX
  return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}



=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
CGS4 and is usually of the form:

  .cYYYYMMDD_NNNNN.ok

=cut



sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;
  
  # flag files for CGS4 of the type .cYYYYMMDD_NNNNN.ok
  my $raw = $self->file_from_bits($prefix, $obsnum);

  # raw includes the .sdf so we have to strip it
  $raw = $self->stripfname($raw);

  my $flag = ".".$raw.".ok";

}


=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut


sub number {

  my $self = shift;

  my ($number);

  # Get the number from the raw data
  # Assume there is a number at the end of the string
  # (since the extension has already been removed)
  # Leading zeroes are dropped

  my $raw = $self->raw;
  if (defined $raw && $raw =~ /(\d+)(_raw)?(\.\w+)?$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.
The number is zero-padded.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $num = $self->number;
  # Zero pad the number
  $num = sprintf("%05d", $num);

  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($template);

}


=back

=head1 SEE ALSO

L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

 
1;
