package ORAC::Calib::ClassicCam;

=head1 NAME

ORAC::Calib::ClassicCam;

=head1 SYNOPSIS

  use ORAC::Calib::ClassicCam;

  $Cal = new ORAC::Calib::ClassicCam;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying ClassicCam-specific
calibration objects.  It provides a class derived from ORAC::Calib.
All the methods available to ORAC::Calib objects are available to
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
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=over 4

=cut

=item B<mask>

Return (or set) the name of the bad-pixel mask.

  $mask = $Cal->mask;

For ClassicCam this is set to $ORAC_DATA_CAL/bpm by default

=cut

sub mask {
   my $self = shift;
   if (@_) { $self->{Mask} = shift; }

   unless ( defined $self->{Mask} ) {
      $self->{Mask} = File::Spec->catfile( $ENV{ORAC_DATA_CAL}, "bpm" );
   }

   return $self->{Mask}; 
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie (mjc@star.rl.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut


1;
