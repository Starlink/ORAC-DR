package ORAC::Calib::Imaging;

=head1 NAME

ORAC::Calib::Imaging - OIR Imaging Calibration

=head1 SYNOPSIS

  use ORAC::Calib::Imaging;

  $Cal = new ORAC::Calib::Imaging;

=head1 DESCRIPTION

Imaging specific calibration methods.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use File::Spec;

use base qw/ ORAC::Calib::OIR /;

$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors( baseshift => { isarray => 1 },
                                   dqc => {},
                                   polrefang => {},
                                   referenceoffset => { isarray => 1 },
                                   skybrightness => {},
                                   zeropoint => {} );

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Accessor Methods

=over 4

=item B<baseshift>

Determine the pixel indices of the base position to be used for the
current observation.  This allows for incorrect instrument apertures.
In theory a 0;0 offset should place a source at the base position.
This method returns a semicolon-separated doublet "x;y" string rather
than a particular file even though it uses an index file.  Semicolon
is used to avoid problems with command-line parsing.

Croaks if it was not possible to determine a valid base location
(usually indicating that a standard has not been observed).

  $base = $Cal->baseshift;

The index file is queried every time (usually not a problem since the
index is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the base
location meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include a column named BASESHIFT.

=cut

sub baseshift {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "baseshift", "BASESHIFT", @_ );
}

=item B<polrefang>

Determine the anti-clockwise angle of the first (X) axis to the
polarimeter reference direction.  This, in essence, is the angle in
degrees to correct the measured positional angles to their true
orientations, thereby allowing for instrumental misalignment.

Croaks if it was not possible to determine a valid angle.

  $angle = $Cal->polrefang;

The index file is queried every time (usually not a problem since the
index is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the
polarisation reference angle meets the specified rules (this is because
the command-line override uses a value rather than a file).

The index file must include a column named POLREFANG.

=cut

sub polrefang {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "polrefang", "POLREFANG", @_ );
}

=item B<referenceoffset>

Determine the pixel offsets of the reference pixel with respect to the
frame centre to be used for the current observation.  This allows for 
the source to be placed away from the centre avoiding defects and the
joins of quadrants.

This method returns a semicolon-separated doublet "x;y" string rather than
a particular file even though it uses an index file.  Semicolon is
used to avoid problems with command-line parsing.

In theory a 0;0 offset should place the reference position at the
centre of the frame.  When this is not the case because of say poor
co-ordinates of the source, or incorrect instrument apertures,
calibration baseshift may be used, which in essence, measures the
displacement of the reference position from nominal.

Croaks if it was not possible to determine a valid reference pixel.

  $shift = $Cal->referenceoffset;

The index file is queried every time (usually not a problem since the
index is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the base
location meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include a column named REFERENCEOFFSET.

=cut

sub referenceoffset {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "referenceoffset", "REFERENCEOFFSET", @_ );
}

=item B<default_rotation_file>

Returns the name of the default rotation transformation matric file.

Returns undef by default.

=cut

sub default_rotation_file {
  return undef;
}

=item B<rotation>

Return (or set) the name of the rotation transformation matrix

  $rotation = $Cal->rotation;

If specified, the default value will be obtained using the method
C<default_rotation_file>.

=cut

sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }

  unless (defined $self->{Rotation}) {
    my $def = $self->default_rotation_file;
    if (defined $def) {
      my $rotation = $self->find_file($def);
      if( defined( $rotation ) ) { $rotation =~ s/\.sdf//; }
      $self->{Rotation} = $rotation;
    }
  };

  return $self->{Rotation};
}

=item B<skybrightness>

Determine the sky brightness to be used for the current observation.
This method returns a number rather than a particular file even though
it uses an index file.

Croaks if it was not possible to determine a valid sky brightness,
which usually indicates that photometric calculations have not been
made.

  $skybrightness = $Cal->skybrightness;

The index file is queried every time unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the sky
brightness meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include a column named SKY_BRIGHTNESS.

=cut

sub skybrightness {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "skybrightness", "SKY_BRIGHTNESS", @_ );
}

=item B<zeropoint>

Determine the zeropoint to be used for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid zeropoint, which
usually indicating that an _APHOT recipe was not run.

  $zeropoint = $Cal->zeropoint;

The index file is queried every time unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the
readnoise meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include a column named ZEROPOINT.

=cut

sub zeropoint {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "zeropoint", "ZEROPOINT", @_ );
}

=back

=head2 Support Methods

Each of the methods above has a support implementation to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

=head1 SEE ALSO

L<ORAC::Calib::OIR> and
L<ORAC::Calib::Spectroscopy> 

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
