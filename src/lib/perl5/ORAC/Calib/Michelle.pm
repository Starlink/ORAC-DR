package ORAC::Calib::Michelle;

=head1 NAME

ORAC::Calib::Michelle;

=head1 SYNOPSIS

  use ORAC::Calib::Michelle;

  $Cal = new ORAC::Calib::Michelle;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying Michelle-specific calibration
objects. It provides a class derived from ORAC::Calib::ImagSpec.  All the
methods available to ORAC::Calib::ImagSpec objects are available to
ORAC::Calib::UKIRT objects.

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
                                  emis => {},
                                  # override default mask since we copy it
                                  mask => { copyindex => 1 },
);


=head1 METHODS

=head2 Index and Rules files

=over 4

=back

=head2 Accessor Methods

=over 4

=item B<emis>

Return (or set) the name of the curent emissivity frame - checks
suitability on return.

=cut

sub emis {
  my $self = shift;
  return $self->GenericIndexAccessor( "emis", 0, 0, @_ );
}

=item B<mask>

Retrieve the mask from the file. Look for the mask in both the calibration
directory and ORAC_DATA_OUT.

  $mask = $Cal->mask();

=cut

sub mask {
  my $self = shift;
  my $mask = $self->GenericIndexAccessor( "mask", 0, 0, @_ );
  $mask .= ".sdf" unless $mask =~ /\.sdf$/;
  return $self->find_file( $mask );
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

Mask overrides base class since the reference index file must be
read from the calibration directory.

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
