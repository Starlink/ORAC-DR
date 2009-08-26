package ORAC::Calib::OIR;

=head1 NAME

ORAC::Calib::OIR - Infrared/Optical calibration data

=head1 SYNOPSIS

  use ORAC::Calib::OIR;

  $dark = $Cal->dark;
  $mask = $Cal->mask;
  $sky = $Cal->sky;
  $bias = $Cal->bias;
  $rn = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying Infraref/Optical calibration
information. It is a subclass of ORAC::Calib and is itself intended to be
subclassed.

=cut

use strict;
use Carp;
use warnings;

use ORAC::Print;
use File::Spec;       # for catfile

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
$VERSION = '1.0';

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

  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

  $obj->{Bias} = undef;
  $obj->{Dark} = undef;
  $obj->{Flat} = undef;
  $obj->{Mask} = undef;
  $obj->{ReadNoise} = undef;
  $obj->{Sky} = undef;

  $obj->{BiasIndex} = undef;
  $obj->{DarkIndex} = undef;
  $obj->{FlatIndex} = undef;
  $obj->{MaskIndex} = undef;
  $obj->{ReadNoiseIndex} = undef;
  $obj->{SkyIndex} = undef;

  $obj->{BiasNoUpdate} = 0;
  $obj->{DarkNoUpdate} = 0;
  $obj->{FlatNoUpdate} = 0;
  $obj->{MaskNoUpdate} = 0;
  $obj->{ReadNoiseNoUpdate} = 0;
  $obj->{SkyNoUpdate} = 0;

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=cut

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

=item B<default_mask>

Name of default mask.

=cut

sub default_mask {
  return 'bpm.sdf';
}

=item B<mask>

Return (or set) the name of the bad pixel mask. If a mask is to be returned 
every effrort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask($newmask);

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), the return value of "default_mask" is returned by
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
      my $defmask = $self->default_mask;
      $defmask = $self->find_file($defmask);
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

# *name methods
# -------------
# Used when a file name is required.

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

=item B<maskname>

Return (or set) the name of the current bad pixel mask

  $mask = $Cal->maskname;

The C<mask()> method should be used if a test for suitability of the
mask is required.

=cut

sub maskname {
  my $self = shift;
  if (@_) { $self->{Mask} = shift unless $self->masknoupdate; }
  return $self->{Mask}; 
};

=item B<skyname>

Return (or set) the name of the current sky frame---no checking.

  $dark = $Cal->skyname;


=cut

sub skyname {
  my $self = shift;
  if (@_) { $self->{Sky} = shift unless $self->skynoupdate; }
  return $self->{Sky};
}

# *cache methods
# --------------
# Used when a value or values (rather than a file) is required.

=item B<readnoisecache>

Cached value of the readnoise.  Only used when noupdate is in effect.

=cut

sub readnoisecache {
  my $self = shift;
  if (@_) { $self->{ReadNoise} = shift unless $self->readnoisenoupdate; }
  return $self->{ReadNoise};
}

# *noupdate methods
# -----------------

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

=item B<masknoupdate>

Stops object from updating itself with more recent data.
Used when overrding the mask file from the command-line.

=cut

sub masknoupdate {

  my $self = shift;
  if (@_) { $self->{MaskNoUpdate} = shift; }
  return $self->{MaskNoUpdate};

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

=item B<skynoupdate>

Stops sky object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub skynoupdate {
  my $self = shift;
  if (@_) { $self->{SkyNoUpdate} = shift; }
  return $self->{SkyNoUpdate};
}

# *index methods
# --------------

=item B<biasindex> 

Return (or set) the index object associated with the bias index file

=cut

sub biasindex {

  my $self = shift;
  if (@_) { $self->{BiasIndex} = shift; }

  unless (defined $self->{BiasIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.bias" );
    my $rulesfile = $self->find_file("rules.bias");
    croak "bias rules file could not be located\n" unless defined $rulesfile;
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
    croak "dark rules file could not be located\n" unless defined $rulesfile;
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
    croak "flat rules file could not be located\n" unless defined $rulesfile;
    $self->{FlatIndex} = new ORAC::Index($indexfile,$rulesfile);
  };


  return $self->{FlatIndex}; 


};

=item B<maskindex>

Return or set the index object associated with the bad pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {

  my $self = shift;
  if (@_) { $self->{MaskIndex} = shift; }
  unless (defined $self->{MaskIndex}) {
     # The mask index file is normally not required to exist
     my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" );
     my $rulesfile = $self->find_file("rules.mask");
     $self->{MaskIndex} = new ORAC::Index($indexfile,$rulesfile);
   };

  return $self->{MaskIndex};

};

=item B<readnoiseindex>

Return (or set) the index object associated with the readnoise index file.

=cut

sub readnoiseindex {

  my $self = shift;
  if (@_) { $self->{ReadNoiseIndex} = shift; }

  unless (defined $self->{ReadNoiseIndex}) {
    my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.readnoise" );
    my $rulesfile = $self->find_file("rules.readnoise");
    croak "readnoise rules file could not be located\n" unless defined $rulesfile;
    $self->{ReadNoiseIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{ReadNoiseIndex};
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
    croak "sky rules file could not be located\n" unless defined $rulesfile;
    $self->{SkyIndex} = new ORAC::Index($indexfile,$rulesfile);
  };

  return $self->{SkyIndex};
};

=back

=head1 SEE ALSO

L<ORAC::Calib>, L<ORAC::Calib::Spectroscopy> and
L<ORAC::Calib::Imaging> 

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
