package ORAC::Frame::MichTemp;

=head1 NAME

ORAC::Frame::MichTemp - class for dealing with temporary Michelle observation files

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Frm = new ORAC::Frame::UKIRT("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to Michelle. The input files must be NDFs containing a single
data array (unlike the final Michelle data format).  It provides a
class derived from B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::MichTemp>
objects.

=cut

# A package to describe a MichTemp group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;
use warnings;
use 5.006;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;

# Let the object know that it is derived from ORAC::Frame;
use base qw/ORAC::Frame::UKIRT/;

$VERSION = '1.0';

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::MichTemp> object.  This
method also takes optional arguments: if 1 argument is supplied it is
assumed to be the name of the raw file associated with the
observation. If 2 arguments are supplied they are assumed to be the
raw file prefix and observation number. In any case, all arguments are
passed to the configure() method which is run in addition to new()
when arguments are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame::MichTemp;
   $Frm = new ORAC::Frame::MichTemp("file_name");
   $Frm = new ORAC::Frame::MichTemp("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'M' prefix although these can be overriden with the
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
  $self->rawfixedpart('M');
  $self->rawsuffix('.sdf');

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

The number is zero-padded to 5 characters.

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably for the MichTemp subclass.

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


=item B<findrecipe>

Find the recipe name. If a recipe name can not be found in the
header (searching for 'RECIPE') the 'ARRAY_ENG' recipe is assumed.

The recipe name stored in the object is automatically updated using
this value.

=cut

sub findrecipe {

  my $self = shift;

  my $recipe = $self->hdr('RECIPE');

  # Check to see whether there is something there
  # if not try to make something up
  if ($recipe !~ /./) {
    $recipe = 'ARRAY_ENG';
  }
  $self->recipe($recipe);

  return $recipe;

}


=item B<mergehdr>

Null method for compatibility with Michelle class

=cut


sub mergehdr {

}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

This method replaces the number in the supplied string with
the current frame number (padded with zeroes up to a length
of 5).

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

=back

=head1 SEE ALSO

L<ORAC::Frame::UKIRT>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
