package ORAC::Calib::JCMT;

=head1 NAME

ORAC::Calib::JCMT;

=head1 SYNOPSIS

  use ORAC::Calib::JCMT;

  $Cal = new ORAC::Calib::JCMT;

=head1 DESCRIPTION

This module contains methods for specifying JCMT-specific calibration
objects. It provides a class derived from ORAC::Calib. All the methods
available to ORAC::Calib objects are also available to
ORAC::Calib::JCMT objects.

It is expected that this module will be subclassed with instrument specific
variations.

=cut

use Carp;
use warnings;
use strict;

use File::Spec;

use base qw/ ORAC::Calib /;

use vars qw/ $VERSION @PLANETS /;
$VERSION = '1.0';

# The planets that we can retrieve fluxes for.
@PLANETS = qw/ MARS JUPITER SATURN URANUS NEPTUNE /;

__PACKAGE__->CreateBasicAccessors( pointing => {},
                                   qaparams => { staticindex => 1 },
);

=head1 METHODS

The following methods are available:

=head2 Accessors

=over 4

=item B<pointing>

Return (or set) the most recent pointing values.

  $pointing = $Cal->pointing;

Returns the entire index entry.

=cut

sub pointing {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "pointing", [qw/ DAZ DEL /], @_ );
}

=item B<qaparams>

Return or set the filename for QA parameters.

  my $qaparams = $Cal->qaparams;

=cut

sub qaparams {
  my $self = shift;
  my $qaparamsfile = $self->GenericIndexAccessor( "qaparams", 0, 0, 1, 1, @_ );
  # Find this file on disk because it will not be in ORAC_DATA_OUT
  return $self->find_file( $qaparamsfile );
}

=back

=head2 General Methods

=over 4

=item B<isplanet>

Returns true if the given object is a planet.

  $isplanet = $Cal->isplanet( "source_name" );

=cut

sub isplanet {
  my $self = shift;
  my $source = uc( shift );

  return 1 if grep /$source/, @PLANETS;
  return 0;
}

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

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
