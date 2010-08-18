package ORAC::Calib::OIR;

=head1 NAME

ORAC::Calib::OIR - Infrared/Optical calibration data

=head1 SYNOPSIS

  use ORAC::Calib::OIR;

  $dark = $Cal->dark;
  $mask = $Cal->mask;
  $sky = $Cal->sky;
  $bias = $Cal->bias;
  $rn = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying Infraref/Optical calibration
information. It is a subclass of ORAC::Calib and is itself intended to be
subclassed.

=cut

use strict;
use Carp;
use warnings;

use ORAC::Print;
use File::Spec;       # for catfile

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors( bias => {},
                                   dark => {},
                                   flat => {},
                                   mask => {},
                                   readnoise => {},
                                   sky => {} );

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Cal = new ORAC::Calib;

=cut

# NEW - create new instance of Calib.

sub new {

  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

  # Take no arguments at present
  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=cut

=item B<bias>

Return (or set) the name of the current bias.

  $bias = $Cal->bias;

=cut

sub bias {
  my $self = shift;
  return $self->GenericIndexAccessor( "bias", 0, 0, 0, 1, @_ );
}

=item B<dark>

Return (or set) the name of the current dark -
checks suitability on return.

=cut


sub dark {
  my $self = shift;
  return $self->GenericIndexAccessor( "dark", 0, 0, 0, 1, @_ );
}

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

=cut


sub flat {
  my $self = shift;
  return $self->GenericIndexAccessor( "flat", 0, 0, 0, 1, @_ );
}

=item B<default_mask>

Name of default mask.

=cut

sub default_mask {
  return 'bpm.sdf';
}

=item B<mask>

Return (or set) the name of the bad pixel mask. If a mask is to be returned
every effrort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask($newmask);

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), the return value of "default_mask" is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut

sub mask {
  my $self = shift;
  return $self->GenericIndexAccessor( "mask", 0,
                                      sub {
                                        my $defmask = $self->default_mask;
                                        $defmask = $self->find_file($defmask);
                                        if( defined( $defmask ) ) {
                                          $defmask =~ s/\.sdf//;
                                          return $defmask;
                                        }
                                      }, 0, 1, @_ );
}

=item B<readnoise>

Determine the readnoise to be used for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid readnoise.
(usually indicating that ARRAY_TESTS have not been reduced).

  $readnoise = $Cal->readnoise;

The index file is queried every time (usually not a problem since there
are only a limited number of array tests per night and the index
is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the readnoise
meets the specified rules (this is because the command-line override
uses a value rather than a file).

The index file must include a column named READNOISE.

=cut

sub readnoise {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "readnoise", "READNOISE", @_ );
}

=item B<sky>

Return (or set) the name of the current "sky" frame

=cut

sub sky {
  my $self = shift;
  return $self->GenericIndexAccessor( "sky", 0, 0, 0, 1, @_ );
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

=head1 SEE ALSO

L<ORAC::Calib>, L<ORAC::Calib::Spectroscopy> and
L<ORAC::Calib::Imaging>

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
