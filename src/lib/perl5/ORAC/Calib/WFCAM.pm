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
derived from ORAC::Calib::Imaging. All the methods available to
ORAC::Calib::Imaging objects are available to ORAC::Calib::WFCAM objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;
use File::Spec;

use base qw/ ORAC::Calib::Imaging /;

use vars qw/ $VERSION /;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors(
                                  interleavemask => { staticindex => 1 },
                                  skyflat => {},
                                  # override base mask implementations
                                  mask => { staticindex => 1 },
                                  flat => { staticindex => 1 },
);

=head1 METHODS

The following methods are available:

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

Additionally, "flat" and "mask" are locally modified to support
a static index location.

=head1 AUTHORS

Brad Cavangh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2004-2006 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
