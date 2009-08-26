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
  if( @_ ) {
    return $self->ifuprofilename( @_ );
  }

  my $ok = $self->ifuprofileindex->verify( $self->ifuprofilename, $self->thing );

  return $self->ifuprofilename if $ok;

  if( defined( $ok ) ) {
    my $ifuprofile = $self->ifuprofileindex->chooseby_negativedt( "ORACTIME", $self->thing );

    if( ! defined( $ifuprofile ) ) {
      croak "No suitable IFU profile file was found in index file";
    }
    $self->ifuprofilename( $ifuprofile );
  } else {
    croak "Error in determining IFU profile file - giving up";
  }
}

=item B<offset>

Returns the appropriate y-offset value.

=cut


sub offset {

  my $self = shift;
  if (@_) {
    return $self->offsetcache(shift);
  };

  my $ok = $self->offsetindex->verify($self->offsetcache,$self->thing);

  # happy ending
  return $self->offsetcache if $ok;

  if (defined $ok) {
    my $offset = $self->offsetindex->choosebydt('ORACTIME',$self->thing);

    unless (defined $offset) {
      # Nothing suitable, give up...
      croak "No suitable offset value was found in index file"
    }

    # Store the good value
    $self->offsetcache($offset);

  } else {
    # All fall down....
    croak("Error in determining offset value - giving up");
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

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
adapted for UIST by S Todd (Dec 2001)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
