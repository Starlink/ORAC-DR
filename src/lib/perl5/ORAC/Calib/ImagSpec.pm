package ORAC::Calib::ImagSpec;

=head1 NAME

ORAC::Calib::ImageSpec;

=head1 SYNOPSIS

  use ORAC::Calib::ImagSpec;

  $Cal = new ORAC::Calib::ImagSpec;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying calibration objects
that are both imaging and spectroscopic.
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib::Imaging and ORAC::Calib::Spectroscopy
objects are available to ORAC::Calib::ImagSpec objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::Imaging ORAC::Calib::Spectroscopy/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

For Michelle and UIST some of the rules files are keyed on the
current value of the CAMERA FITS header item. This sub-class
automatically changes the rules file of the underlying index
object.

=over 4

=item B<default_mask>

Default mask may depend on observation mode. Default bpm.sdf
unless we are in spectroscopy mode and a bpm_sp.sdf is available.

=cut

sub default_mask {
  my $self = shift;
  my $defmask = "bpm.sdf";
  my $uhdrref = $self->thingtwo;
  if ($self->is_spectroscopy_mode) {
    my $spmask = $self->find_file("bpm_sp.sdf");
    $defmask = $spmask if defined $spmask;
  }
  return $defmask;
}

=item B<is_imaging_mode>

Returns true if this observation should use an imaging (_im)
calibration.

The base class checks ORAC_OBSERVATION_MODE for the string "imag".

=cut

sub is_imaging_mode {
  my $self = shift;
  return $self->thingtwo->{ORAC_OBSERVATION_MODE} =~ /imag/i;
}

=item B<is_spectroscopy_mode>

Returns true if this observation should use an imaging (_sp)
calibration.

The base class checks ORAC_OBSERVATION_MODE for the string "spec".

=cut

sub is_spectroscopy_mode {
  my $self = shift;
  return $self->thingtwo->{ORAC_OBSERVATION_MODE} =~ /spec/i;
}

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>, and sets the index
file for imaging mode to be F<index.flat_im> and for spectroscopy
and IFU to be F<index.flat_sp>.

=cut


sub flatindex {
  my $self = shift;

  if (@_) { $self->{FlatIndex} = shift; }

  if( $self->is_imaging_mode() ) {
    $self->flatindex_im( $self->{FlatIndex} );
  } else {
    $self->flatindex_sp( $self->{FlatIndex} );
  }

  return $self->{FlatIndex};

}

sub flatindex_im {
  my $self = shift;

  if( @_ ) { $self->{FlatIndex} = shift; }

  if( !defined( $self->{FlatIndex} ) ||
      $self->{FlatIndex}->indexfile !~ /_im$/ ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.flat_im" );
    my $rulesfile = $self->find_file("rules.flat_im");
    $self->{FlatIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{FlatIndex};
}

sub flatindex_sp {
  my $self = shift;

  if( @_ ) { $self->{FlatIndex} = shift; }

  if( !defined( $self->{FlatIndex} ) ||
      $self->{FlatIndex}->indexfile !~ /_sp$/ ) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.flat_sp" );
    my $rulesfile = $self->find_file("rules.flat_sp");
    $self->{FlatIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{FlatIndex};
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

=item B<_set_index_rules>

Internal method to modify the state of an index object to reflect
the camera mode of Michelle or UIST.

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
  if ($self->is_imaging_mode) {
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

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
adapted for UIST by S Todd (Dec 2001)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
