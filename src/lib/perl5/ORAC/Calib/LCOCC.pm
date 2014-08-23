package ORAC::Calib::LCOCC;

=head1 NAME

ORAC::Calib::LCOCC;

=head1 SYNOPSIS

  use ORAC::Calib::LCOCC;

  $Cal = new ORAC::Calib::LCOCC;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying LCOCC-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::UKIRT objects.

=cut

use 5.006;

# standard modules
use Carp;
use strict;
use warnings;

use base qw/ ORAC::Calib::Imaging /;

use File::Spec;

use vars qw/ $VERSION/;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors( baseshift => { isarray => 1 },
                                   dqc => {},
                                   flat => { copyindex => 1 },
                                   astromqc => {},
                                   mask => { copyindex => 1 },
                                   referenceoffset => { isarray => 1 },
                                   skybrightness => {},
                                   skycat_catalogue => { copyindex => 1 },
                                   zeropoint => {} );
=cut

=head1 METHODS

The following methods are available:

=head2 Accessors

=over 4


=item B<astromqc>

Determine the astrometric data quality control parameters for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid dqc, which
usually indicating that an _ADD_AUTO_ASTROMETRY_ primitive was not run.

  $astromqc = $Cal->astromqc;

The index file is queried every time unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the
readnoise meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include columns named NSTARS, OFFSETRA, OFFSETDEC, SECPIX, XRMS, YRMS.

=cut

sub astromqc {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "astromqc", [qw/ NSTARS OFFSETRA OFFSETDEC SECPIX XRMS YRMS /], @_ );
}


=item B<dqc>

Determine the data quality control parameters for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid dqc, which
usually indicating that an _CALCULATE_<foo>_STATS_ primitive was not run.

  $dqc = $Cal->dqc;

The index file is queried every time unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the
readnoise meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include columns named AIRMASS, ELLIPTICITY, FWHM,
ORIENT, QC_OBCON, QC_IMGST, QC_CATST & QC_PHTST.

=cut

sub dqc {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "dqc", [qw/ AIRMASS ELLIPTICITY FWHM ORIENT QC_OBCON QC_IMGST QC_CATST QC_PHTST /], @_ );
}


=item B<zeropoint>

Determine the zeropoint parameters for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

  $zeropoint = $Cal->zeropoint;

The index file is queried every time unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the
readnoise meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include columns named AIRMASS, EXTINCTION, MAG_LIMIT,
SKY_VALUE, SKY_VALUE_ERROR, SKY_VALUE_MAG, ZEROPOINT, ZEROPOINT_ERROR,
ZEROPOINT_SRC

=cut

sub zeropoint {
  my $self = shift;
  return $self->GenericIndexEntryAccessor( "zeropoint", [qw/ AIRMASS EXTINCTION FILTER MAG_LIMIT NCALOBJS SKY_VALUE SKY_VALUE_ERROR SKY_VALUE_MAG TRANSPARENCY ZEROPOINT ZEROPOINT_ERROR ZEROPOINT_SRC /], @_ );
}

=back

=head2 General Methods

=over 4

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

This method is subclassed for LCOCC so that the warning messages when
going through the list of possible flats are suppressed (5th argument = 0).
Also we don't croak (3rd argument = 1) if we fail to find a flat so we can
call the following code to set a default unity flat.

=cut

sub flat {
  my $self = shift;
  my $flat =  $self->GenericIndexAccessor( "flat", 0, 1, 0, 0, @_ );
# Try and find a default unity fakeflat if we didn't find an entry ($flat is undef)
  unless ( defined $flat ) {
    # $uhdrref is a reference to the Frame uhdr hash
    my $uhdrref = $self->thingtwo;
    my $defflatname = "fakeflat.sdf";
    if ($uhdrref->{'ORAC_XBINNING'} == 2 && $uhdrref->{'ORAC_YBINNING'} == 2 ) {
      my $defflatname = "fakeflat_bin2x2.sdf";
    }
    my $defflat = $self->find_file($defflatname);
    if( defined( $defflat ) ) {
      $defflat =~ s/\.sdf$//;
      return $defflat;
    }
# Give up...
    croak "No suitable flat was found in index file and no default available.";
  }
  $flat .= ".sdf" unless $flat =~ /\.sdf$/;
  return $self->find_file( $flat );
}

=item B<mask>

Return (or set) the name of the current mask.  If a mask is to be returned 
every effort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask( $newmask );

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), the LCOCC C<$ORAC_DATA_CAL/bpm_kb22> is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut

sub mask {
  my $self = shift;
  my $mask = $self->GenericIndexAccessor( "mask", 0, 0, 0, 0, @_ );
  unless ( defined $mask ) {
    my $defmask = $self->find_file("bpm_kb22.sdf");
    if( defined( $defmask ) ) {
      $defmask =~ s/\.sdf$//;
      return $defmask;
    }

# Give up...
    croak "No suitable bad pixel mask was found in index file and no default available.";
  }
  $mask .= ".sdf" unless $mask =~ /\.sdf$/;
  return $self->find_file( $mask );
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Lister (tlister@lcogt.net)
Malcolm Currie (Starlink) (mjc@star.rl.ac.uk)
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


1;
