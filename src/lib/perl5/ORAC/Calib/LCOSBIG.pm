package ORAC::Calib::LCOSBIG;

=head1 NAME

ORAC::Calib::LCOSBIG;

=head1 SYNOPSIS

  use ORAC::Calib::LCOSBIG;

  $Cal = new ORAC::Calib::LCOSBIG;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;

=head1 DESCRIPTION

This module contains methods for specifying LCOSBIG-specific calibration
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
                                   polrefang => { staticindex => 1 },
                                   referenceoffset => { isarray => 1 },
                                   skybrightness => {},
                                   skycat_catalogue => { copyindex => 1 },
                                   zeropoint => {} );
=cut

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of mask.

  my $Cal = new ORAC::Calib::LCOSBIG;

=cut

sub new {
   my $self = shift;
   my $obj = $self->SUPER::new(@_);

# Assumes we have a hash object.
   $obj->{Mask}        = undef;
   $obj->{MaskIndex}   = undef;
   $obj->{MaskNoUpdate} = 0;
   $obj->{FlatIndex} = undef;

   return $obj;

}


=back

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

=item B<maskname>

Return (or set) the name of the current bad-pixel mask

  $mask = $Cal->maskname;

The C<mask()> method should be used if a test for suitability of the
mask is required.

=cut


sub maskname {
   my $self = shift;
   if (@_) { $self->{Mask} = shift unless $self->masknoupdate; }
   return $self->{Mask};
};


=item B<maskindex>

Return or set the index object associated with the bad-pixel mask.

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
      $self->{MaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
   };

   return $self->{MaskIndex};

};

=item B<masknoupdate>

Stops object from updating itself with more recent data.
Used when overrding the mask file from the command-line.

=cut

sub masknoupdate {

   my $self = shift;
   if (@_) { $self->{MaskNoUpdate} = shift; }
   return $self->{MaskNoUpdate};

}

=item B<zeropoint>

Determine the zeropoint parameters for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid zeropoint, which
usually indicating that an _CALCULATE_ZEROPOINT_ primitive was not run.

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



=item B<flatindex>

Uses F<rules.flat_im> and <rules.flat_sp>, and sets the index
file for imaging mode to be F<index.flat_im> and for spectroscopy
and IFU to be F<index.flat_sp>.

=cut

#sub flatindex {
#  my $self = shift;
#  return $self->GenericIndex( "flat", "copy", @_ );
#}

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

This method is subclassed for LCOSBIG so that the warning messages when
going through the list of possible flats are suppressed (5th argument = 0).

=cut


sub flat {
  my $self = shift;
  return $self->GenericIndexAccessor( "flat", 0, 0, 0, 0, @_ );
}

=item B<mask>

Return (or set) the name of the current mask.  If a mask is to be returned
every effort is made to guarantee that the mask is suitable for use.

  $mask = $Cal->mask;
  $Cal->mask( $newmask );

If no suitable mask can be found from the index file (or the currently
set mask is not suitable), the LCOSBIG C<$ORAC_DATA_CAL/bpm> is returned by
default (so long as the file does exist).  Note that a test for
suitability can not be performed since there is no corresponding index
entry for this default mask.

=cut

sub mask {

   my $self = shift;

   if (@_) {
      return $self->maskname( shift );
   };

   my $ok = $self->maskindex->verify( $self->maskname, $self->thing );

# Return the name if successful.
   return $self->maskname if $ok;

   croak ( "Override mask is not suitable!  Giving up." ) if $self->masknoupdate;

   if ( defined $ok ) {
      my $mask = $self->maskindex->choosebydt( 'ORACTIME', $self->thing );

      unless ( defined $mask ) {

# There is no suitable mask.  Default to fallback position.
# Check that the default mask exists and be careful not to set this
# as the maskname() value since it has no corresponding index entry.
#      $self->{Mask} = File::Spec->catfile( $ENV{ORAC_DATA_CAL}, "bpm" );
#      return $self->{Mask};
        my $defmask = $self->find_file("bpm-kb73.sdf");
        if( defined( $defmask ) ) {
          $defmask =~ s/\.sdf$//;
          return $defmask;
        }

# Give up...
         croak "No suitable bad pixel mask was found in index file.";
      }

# Store the good value.
      $self->maskname( $mask );

   } else {

# All fall down....
      croak "Error in determining bad pixel mask.  Giving up.";
   }

}

=back

=head1 REVISION

$Id: LCOSBIG.pm 5756 2012-05-24 01:14:41Z tlister $

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
