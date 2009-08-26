package ORAC::Calib::IRIS2;

=head1 NAME

ORAC::Calib::IRIS2;

=head1 SYNOPSIS

  use ORAC::Calib::IRIS2;

  $Cal = new ORAC::Calib::IRIS2;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying IRIS2-specific calibration
objects. It provides a class derived from ORAC::Calib::ImagSpec.  All the
methods available to ORAC::Calib::ImagSpec objects are available to
ORAC::Calib::IRIS2 objects. Written for Michelle and adpated for UIST
and IRIS2.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;
use File::Copy;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

The following methods are available:

=head2 Accessors

=over 4

=item B<maskindex>

Return or set the index object associated with the bad pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {
  my $self = shift;

  if (@_) { $self->{MaskIndex} = shift; }

  # Switch on observation mode.
  if( $self->thingtwo->{ORAC_OBSERVATION_MODE} =~ /spectroscopy/ ) {
    $self->maskindex_sp( $self->{MaskIndex} );
  } else {
    $self->maskindex_im( $self->{MaskIndex} );
  }

  return $self->{MaskIndex};

};

sub maskindex_im {
  my $self = shift;

  if( @_ ) { $self->{MaskIndex} = shift; }

  if( ! defined( $self->{MaskIndex} ) ||
      $self->{MaskIndex}->indexfile !~ /_im$/ ) {

    # Copy the index file from ORAC_DATA_CAL into ORAC_DATA_OUT,
    # unless it already exists there. Then use the one in
    # ORAC_DATA_OUT.
    if( ! -e File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_im" ) ) {
      copy( $self->find_file( "index.mask_im" ),
            File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_im" ) );
    }
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_im" );
    my $rulesfile = $self->find_file( "rules.mask_im" );

    $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{MaskIndex};
}

sub maskindex_sp {
  my $self = shift;

  if( @_ ) { $self->{MaskIndex} = shift; }

  if( ! defined( $self->{MaskIndex} ) ||
      $self->{MaskIndex}->indexfile !~ /_sp$/ ) {

    # Copy the index file from ORAC_DATA_CAL into ORAC_DATA_OUT,
    # unless it already exists there. Then use the one in
    # ORAC_DATA_OUT.
    if( ! -e File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_sp" ) ) {
      copy( $self->find_file( "index.mask_sp" ),
            File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_sp" ) );
    }
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.mask_sp" );
    my $rulesfile = $self->find_file( "rules.mask_sp" );

    $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{MaskIndex};
}

=back

=head2 Index and Rules files

For IRIS2 some of the rules files are keyed on the current
value of the CAMERA FITS header item. This sub-class
automatically changes the rules file of the underlying index
object.

=over 4

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>

=cut

sub flatindex {
  my $self = shift;
  my $index = $self->SUPER::flatindex;
  $self->_set_index_rules($index, 'rules.flat_im', 'rules.flat_sp');
}

=back

=head2 General Methods

=over 4

=item B<default_mask>

Default mask depends on camera mode.

=cut

sub default_mask {
  my $self = shift;
  my $defmask = "bpm_fallback.sdf";

  # If we're in spectroscopy mode, over-ride this to be bpm_sp
  # $uhdrref is a reference to the Frame uhdr hash
  my $uhdrref = $self->thingtwo;
  if ($uhdrref->{'ORAC_OBSERVATION_MODE'} eq 'spectroscopy') {
    $defmask = "bpm_sp.sdf";
  }
  return $defmask;
}

=back

=head2 New methods

=over 4

=item B<is_imaging_mode>

Returns true if this observation should use an imaging (_im)
calibration.

=cut

sub is_imaging_mode {
  my $self = shift;
  return !$self->is_spectroscopy_mode;
}

=item B<is_spectroscopy_mode>

Returns true if this observation should use an imaging (_sp)
calibration.

=cut

sub is_spectroscopy_mode {
  my $self = shift;
  # SDR: We can only check what's in the grism wheel.
  return ((uc($self->thing->{IRS_GRSM}) eq 'SAPPHIRE_316') || (uc($self->thing->{IRS_GRSM}) eq 'SAPPHIRE_240'));
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Stuart Ryder E<lt>sdr@aaoepp.aao.gov.auE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
adapted for IRIS2 by S Ryder (Jan 2004)

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
