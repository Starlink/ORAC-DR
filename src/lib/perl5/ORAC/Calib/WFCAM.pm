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
  return $self->GenericIndexAccessor( "interleavemask", 0, 0, 0, 0, @_ );
}

=item B<dark>

Return (or set) the name of the current dark - checks suitability on return.
This is subclassed for WFCAM so that the warning messages when going through
the list of possible darks are suppressed.

=cut

sub dark {
  my $self = shift;
  return $self->GenericIndexAccessor( "dark", 0, 0, 0, 0, @_ );
}

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

This method is subclassed for WFCAM so that the warning messages when
going through the list of possible flats are suppressed.

=cut


sub flat {
  my $self = shift;
  return $self->GenericIndexAccessor( "flat", 0, 0, 0, 0, @_ );
}

=item B<mask>

Return (or set) the name of the current bad pixel mask.

  $mask = $Cal->mask;

This method is subclassed for WFCAM because we have one mask per
camera and not one standard mask.

=cut

sub mask {
  my $self = shift;
  return $self->GenericIndexAccessor( "mask", 0, 0, 0, 0, @_ );
}

=item B<skyflat>

Return (or set) the name of the current skyflat.

  $skyflat = $Cal->skyflat;

=cut

sub skyflat {
  my $self = shift;
  return $self->GenericIndexAccessor( "skyflat", 0, 0, 0, 0, @_ );
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
