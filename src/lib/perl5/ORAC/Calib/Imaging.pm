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

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib::Imaging object.
The object identifier is returned.

  $Cal = new ORAC::Calib::Imaging;

=cut

sub new {

  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

  $obj->{BaseShift} = undef;
  $obj->{DQC} = undef;
  $obj->{PolRefAng} = undef;
  $obj->{ReferenceOffset} = undef;
  $obj->{Rotation} = undef;
  $obj->{SkyBrightness} = undef;
  $obj->{Zeropoint} = undef;

  $obj->{BaseShiftIndex} = undef;
  $obj->{DQCIndex} = undef;
  $obj->{PolRefAngIndex} = undef;
  $obj->{ReferenceOffsetIndex} = undef;
  $obj->{RotationIndex} = undef;
  $obj->{SkyBrightnessIndex} = undef;
  $obj->{ZeropointIndex} = undef;

  $obj->{BaseShiftNoUpdate} = 0;
  $obj->{PolRefAngNoUpdate} = 0;
  $obj->{ReferenceShiftNoUpdate} = 0;
  $obj->{SkyBrightnessNoUpdate} = 0;
  $obj->{ZeropointNoUpdate} = 0;

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=cut

# Methods to access the data.
# ---------------------------

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

  # Handle arguments
  return $self->baseshiftcache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined.  This effectively allows the command-line
  # value to be used to override without verifying its suitability.
  if ($self->baseshiftnoupdate) {
    my $cache = $self->baseshiftcache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $basefile = $self->baseshiftindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable pixel location of the base found in index file."
    unless defined $basefile;

  # This gives us the filename, we now need to get the actual value
  # of the pixel location of the base.
  my $baseref = $self->baseshiftindex->indexentry( $basefile );
  if (exists $baseref->{BASESHIFT}) {
    return $baseref->{BASESHIFT};
  } else {
    croak "Unable to obtain BASESHIFT from index file entry $basefile.\n";
  }

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

  # Handle arguments
  return $self->polrefangcache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined.  This effectively allows the command-line
  # value to be used to override without verifying its suitability.
  if ($self->polrefangnoupdate) {
    my $cache = $self->polrefangcache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $prafile = $self->polrefangindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable angle to the polarisation reference direction " .
        "found in index file."
    unless defined $prafile;

  # This gives us the filename, we now need to get the actual value
  # of the angle to the reference direction.
  my $polref = $self->polrefangindex->indexentry( $prafile );
  if (exists $polref->{POLREFANG}) {
    return $polref->{POLREFANG};
  } else {
    croak "Unable to obtain POLREFANG from index file entry $prafile.\n";
  }

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

  # Handle arguments
  return $self->referenceoffsetcache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined.  This effectively allows the command-line
  # value to be used to override without verifying its suitability.
  if ($self->referenceoffsetnoupdate) {
    my $cache = $self->referenceoffsetcache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file.
  my $refofffile = $self->referenceoffsetindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable offset of the reference pixel found in index file."
    unless defined $refofffile;

  # This gives us the filename, we now need to get the actual value
  # of the pixel offsets of the reference pixel.
  my $refoffref = $self->referenceoffsetindex->indexentry( $refofffile );
  if (exists $refoffref->{REFERENCEOFFSET}) {
    return $refoffref->{REFERENCEOFFSET};
  } else {
    croak "Unable to obtain REFERENCEOFFSET from index file entry $refofffile.\n";
  }

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

  # Handle arguments
  return $self->skybrightnesscache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined. This effectively allows the command-line
  # value to be used to override without verifying its suitability
  if ($self->skybrightnessnoupdate) {
    my $cache = $self->skybrightnesscache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $sbfile = $self->skybrightnessindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable sky brightness value found in index file"
    unless defined $sbfile;

  # This gives us the filename, we now need to get the actual value
  # of the sky brightness.
  my $noiseref = $self->skybrightnessindex->indexentry( $sbfile );
  if (exists $noiseref->{SKY_BRIGHTNESS}) {
    return $noiseref->{SKY_BRIGHTNESS};
  } else {
    croak "Unable to obtain SKY_BRIGHTNESS from index file entry $sbfile\n";
  }

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

  # Handle arguments
  return $self->zeropointcache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined. This effectively allows the command-line
  # value to be used to override without verifying its suitability
  if ($self->zeropointnoupdate) {
    my $cache = $self->zeropointcache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $zpfile = $self->zeropointindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable zeropoint value found in index file"
    unless defined $zpfile;

  # This gives us the filename, we now need to get the actual value of
  # the zeropoint.
  my $zpref = $self->zeropointindex->indexentry( $zpfile );
  if (exists $zpref->{ZEROPOINT}) {
    return $zpref->{ZEROPOINT};
  } else {
    croak "Unable to obtain ZEROPOINT from index file entry $zpfile\n";
  }

}

# *name methods
# -------------
# Used when a file name is required.

# *cache methods
# --------------
# Used when a value or values (rather than a file) is required.

=item B<baseshiftcache>

Cached value of the baseshift.  Only used when noupdate is in effect.

=cut

sub baseshiftcache {
  my $self = shift;
  my @values;
  if ( ref($_[0]) eq 'ARRAY' ) {
     @values = @{ $_[0] };
  } else {
     @values = ( $_[0] );
  }
                  
  if (@_) { $self->{BaseShift} = \@values unless $self->baseshiftnoupdate; }
  return $self->{BaseShift};
}

=item B<polrefangcache>

Cached value of the angle to the polarisation reference direction.  Only
used when noupdate is in effect.

=cut

sub polrefangcache {
  my $self = shift;
  if (@_) { $self->{PolRefAng} = shift unless $self->polrefangnoupdate; }
  return $self->{PolRefAng};
}

=item B<referenceoffsetcache>

Cached value of the referenceoffset.  Only used when noupdate is in effect.

=cut

sub referenceoffsetcache {
  my $self = shift;
  my @values;
  if ( ref($_[0]) eq 'ARRAY' ) {
     @values = @{ $_[0] };
  } else {
     @values = ( $_[0] );
  }

  if (@_) { $self->{ReferenceOffset} = \@values unless $self->referenceoffsetnoupdate; }
  return $self->{ReferenceOffset};
}

=item B<zeropointcache>

Cached value of the zeropoint.  Only used when noupdate is in effect.

=cut

sub zeropointcache {
  my $self = shift;
  if (@_) { $self->{Zeropoint} = shift unless $self->zeropointnoupdate; }
  return $self->{Zeropoint};
}

# *noupdate methods
# -----------------

=item B<baseshiftnoupdate>

Stops baseshift object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub baseshiftnoupdate {
  my $self = shift;
  if (@_) { $self->{BaseShiftNoUpdate} = shift; }
  return $self->{BaseShiftNoUpdate};
}

=item B<polrefangnoupdate>

Stops polrefang object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub polrefangnoupdate {
  my $self = shift;
  if (@_) { $self->{PolRefAngNoUpdate} = shift; }
  return $self->{PolRefAngNoUpdate};
}

=item B<referenceoffsetnoupdate>

Stops referenceoffset object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub referenceoffsetnoupdate {
  my $self = shift;
  if (@_) { $self->{ReferenceOffsetNoUpdate} = shift; }
  return $self->{ReferenceOffsetNoUpdate};
}

=item B<skybrightnessnoupdate>

Stops sky brightness object from updating itself with more recent
data.

Used when using a command-line override to the pipeline.

=cut

sub skybrightnessnoupdate {
  my $self = shift;
  if (@_) { $self->{SkyBrightnessNoUpdate} = shift; }
  return $self->{SkyBrightnessNoUpdate};
}

=item B<zeropointnoupdate>

Stops zeropoint object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub zeropointnoupdate {
  my $self = shift;
  if (@_) { $self->{ZeropointNoUpdate} = shift; }
  return $self->{ZeropointNoUpdate};
}

# *index methods
# --------------

=item B<baseshiftindex>

Return (or set) the index object associated with the baseshift index file.

=cut

sub baseshiftindex {

  my $self = shift;
  if (@_) { $self->{BaseShiftIndex} = shift; }

  unless (defined $self->{BaseShiftIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.baseshift" );
    my $rulesfile = $self->find_file("rules.baseshift");
    croak "baseshift rules file could not be located\n" unless defined $rulesfile;
    $self->{BaseShiftIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{BaseShiftIndex};
}

=item B<dqcindex>

Return (or set) the index object associated with the data quality
parameters index file.

=cut

sub dqcindex {

  my $self = shift;
  if (@_) { $self->{DQCIndex} = shift; }

  unless (defined $self->{DQCIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.dqc" );
    my $rulesfile = $self->find_file("rules.dqc");
    croak "dqc rules file could not be located\n" unless defined $rulesfile;
    $self->{DQCStats} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{DQCStats};

}

=item B<polrefangindex>

Return (or set) the index object associated with the polrefang index file.
The index is static, therefore it resides in the calibration directory.

=cut

sub polrefangindex {

  my $self = shift;
  if (@_) { $self->{PolRefAngIndex} = shift; }

  unless (defined $self->{PolRefAngIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_CAL}, "index.polrefang" );
    my $rulesfile = $self->find_file("rules.polrefang");
    croak "polrefang rules file could not be located\n"
      unless defined $rulesfile;
    $self->{PolRefAngIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{PolRefAngIndex};
}

=item B<referenceoffsetindex>

Return (or set) the index object associated with the referenceoffset index file.

=cut

sub referenceoffsetindex {

  my $self = shift;
  if (@_) { $self->{ReferenceOffsetIndex} = shift; }

  unless (defined $self->{ReferenceOffsetIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.referenceoffset" );
    my $rulesfile = $self->find_file("rules.referenceoffset");
    croak "referenceoffset rules file could not be located\n"
      unless defined $rulesfile;
    $self->{ReferenceOffsetIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ReferenceOffsetIndex};
}

=item B<skybrightnessindex>

Return (or set) the index object associated with the sky brightness
index file.

=cut

sub skybrightnessindex {

  my $self = shift;
  if (@_) { $self->{SkyBrightnessIndex} = shift; }

  unless (defined $self->{SkyBrightnessIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.skybrightness" );
    my $rulesfile = $self->find_file("rules.skybrightness");
    $self->{SkyBrightnessIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{SkyBrightnessIndex};
}

=item B<zeropointindex>

Return (or set) the index object associated with the zeropoint index file.

=cut

sub zeropointindex {

  my $self = shift;
  if (@_) { $self->{ZeropointIndex} = shift; }

  unless (defined $self->{ZeropointIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.zeropoint" );
    my $rulesfile = $self->find_file("rules.zeropoint");
    $self->{ZeropointIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ZeropointIndex};
}

=back

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
