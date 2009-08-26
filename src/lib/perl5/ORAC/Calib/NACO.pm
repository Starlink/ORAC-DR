package ORAC::Calib::NACO;

=head1 NAME

ORAC::Calib::NACO;

=head1 SYNOPSIS

  use ORAC::Calib::NACO;

  $Cal = new ORAC::Calib::NACO;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying NACO-specific calibration
objects.  It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.  Written for Michelle and adapted for NACO.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Spec;

use base qw/ORAC::Calib::ImagSpec/;

use vars qw/$VERSION/;
$VERSION = '1.0';


=head1 METHODS

=head2 Index and Rules files

For NACO some of the rules files are keyed on the current value of
the CAMERA FITS header item.  This sub-class automatically changes the
rules file of the underlying index object.

=over 4

=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>

Does not use base class implementation since the index file is still
called index.flat (as for Michelle).

=cut

sub flatindex {
  my $self = shift;
  my $index = $self->SUPER::flatindex;
  $self->_set_index_rules($index, 'rules.flat_im', 'rules.flat_sp');
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
