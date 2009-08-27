package ORAC::Calib::UIST;

=head1 NAME

ORAC::Calib::UIST;

=head1 SYNOPSIS

  use ORAC::Calib::UIST;

  $Cal = new ORAC::Calib::UIST;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying UIST-specific calibration
objects. It provides a class derived from ORAC::Calib::ImagSpec.  All the
methods available to ORAC::Calib::ImagSpec objects are available to
ORAC::Calib::UIST objects. Written for Michelle and adpated for UIST.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors(
                                  ifuprofile => { staticindex => 1 },
                                  offset => {},
);

=head1 METHODS

=head2 General Methods

=over 4

=item B<ifuprofile>

=cut

sub ifuprofile {
  my $self = shift;
  return $self->GenericIndexAccessor( "ifuprofile", -1, 0, @_ );
}

=item B<offset>

Returns the appropriate y-offset value.

=cut


sub offset {
  my $self = shift;
  return $self->GenericIndexAccessor( "offset", 0, 0, @_ );
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

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
adapted for UIST by S Todd (Dec 2001)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
