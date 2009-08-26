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

use File::Copy;
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
  return $self->chooseindex( "flat", 0, @_ );
}

=item B<skyindex>

Uses F<rules.sky_im> and <rules.sky_sp>

=cut

sub skyindex {
  my $self = shift;
  return $self->chooseindex( "sky", 0, @_ );
}

=back

=head2 General Methods

=over 4

=item B<chooseindex>

Given a key root and knowledge that this is imaging or spectroscopy, choose
the correct index file. The key root should correspond to the names of
the index and rules files.

  $index = $Cal->choosindex( "flat" );

A second argument, if true, indicates that a pre-existing index file
can be copied from the calibration directory. If false it will just
define the index file to exist in the data directory.

  $index = $Cal->chooseindex( "flat", 1 );

Optionally can be given an index to store. It will be cached in the
correct slot.

  $index = $Cal->chooseindex( "flat", 1, $index );

In the latter case all 3 arguments must be provided.

=cut

sub chooseindex {
  my $self = shift;
  my $root = shift;
  my $docopy = shift;

  # Choose the correct slot and correct rules/index root
  my $key = ucfirst($root);
  my $indrul = $root;
  if ($self->is_imaging_mode() ) {
    $key .= "ImagingIndex";
    $indrul .= "_im";
  } else {
    $key .= "SpectroscopyIndex";
    $indrul .= "_sp";
  }

  # Store any supplied argument
  if (@_) {
    $self->{$key} = shift;
  }

  # Now create one if required
  if (!defined $self->{$key}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.$indrul" );
    if( $docopy && ! -e $indexfile ) {
      copy( $self->find_file( "index.mask_im" ), $indexfile );
    }
    my $rulesfile = $self->find_file("rules.$indrul");
    $self->{$key} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{$key};
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
