package ORAC::Calib;

=head1 NAME

ORAC::Calib - base class for selecting calibration frames in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Calib;

  $Cal = new ORAC::Calib;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Calib
objects.  This class should be used for selecting calibration frames.

Unless specified otherwise, a calibration frame is selected by first,
the nearest reduced frame; second, explicit specification via the
-calib command line option (handled by the pipeline); third, by search
of the appropriate index file.

Note this version: Index files not implemented.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use ORAC::Inst::Defn qw/ orac_determine_calibration_search_path /;
use File::Spec;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Cal = new ORAC::Calib;

=cut

# NEW - create new instance of Calib.

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};  # Anon hash reference
  $obj->{Thing1} = {};		# ditto
  $obj->{Thing2} = {};		# ditto

  $obj->{Arc} = undef;
  $obj->{BaseShift} = undef;
  $obj->{Bias} = undef;
  $obj->{CalibratedArc} = undef;
  $obj->{Dark} = undef;
  $obj->{Emissivity} = undef;
  $obj->{Flat} = undef;
  $obj->{Mask} = undef;
  $obj->{PolRefAng} = undef;
  $obj->{ReadNoise} = undef;
  $obj->{ReferenceOffset} = undef;
  $obj->{Rotation} = undef;
  $obj->{Sky} = undef;
  $obj->{Standard} = undef;
  $obj->{Zeropoint} = undef;

  $obj->{ArcIndex} = undef;
  $obj->{BaseShiftIndex} = undef;
  $obj->{BiasIndex} = undef;
  $obj->{CalibratedArcIndex} = undef;
  $obj->{DarkIndex} = undef;
  $obj->{EmissivityIndex} = undef;
  $obj->{FlatIndex} = undef;
  $obj->{PolRefAngIndex} = undef;
  $obj->{ReadNoiseIndex} = undef;
  $obj->{SkyIndex} = undef;
  $obj->{StandardIndex} = undef;
  $obj->{ZeropointIndex} = undef;

  $obj->{ArcNoUpdate} = 0;
  $obj->{BaseShiftNoUpdate} = 0;
  $obj->{BiasNoUpdate} = 0;
  $obj->{DarkNoUpdate} = 0;
  $obj->{EmissivityNoUpdate} = 0;
  $obj->{FlatNoUpdate} = 0;
  $obj->{PolRefAngNoUpdate} = 0;
  $obj->{ReadNoiseNoUpdate} = 0;
  $obj->{ReferenceShiftNoUpdate} = 0;
  $obj->{SkyNoUpdate} = 0;
  $obj->{ZeropointNoUpdate} = 0;

  # Used in UIST IFU reduction
  $obj->{Arlines} = undef;
  $obj->{ArlinesIndex} = undef;
  $obj->{Iar} = undef;
  $obj->{IarIndex} = undef;
  $obj->{Offset} = undef;
  $obj->{OffsetIndex} = undef;

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4


# Methods to access the data.
# ---------------------------

=item B<arc>

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

=cut

sub arc {
  my $self = shift;
  if (@_) { 
    # if we are setting, accept the value and return
    return $self->arcname(shift);
  };

  my $ok = $self->arcindex->verify($self->arcname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->arcname};

  croak("Override arc is not suitable! Giving up") if $self->arcnoupdate;

  # not so good
  if (defined $ok) {
    my $arc = $self->arcindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable arc was found in index file"
      unless defined $arc;
    $self->arcname($arc);
  } else {
    croak("Error in arc calibration checking - giving up");
  };
};


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


=item B<bias>

Return (or set) the name of the current bias.

  $bias = $Cal->bias;

=cut

sub bias {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->biasname(shift);
  };

  my $ok = $self->biasindex->verify($self->biasname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->biasname};

  croak("Override bias is not suitable! Giving up") if $self->biasnoupdate;

  # not so good
  if (defined $ok) {
    my $bias = $self->biasindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable bias calibration was found in index file"
      unless defined $bias;
    $self->biasname($bias);
  } else {
    croak("Error in bias calibration checking - giving up");
  };
};

=item B<dark>

Return (or set) the name of the current dark - 
checks suitability on return.

=cut


sub dark {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->darkname(shift);
  };

  my $ok = $self->darkindex->verify($self->darkname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->darkname};

  croak("Override dark is not suitable! Giving up") if $self->darknoupdate;

  # not so good
  if (defined $ok) {
    my $dark = $self->darkindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable dark calibration was found in index file"
      unless defined $dark;
    $self->darkname($dark);
  } else {
    croak("Error in dark calibration checking - giving up");
  };
};

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

=cut


sub flat {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->flatname(shift);
  };

  my $ok = $self->flatindex->verify($self->flatname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->flatname};

  croak("Override flat is not suitable! Giving up") if $self->flatnoupdate;

  # not so good
  if (defined $ok) {
    my $flat = $self->flatindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable flat was found in index file"
      unless defined $flat;
    $self->flatname($flat);
  } else {
    croak("Error in flat calibration checking - giving up");
  };
};


=item B<mask>

Return (or set) the name of the bad pixel mask

  $mask = $Cal->mask;

=cut

sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }
  return $self->{Mask};
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


=item B<readnoise>

Determine the readnoise to be used for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid readnoise.
(usually indicating that ARRAY_TESTS have not been reduced).

  $readnoise = $Cal->readnoise;

The index file is queried every time (usually not a problem since there
are only a limited number of array tests per night and the index
is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the readnoise
meets the specified rules (this is because the command-line override
uses a value rather than a file).

The index file must include a column named READNOISE.

=cut

sub readnoise {
  my $self = shift;

  # Handle arguments
  return $self->readnoisecache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined. This effectively allows the command-line
  # value to be used to override without verifying its suitability
  if ($self->readnoisenoupdate) {
    my $cache = $self->readnoisecache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $noisefile = $self->readnoiseindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable readnoise value found in index file"
    unless defined $noisefile;

  # This gives us the filename, we now need to get the actual value
  # of the readnoise.
  my $noiseref = $self->readnoiseindex->indexentry( $noisefile );
  if (exists $noiseref->{READNOISE}) {
    return $noiseref->{READNOISE};
  } else {
    croak "Unable to obtain READNOISE from index file entry $noisefile\n";
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


=item B<rotation>

Return (or set) the name of the rotation transformation matrix

  $rotation = $Cal->rotation;

=cut

sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }
  return $self->{Rotation};
}


=item B<sky>

Return (or set) the name of the current "sky" frame

=cut

sub sky {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->skyname(shift);
  };

  my $ok = $self->skyindex->verify($self->skyname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->skyname};

  croak("Override sky is not suitable! Giving up") if $self->skynoupdate;

  # not so good
  if (defined $ok) {
    my $sky= $self->skyindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable sky frame was found in index file"
      unless defined $sky;
    $self->skyname($sky);
  } else {
    croak("Error in sky frame calibration checking - giving up");
  };
};


=item B<standard>

Return (or set) the name of the current standard.

  $standard = $Cal->standard;

=cut

sub standard {

  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->standardname(shift);
  };

  my $ok = $self->standardindex->verify($self->standardname,$self->thing);

  # happy ending - frame is ok
  if ($ok) {return $self->standardname};

  croak("Override standard is not suitable! Giving up") if $self->standardnoupdate;

  # not so good
  if (defined $ok) {
    my $standard= $self->standardindex->choosebydt('ORACTIME',$self->thing);
    croak "No suitable standard frame was found in index file"
      unless defined $standard;
    $self->standardname($standard);
  } else {
    croak("Error in standard calibration checking - giving up");
  };

}


=item B<zeropoint>

Determine the photometric zeropoint to be used for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid zeropoint.
(usually indicating that a standard star has not been reduced).

  $zeropoint = $Cal->zeropoint;

The index file is queried every time (usually not a problem since there
are only a limited number of standard stars per night and the index
is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the zeropoint
meets the specified rules (this is because the command-line override
uses a value rather than a file).

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
  my $zeropointfile = $self->zeropointindex->choosebydt('ORACTIME',$self->thing);
  croak "No suitable zeropoint value found in index file"
    unless defined $zeropointfile;

  # This gives us the filename, we now need to get the actual value
  # of the readnoise.
  my $zeropointref = $self->zeropointindex->indexentry( $zeropointfile );
  if (exists $zeropointref->{ZEROPOINT}) {
    return $zeropointref->{ZEROPOINT};
  } else {
    croak "Unable to obtain ZEROPOINT from index file entry $zeropointfile\n";
  }

}

# *name methods
# -------------
# Used when a file name is required.

=item B<arcname>

Return (or set) the name of the current arc---no checking.

  $arc = $Cal->arcname;


=cut

sub arcname {
  my $self = shift;
  if (@_) { $self->{Arc} = shift unless $self->arcnoupdate; }
  return $self->{Arc};
}

=item B<biasname>

Return (or set) the name of the current bias---no checking.

  $dark = $Cal->biasname;


=cut

sub biasname {
  my $self = shift;
  if (@_) { $self->{Bias} = shift unless $self->biasnoupdate; }
  return $self->{Bias};
}

=item B<darkname>

Return (or set) the name of the current dark--no checking.

  $dark = $Cal->darkname;


=cut

sub darkname {
  my $self = shift;
  if (@_) { $self->{Dark} = shift unless $self->darknoupdate; }
  return $self->{Dark};
}

=item B<flatname>

Return (or set) the name of the current flat---no checking.

  $flat = $Cal->flatname;


=cut

sub flatname {
  my $self = shift;
  if (@_) { $self->{Flat} = shift unless $self->flatnoupdate; }
  return $self->{Flat};
}

=item B<skyname>

Return (or set) the name of the current sky frame---no checking.

  $dark = $Cal->skyname;


=cut

sub skyname {
  my $self = shift;
  if (@_) { $self->{Sky} = shift unless $self->skynoupdate; }
  return $self->{Sky};
}

=item B<standardname>

Return (or set) the name of the current standard frame---no checking.

  $dark = $Cal->standardname;


=cut

sub standardname {
  my $self = shift;
  if (@_) { $self->{Standard} = shift unless $self->standardnoupdate; }
  return $self->{Standard};
}


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

=item B<readnoisecache>

Cached value of the readnoise.  Only used when noupdate is in effect.

=cut

sub readnoisecache {
  my $self = shift;
  if (@_) { $self->{ReadNoise} = shift unless $self->readnoisenoupdate; }
  return $self->{ReadNoise};
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

Cached value of the zeropoint. Only used when noupdate is in effect.

=cut

sub zeropointcache {
  my $self = shift;
  if (@_) { $self->{Zeropoint} = shift unless $self->zeropointnoupdate; }
  return $self->{Zeropoint};
}


# *noupdate methods
# -----------------

=item B<arcnoupdate>

Stops arc object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub arcnoupdate {
  my $self = shift;
  if (@_) { $self->{ArcNoUpdate} = shift; }
  return $self->{ArcNoUpdate};
}


=item B<baseshiftnoupdate>

Stops baseshift object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub baseshiftnoupdate {
  my $self = shift;
  if (@_) { $self->{BaseShiftNoUpdate} = shift; }
  return $self->{BaseShiftNoUpdate};
}


=item B<biasnoupdate>

Stops bias object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub biasnoupdate {
  my $self = shift;
  if (@_) { $self->{BiasNoUpdate} = shift; }
  return $self->{BiasNoUpdate};
}


=item B<darknoupdate>

Stops dark object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub darknoupdate {
  my $self = shift;
  if (@_) { $self->{DarkNoUpdate} = shift; }
  return $self->{DarkNoUpdate};
}

=item B<flatnoupdate>

Stops flat object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub flatnoupdate {
  my $self = shift;
  if (@_) { $self->{FlatNoUpdate} = shift; }
  return $self->{FlatNoUpdate};
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

=item B<readnoisenoupdate>

Stops readnoise object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub readnoisenoupdate {
  my $self = shift;
  if (@_) { $self->{ReadNoiseNoUpdate} = shift; }
  return $self->{ReadNoiseNoUpdate};
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


=item B<skynoupdate>

Stops sky object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub skynoupdate {
  my $self = shift;
  if (@_) { $self->{SkyNoUpdate} = shift; }
  return $self->{SkyNoUpdate};
}

=item B<standardnoupdate>

Stops standard object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub standardnoupdate {
  my $self = shift;
  if (@_) { $self->{StandardNoUpdate} = shift; }
  return $self->{StandardNoUpdate};
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

=item B<arcindex>

Return (or set) the index object associated with the arc index file

=cut

sub arcindex {

  my $self = shift;
  if (@_) { $self->{ArcIndex} = shift; }

  unless (defined $self->{ArcIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.arc" );
    my $rulesfile = $self->find_file("rules.arc");
    $self->{ArcIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{ArcIndex}; 


};

=item B<baseshiftindex>

Return (or set) the index object associated with the baseshift index file.

=cut

sub baseshiftindex {

  my $self = shift;
  if (@_) { $self->{BaseShiftIndex} = shift; }

  unless (defined $self->{BaseShiftIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.baseshift" );
    my $rulesfile = $self->find_file("rules.baseshift");
    $self->{BaseShiftIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{BaseShiftIndex};
}

=item B<biasindex> 

Return (or set) the index object associated with the bias index file

=cut

sub biasindex {

  my $self = shift;
  if (@_) { $self->{BiasIndex} = shift; }

  unless (defined $self->{BiasIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.bias" );
    my $rulesfile = $self->find_file("rules.bias");
    $self->{BiasIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{BiasIndex}; 

};

=item B<darkindex> 

Return (or set) the index object associated with the dark index file

=cut

sub darkindex {

  my $self = shift;
  if (@_) { $self->{DarkIndex} = shift; }

  unless (defined $self->{DarkIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.dark" );
    my $rulesfile = $self->find_file("rules.dark");
    $self->{DarkIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{DarkIndex}; 


};

=item B<flatindex>

Return (or set) the index object associated with the flat index file

=cut

sub flatindex {

  my $self = shift;
  if (@_) { $self->{FlatIndex} = shift; }

  unless (defined $self->{FlatIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.flat" );
    my $rulesfile = $self->find_file("rules.flat");
    $self->{FlatIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{FlatIndex}; 


};

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
    $self->{PolRefAngIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{PolRefAngIndex};
}

=item B<readnoiseindex>

Return (or set) the index object associated with the readnoise index file.

=cut

sub readnoiseindex {

  my $self = shift;
  if (@_) { $self->{ReadNoiseIndex} = shift; }

  unless (defined $self->{ReadNoiseIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.readnoise" );
    my $rulesfile = $self->find_file("rules.readnoise");
    $self->{ReadNoiseIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ReadNoiseIndex};
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
    $self->{ReferenceOffsetIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ReferenceOffsetIndex};
}


=item B<skyindex>

Return (or set) the index object associated with the sky index file

=cut

sub skyindex {

  my $self = shift;
  if (@_) { $self->{SkyIndex} = shift; }

  unless (defined $self->{SkyIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.sky" );
    my $rulesfile = $self->find_file("rules.sky");
    $self->{SkyIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{SkyIndex};
};

=item B<standardindex> 

Return (or set) the index object associated with the standard index file

=cut

sub standardindex {

  my $self = shift;
  if (@_) { $self->{StandardIndex} = shift; }

  unless (defined $self->{StandardIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.standard" );
    my $rulesfile = $self->find_file("rules.standard");
    $self->{StandardIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{StandardIndex}; 


};

=item B<zeropointindex>

Return (or set) the index object associated with the zeropoint index file.

=cut

sub zeropointindex {

  my $self = shift;
  if (@_) { $self->{ZeropointIndex} = shift; }

  unless (defined $self->{ZeropointIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.zeropoint" );
    my $rulesfile = $self->find_file( "rules.zeropoint" );
    $self->{ZeropointIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ZeropointIndex};
}


# Frossie's things
# ----------------

=item B<thing>

Returns the hash that can be used for checking the validity of
calibration frames. This is a combination of the two hashes
stored in C<thingone> and C<thingtwo>. The hash returned
by this method is readonly.

  $hdr = $Cal->thing;

=cut

sub thing {
  return { %{$_[0]->thingone}, %{$_[0]->thingtwo} };
}

=item B<thingone>

Returns or sets the hash associated with the header of the object
(frame or group or whatever) needed to match calibration criteria
against.

Ending sentences with a preposition is a bug.

=cut

sub thingone {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing1} = $arg;
  }

  return $self->{Thing1};
}

=item B<thingtwo>

Returns or sets the hash associated with the user defined header of
the object (frame or group or whatever) against which calibration
criteria are applied.

=cut

sub thingtwo {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing2} = $arg;
  }

  return $self->{Thing2};
}


=back

=head2 General Methods

=over 4

=item B<find_file>

Returns the full path and filename of the requested file.

  $filename = $Cal->find_file("fs_izjhklm.dat");

Returns undef if the requested file cannot be found. See
B<ORAC::Inst::Defn::orac_determine_calibration_search_path>
for information on setting up calibration directories.

=cut

sub find_file {
  my $self = shift;

  my $file = shift;
  return undef if ! defined $file;

  my @directories = orac_determine_calibration_search_path( $ENV{'ORAC_INSTRUMENT'} );

  foreach my $directory (@directories) {
    if( -e ( File::Spec->catdir( $directory, $file ) ) ) {
      return File::Spec->catdir( $directory, $file );
    }
  }

  return undef;
}

=back

=head1 SEE ALSO

L<ORAC::Group> and
L<ORAC::Frame> 

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
