package ORAC::Calib::NACO;

=head1 NAME

ORAC::Calib::NACO;

=head1 SYNOPSIS

  use ORAC::Calib::NACO;

  $Cal = new ORAC::Calib::NACO;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying NACO-specific calibration
objects.  It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.  Written for Michelle and adapted for NACO.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Calib::CGS4;			# use base class
use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::CGS4/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

For NACO some of the rules files are keyed on the current value of
the CAMERA FITS header item.  This sub-class automatically changes the
rules file of the underlying index object.

=over 4

=item B<flatindex>

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


=head2 General Methods

=over 4

=item B<mask>

Return (or set) the name of the current mask. If a mask is to be returned 
every effrort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask($newmask);

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), C<$ORAC_DATA_CAL/bpm> is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut


sub mask {

  my $self = shift;

  if (@_) {
    return $self->maskname(shift);
  };

  my $ok = $self->maskindex->verify($self->maskname,$self->thing);

  # happy ending
  return $self->maskname if $ok;

  croak ("Override mask is not suitable! Giving up") if $self->masknoupdate;

  if (defined $ok) {

    my $mask = $self->maskindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $mask) {

      # Nothing suitable, default to fallback position
      # Check that exists and be careful not to set this as the
      # maskname() value since it has no corresponding index enrty
      my $defmask = $self->find_file("bpm.sdf");
      if( defined( $defmask ) ) {
        $defmask =~ s/\.sdf//;
        return $defmask;
      }

      # give up...
      croak "No suitable bad pixel mask was found in index file"
    }

    # Store the good value
    $self->maskname($mask);

  } else {

    # All fall down....
    croak("Error in determining bad pixel mask - giving up");
  }

}

=back

=head2 New methods

=over 4

=item B<_set_index_rules>

Internal method to modify the state of an index object to reflect
the camera mode of NACO.

  $Cal->_set_index_rules($index, $imaging_rules, $spec_rules);

ORAC_DATA_CAL is prepended if no path is provided.

Returns the index object.

=cut

sub _set_index_rules {

  my $self = shift;
  my $index = shift;
  my $im = shift;
  my $sp = shift;

  # Prefix ORAC_DATA_CAL if required
  # This is non-portable (kluge)
  $im = $self->find_file($im)
    unless $im =~ /\//;
  $sp = $self->find_file($sp)
    unless $sp =~ /\//;

  # Get the current name of the rules file in case we don't need to
  # update it
  my $current = $index->indexrulesfile;

  # Now change the rules file
  if (uc($self->thing->{"HIERARCH.ESO.DPR.TECH"}) eq 'IMAGE') {
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
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
