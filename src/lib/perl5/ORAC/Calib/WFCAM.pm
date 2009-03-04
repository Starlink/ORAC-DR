package ORAC::Calib::WFCAM;

=head1 NAME

ORAC::Calib::WFCAM;

=head1 SYNOPSIS

use ORAC::Calib::WFCAM;

  $Cal = new ORAC::Calib::WFCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

=head1 DESCRIPTION

This module contains methods for specifying WFCAM-specific calibration
objects when using Starlink software for reduction. It provides a class
derived from ORAC::Calib. All the methods available to ORAC::Calib objects
are available to ORAC::Calib::WFCAM objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Calib::UFTI;
use ORAC::Print;

use File::Spec;

use base qw/ ORAC::Calib::UFTI /;

use vars qw/ $VERSION /;
$VERSION = '1.0';

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of interleave mask and bad
pixel mask.

  my $Cal = new ORAC::Calib::WFCAM;

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new(@_);

# Assumes we have a hash object.
  $obj->{InterleaveMask} = undef;
  $obj->{InterleaveMaskIndex} = undef;
  $obj->{InterleaveMaskNoUpdate} = 0;
  $obj->{SkyFlat} = undef;
  $obj->{SkyFlatIndex} = undef;
  $obj->{SkyFlatNoUpdate} = 0;

  return $obj;
}

=back

=head2 Accessors

=over 4

=item B<interleavemaskname>

Return (or set) the mask used in the interleaving process.

  $interleavemask = $Cal->interleavemaskname;

=cut

sub interleavemaskname {
  my $self = shift;

  if( @_ ) { $self->{InterleaveMask} = shift unless $self->interleavemasknoupdate; }
  return $self->{InterleaveMask};
}

=item B<skyflatname>

Return (or set) the skyflat used.

  $skyflat = $Cal->skyflatname;

=cut

sub skyflatname {
  my $self = shift;

  if( @_ ) { $self->{SkyFlat} = shift unless $self->skyflatnoupdate; }
  return $self->{SkyFlat};
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
}

=item B<interleavemaskindex>

Return or set the index object associated with the interleave mask.

  $index = $Cal->interleavemaskindex;

An index object is created automatically the first time this method
is run.

=cut

sub interleavemaskindex {
  my $self = shift;
  if ( @_ ) { $self->{InterleaveMaskIndex} = shift; }
  unless ( defined $self->{InterleaveMaskIndex} ) {
    my $indexfile = $self->find_file("index.interleavemask");
    my $rulesfile = $self->find_file("rules.interleavemask");
    $self->{InterleaveMaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{InterleaveMaskIndex};
}

=item B<maskindex>

Return or set the index object associated with the bad pixel mask.

  $index = $Cal->maskindex;

An index object is created automatically the first time this method
is run.

=cut

sub maskindex {
  my $self = shift;

  if (@_) { $self->{MaskIndex} = shift; }
  unless ( defined $self->{MaskIndex} ) {
    my $indexfile = $self->find_file("index.mask");
    my $rulesfile = $self->find_file("rules.mask");
    $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{MaskIndex};
}

=item B<skyflatindex>

Return or set the index object associated with the skyflat.

  $index = $Cal->skyflatindex;

An index object is created automatically the first time this method is
run.

=cut

sub skyflatindex {
  my $self = shift;

  if( @_ ) { $self->{SkyFlatIndex} = shift; }
  unless( defined( $self->{SkyFlatIndex} ) ) {
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.skyflat" );
    my $rulesfile = $self->find_file( "rules.skyflat" );
    $self->{SkyFlatIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{SkyFlatIndex};
}

=item B<interleavemasknoupdate>

Stops object from updating itself with more recent data.
Used when overriding the interleave mask from the commandline.

=cut

sub interleavemasknoupdate {
  my $self = shift;
  if( @_ ) { $self->{InterleaveMaskNoUpdate} = shift; }
  return $self->{InterleaveMaskNoUpdate};
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

=item B<skyflatnoupdate>

Stos object from updating itself with more recent data. Used when
overriding the skyflat file from the commandline.

=cut

sub skyflatnoupdate {
  my $self = shift;
  if( @_ ) { $self->{SkyFlatNoUpdate} = shift; }
  return $self->{SkyFlatNoUpdate};
}

=back

=head2 General Methods

=over 4

=item B<interleavemask>

Determine the mask necessary for microstep interleaving.

  $interleavemask = $Cal->interleavemask;

This method returns a filename, including directory structure. If
the noupdate flag is set there is no verification that the mask
meets the specified rules.

=cut

sub interleavemask {
  my $self = shift;

# Handle arguments.
  return $self->interleavemaskname(shift) if @_;

  my $ok = $self->interleavemaskindex->verify( $self->interleavemaskname, $self->thing );

  if( $ok ) { return $self->interleavemaskname };

  croak("Override interleave mask is not suitable! Giving up") if $self->interleavemasknoupdate;

  if( defined( $ok ) ) {
    my $mask = $self->interleavemaskindex->choosebydt('ORACTIME', $self->thing);
    croak "No suitable interleave mask calibration was found in index file"
      unless defined $mask;
    $self->interleavemaskname($mask);
  } else {
    croak "Error in interleave mask calibration checking - giving up";
  }
}

=item B<dark>

Return (or set) the name of the current dark - checks suitability on return.
This is subclassed for WFCAM so that the warning messages when going through
the list of possible darks are suppressed.

=cut

sub dark {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->darkname(shift);
  };

  my $ok = $self->darkindex->verify($self->darkname,$self->thing, 0);

  # happy ending - frame is ok
  if ($ok) {return $self->darkname};

  croak("Override dark is not suitable! Giving up") if $self->darknoupdate;

  # not so good
  if (defined $ok) {
    my $dark = $self->darkindex->choosebydt('ORACTIME',$self->thing, 0);
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

This method is subclassed for WFCAM so that the warning messages when
going through the list of possible flats are suppressed.

=cut


sub flat {
  my $self = shift;
  if (@_) {
    # if we are setting, accept the value and return
    return $self->flatname(shift);
  };

  my $ok = $self->flatindex->verify($self->flatname,$self->thing, 0);

  # happy ending - frame is ok
  if ($ok) {return $self->flatname};

  croak("Override flat is not suitable! Giving up") if $self->flatnoupdate;

  # not so good
  if (defined $ok) {
    my $flat = $self->flatindex->choosebydt('ORACTIME',$self->thing,0);
    croak "No suitable flat was found in index file"
      unless defined $flat;
    $self->flatname($flat);
  } else {
    croak("Error in flat calibration checking - giving up");
  };
};

=item B<mask>

Return (or set) the name of the current bad pixel mask.

  $mask = $Cal->mask;

This method is subclassed for WFCAM because we have one mask per
camera and not one standard mask.

=cut

sub mask {
  my $self = shift;
  if( @_ ) {
    return $self->maskname( shift );
  }

  my $ok = $self->maskindex->verify( $self->maskname, $self->thing, 0 );

  # Happy ending. Frame is OK.
  if( $ok ) { return $self->maskname; }

  croak( "Override mask is not suitable! Giving up" ) if $self->masknoupdate;

  if( defined( $ok ) ) {
    my $mask = $self->maskindex->choosebydt( 'ORACTIME', $self->thing, 0 );
    croak "No suitable mask was found in index file"
      unless defined $mask;
    $self->maskname( $mask );
  } else {
    croak( "Error in mask calibration checking - giving up" );
  }
}

=item B<skyflat>

Return (or set) the name of the current skyflat.

  $skyflat = $Cal->skyflat;

=cut

sub skyflat {
  my $self = shift;
  if( @_ ) {
    return $self->skyflatname( shift );
  }

  my $ok = $self->skyflatindex->verify( $self->skyflatname, $self->thing, 0 );

  if( $ok ) { return $self->skyflatname; }

  croak( "Override skyflat is not suitable! Giving up" ) if $self->skyflatnoupdate;

  if( defined( $ok ) ) {
    my $skyflat = $self->skyflatindex->choosebydt( 'ORACTIME', $self->thing, 0 );
    croak "No suitable skyflat was found in index file"
      unless defined $skyflat;
    $self->skyflatname( $skyflat );
  } else {
    croak( "Error in skyflat calibration checking - giving up" );
  }
}

=item B<flatindex>

Return or set the index for the flat.

  $index = $Cal->flatindex;
  $Cal->flatindex( $index );

This method is subclassed for WFCAM to use the find_file() method to
find the default index.flat file, so that it can be located in either
the C<ORAC_DATA_CAL> or C<ORAC_DATA_OUT> directories.

=cut

sub flatindex {

  my $self = shift;
  if (@_) { $self->{FlatIndex} = shift; }

  unless (defined $self->{FlatIndex}) {
    my $indexfile = $self->find_file("index.flat");
    my $rulesfile = $self->find_file("rules.flat");
    $self->{FlatIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{FlatIndex};

}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavangh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2004-2006 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
