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

use vars qw/ $VERSION /;
$VERSION = '1.0';

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

=cut

sub pointing {
  my $self = shift;

  # Handle arguments.
  return $self->pointingcache( shift ) if @_;

  if( $self->pointingnoupdate ) {
    my $cache = $self->pointingcache;
    return $cache if defined $cache;
  }

  my $pointingfile = $self->pointingindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $pointingfile ) ) {
    croak "No suitable pointing value found in index file"
  }

  my $pointingref = $self->pointingindex->indexentry( $pointingfile );
  if( exists( $pointingref->{DAZ} ) &&
      exists( $pointingref->{DEL} ) ) {
    return $pointingref;
  } else {
    croak "Unable to obtain DAZ and DEL from index file entry $pointingfile\n";
  }

}

=item B<qaparams>

Return or set the filename for QA parameters.

  my $qaparams = $Cal->qaparams;

=cut

sub qaparams {
  my $self = shift;

  # Handle arguments.
  return $self->qaparamscache( shift ) if @_;

  if( $self->qaparamsnoupdate ) {
    my $cache = $self->qaparamscache;
    return $cache if defined $cache;
  }

  my $qaparamsfile = $self->qaparamsindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $qaparamsfile ) ) {
    croak "No suitable QA parameters file found in index file"
  }

  return $self->find_file( $qaparamsfile );

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

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
