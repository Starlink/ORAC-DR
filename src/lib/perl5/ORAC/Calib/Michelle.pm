package ORAC::Calib::Michelle;

=head1 NAME

ORAC::Calib::Michelle;

=head1 SYNOPSIS

  use ORAC::Calib::Michelle;

  $Cal = new ORAC::Calib::Michelle;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying Michelle-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Calib::CGS4;			# use base class
use ORAC::Print;

use base qw/ORAC::Calib::CGS4/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


=head1 METHODS

=head2 Index and Rules files

For Michelle some of the rules files are keyed on the
current value of the CAMERA FITS header item. This sub-class
automatically changes the rules file of the underlying index
object.

=over 4

=item B<standardindex>

Uses F<rules.standard_im> and <rules.standard_sp>

=cut

sub standardindex {
  my $self = shift;
  my $index = $self->SUPER::standardindex;

  # in principal we could always call this from the base class
  # and simply use a no-op method. Problem is that for michelle only
  # some of the index files need this trickery
  $self->_set_index_rules($index, 'rules.standard_im', 'rules.standard_sp');
}

=item B<standardindex>

Uses F<rules.flat_im> and <rules.flat_sp>

=cut


sub flatindex {
  my $self = shift;
  my $index = $self->SUPER::flatindex;
  $self->_set_index_rules($index, 'rules.flat_im', 'rules.flat_sp');
}

=item B<skyindex>

Uses F<rules.sky_im> and <rules.sky_sp>

=cut


sub skyindex {
  my $self = shift;
  my $index = $self->SUPER::skyindex;
  $self->_set_index_rules($index, 'rules.sky_im', 'rules.sky_sp');
}




=back

=head2 New methods

=over 4

=item B<_set_index_rules>

Internal method to modify the state of an index object to reflect
the camera mode of Michelle.

  $Cal->_set_index_rules($index, $imaging_rules, $spec_rules);

Returns the index object.

=cut

sub _set_index_rules {

  my $self = shift;
  my $index = shift;
  my $im = shift;
  my $sp = shift;

  # Get the current name of the rules file in case we don't need to
  # update it
  my $current = $index->indexrulesfile;

  # Now change the rules file
  if ($self->thing->{CAMERA} eq 'IMAGING') {
    $index->indexrulesfile($im)
      unless $im eq $current;
  } else {
    $index->indexrulesfile($sp)
      unless $sp eq $current;
  }
  # and return the object
  return $index;
}


=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
