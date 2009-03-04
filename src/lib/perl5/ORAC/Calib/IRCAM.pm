package ORAC::Calib::IRCAM;

=head1 NAME

ORAC::Calib::IRCAM;

=head1 SYNOPSIS

  use ORAC::Calib::IRCAM;

  $Cal = new ORAC::Calib::IRCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying IRCAM-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use 5.006;

# standard modules
use Carp;
use strict;
use warnings;

use ORAC::Calib;			# use base class
use base qw/ ORAC::Calib /;

use File::Spec;

use vars qw/ $VERSION/;
$VERSION = '1.0';

=over 4

=item B<rotation>

Return (or set) the name of the rotation transformation matrix.

  $rotation = $Cal->rotation;

For IRCAM this is set to $ORAC_DATA_CAL/ircam3_rotate2eq by default.

=cut


sub rotation {
  my $self = shift;
  if (@_) { $self->{Rotation} = shift; }

  unless (defined $self->{Rotation}) {
    my $rotation = $self->find_file("ircam3_rotate2eq.sdf");
    if( defined( $rotation ) ) { $rotation =~ s/\.sdf//; }
    $self->{Rotation} = $rotation;
  };


  return $self->{Rotation};
};

=item B<mask>

Return (or set) the name of the bad-pixel mask.

  $mask = $Cal->mask;

For IRCAM this is set to $ORAC_DATA_CAL/bpm by default.

=cut


sub mask {
  my $self = shift;
  if (@_) { $self->{Mask} = shift; }

  unless (defined $self->{Mask}) {
    my $mask = $self->find_file("bpm.sdf");
    if( defined( $mask ) ) { $mask =~ s/\.sdf//; }
    $self->{Mask} = $mask;
  };


  return $self->{Mask}; 
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
     my $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, "index.mask" );
     my $rulesfile = $self->find_file("rules.mask");
     $self->{MaskIndex} = new ORAC::Index($indexfile,$rulesfile);
   };

  return $self->{MaskIndex};

};

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
