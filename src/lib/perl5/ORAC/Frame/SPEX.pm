package ORAC::Frame::SPEX;

=head1 NAME

ORAC::Frame::SPEX - SPEX class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::SPEX;

  $Frm = new ORAC::Frame::SPEX("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to SPEX.  It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::SPEX>
objects.  Some additional methods are supplied.

=cut

# A package to describe a SPEX group object for the ORAC pipeline.

# standard error module and turn on strict
use Carp;
use strict;
use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::SPEX> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::SPEX;
   $Frm = new ORAC::Frame::SPEX("file_name");
   $Frm = new ORAC::Frame::SPEX("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

   my $proto = shift;
   my $class = ref($proto) || $proto;

# Run the base class constructor with a hash reference defining
# additions to the class

# Do not supply user-arguments yet.  This is because if we do run
# configure via the constructor # the rawfixedpart and rawsuffix will
# be undefined.
   my $self = $class->SUPER::new();

# Configure initial state - could pass these in with the class
# initialisation hash - this assumes that we know  the hash member name.
   $self->rawfixedpart( 'spex' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.  Currently
# the argument will be the filename.  If there are two args this becomes
# a prefix and number.
   $self->configure(@_) if @_;

   return $self;

}

=back

=head2 General Methods

=over 4


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For SPEX the raw filename after pressing by spex2oracdr.csh is
of the form:

  spexYYYYMMDD_NNNNN.sdf

where the number NNNNN is 0 padded.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# Zero pad the number.
   $obsnum = sprintf( "%05d", $obsnum );

# Temporary SPEX UKIRT-like form form is fixed prefix _ num suffix
   return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
SPEX.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the SPEX case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = $self->pattern_from_bits($prefix, $obsnum);

  # Replace the 'f' with a '.' and append '.ok'
  substr($raw,0,1) = '.';
  $raw .= '.ok';
}

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

# Pad with leading zeroes for a 5-digit obsnum.
   $num = "0" x ( 5 - length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename.
   $self->file( $template );

}

=item B<mergehdr>

Dummy method.

  $frm->mergehdr();

=cut


=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
