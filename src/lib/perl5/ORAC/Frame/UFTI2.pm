package ORAC::Frame::UFTI2;

=head1 NAME

ORAC::Frame::UFTI2 - UFTI class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::UFTI2;

  $Frm = new ORAC::Frame::UFTI("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to UFTI post ORAC delivery. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::UFTI>
objects. Some additional methods are supplied.

=cut

# A package to describe a UFTI group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UFTI;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame::UFTI;
use base qw/ORAC::Frame::UFTI/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::UFTI2> object.
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

  # Replace prepend  '.', drop the suffix and append '.ok'
  my $suffix = $self->rawsuffix;
  $raw =~ s/$suffix$//;
  my $flag = ".$raw.ok";

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

=back

=head1 SEE ALSO

L<ORAC::Group>

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
