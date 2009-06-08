package ORAC::Frame::ACSIS;

=head1 NAME

ORAC::Frame::ACSIS - Class for dealing with ACSIS observation frames.

=head1 SYNOPSIS

use ORAC::Frame::ACSIS;

$Frm = new ORAC::Frame::ACSIS(\@filenames);
$Frm->file("file");
$Frm->readhdr;
$Frm->configure;
$value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to ACSIS. It provides a class derived from B<ORAC::Frame::NDF>.
All the methods available to B<ORAC::Frame> objects are available to
B<ORAC::Frame::IRIS2> objects.

=cut

use 5.006;
use warnings;
use strict;
use Carp;

use ORAC::Error qw/ :try /;
use ORAC::Print qw/ orac_warn /;

use Astro::Coords;
use Astro::Coords::Angle;
use Astro::Coords::Angle::Hour;
use DateTime;
use DateTime::Format::ISO8601;
use NDF;
use Starlink::AST;

our $VERSION;

use base qw/ ORAC::JSAFile ORAC::Frame::JCMT ORAC::Frame::NDF /;

$VERSION = '1.0';

use ORAC::Constants;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Frame::ACSIS> object. This method
also takes optional arguments:

=over 8

=item * If one argument is supplied it is assumed to be a reference
to an array containing a list of raw files associated with the
observation.

=item * If two arguments are supplied they are assumed to be the
UT date and observation number.

=back

In any case, all arguments are passed to the configure() method which
is run in addition to new() when arguments are supplied.

The object identifier is returned.

  $Frm = new ORAC::Frame::ACSIS;
  $Frm = new ORAC::Frame::ACSIS( \@files );
  $Frm = new ORAC::Frame::ACSIS( '20040919', '10' );

The constructor hard-wires the '.sdf' rawsuffix and the 'a' prefix,
although these can be overridden with the rawsuffix() and
rawfixedpart() methods.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('a');
  $self->rawformat('NDF');
  $self->rawsuffix('.sdf');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object.
  # Currently the argument will be the array reference to the list
  # of filenames, or if there are two args it's the UT date and
  # observation number.
  $self->configure(@_) if @_;

  return $self;
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument.
The file(), raw(), readhdr(), findgroup(), findrecipe() and
findnsubs() methods are invoked by this command. Arguments are
required. If there is one argument it is assumed that this
is a reference to an array containing a list of raw filenames.
The ACSIS version of configure() cannot take two parameters,
as there is no way to know the location of the file that would
make up the Frame object from only the UT date and run number.

  $Frm->configure(\@files);

=cut

sub configure {
  my $self = shift;

  my @fnames;
  if( scalar( @_ ) == 1 ) {
    my $fnamesref = shift;
    @fnames = (ref $fnamesref ? @$fnamesref : $fnamesref);
  } elsif( scalar( @_ ) == 2 ) {

    # ACSIS configure() cannot take 2 arguments.
    croak "configure() for ACSIS cannot take two arguments";

  } else {
    croak "Wrong number of arguments to configure: 1 or 2 args only";
  }

  # Set the filenames.
  for my $i (1..scalar(@fnames)) {
    $self->file($i, $fnames[$i-1]);
  }

  # Set the raw files.
  $self->raw( @fnames );

  # Populate the header.
  $self->readhdr;

  # Find the group name and set it.
  $self->findgroup;

  # Find the recipe name.
  $self->findrecipe;

  # Find nsubs.
  $self->findnsubs;

  # Just return true.
  return 1;
}

=item B<framegroupkeys>

Returns the keys that should be used for determining whether files
from a single observation should be treated independently.

For ACSIS a single frame object is returned for single sub-system
observations and multiple frame objects returned in multi-subsystem
mode. One caveat is that if the multi-subsystem mode looks like a
hybrid mode (bandwidth mode and IF frequency identical) then a single
frame object is returned.

 @keys = $Frm->framegroupkeys;

=cut

sub framegroupkeys {
  return (qw/ BWMODE IFFREQ UTDATE ORAC_OBSERVATION_NUMBER /);
}

=back

=head2 General Methods

=over 4



=item B<file_from_bits>

There is no file_from_bits() for ACSIS. Use pattern_from_bits()
instead.

=cut

sub file_from_bits {
  die "ACSIS has no file_from_bits() method. Use pattern_from_bits() instead\n";
}

=item B<file_from_bits_extra>

Extra information that can be supplied to the Group file_from_bits
methods when constructing the Group filename.

 $extra = $Frm->file_from_bits_extra();

=cut

sub file_from_bits_extra {
  my $self = shift;
  my (@subsysnrs) = $self->subsysnrs;
  # for hybrid mode return the first subsystem number
  return $subsysnrs[0];
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable component
parts. A prefix (usually UT) and observation number should be
supplied.

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

For ACSIS the flag file is of the form .aYYYYMMDD_NNNNN.ok, where
YYYYMMDD is the UT date and NNNNN is the observation number zero-padded
to five digits. The flag file is stored in $ORAC_DATA_IN.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # Pad the observation number with leading zeros to make it five
  # digits long.
  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  my $flag = File::Spec->catfile('.' . $self->rawfixedpart . $prefix . '_' . $padnum . '.ok');

  return $flag;
}

=item B<findgroup>

Returns the group name from the header.

The group name stored in the object is automatically updated using
this value.

=cut

sub findgroup {
  my $self = shift;

  my $hdrgrp;
  if( defined( $self->hdr('DRGROUP') ) ) {
    $hdrgrp = $self->hdr('DRGROUP');
  } else {

    # Check to see if we have the tracking system and base position in the header. If we don't, we'll have to get it from the WCS.©
    my %state;
    my $wcs;
    if( defined( $self->hdr( 'TRACKSYS' ) ) ) {

      $state{'TCS_TR_SYS'} = $self->hdr( 'TRACKSYS' );

      if( $self->hdr( 'TRACKSYS' ) ne 'APP' &&
        defined( $self->hdr( 'BASEC1' ) ) &&
        defined( $self->hdr( 'BASEC2' ) ) ) {

        $state{'TCS_TR_BC1'} = $self->hdr( 'BASEC1' );
        $state{'TCS_TR_BC2'} = $self->hdr( 'BASEC2' );

      }

    } else {

      # Get the WCS.
      $self->read_wcs;
      $wcs = $self->wcs;

      # Retrieve the TCS_TR_SYS, TCS_TR_BC1 and TCS_TR_BC2 values from
      # the JCMTSTATE structure.
      $state{'TCS_TR_SYS'} = $self->jcmtstate( "TCS_TR_SYS" );
      $state{'TCS_TR_BC1'} = $self->jcmtstate( "TCS_TR_BC1" );
      $state{'TCS_TR_BC2'} = $self->jcmtstate( "TCS_TR_BC2" );

    }

    if( exists $state{TCS_TR_SYS} && $state{TCS_TR_SYS} =~ /APP/ ) {

      # We're tracking in geocentric apparent, so instead of using the
      # RefRA/RefDec position (which will be moving with the object)
      # use the object name.
      $hdrgrp = $self->hdr( "OBJECT" );

    } else {

      # Sometimes it seems that the RefRA/RefDec position stored in the
      # specframe is not the same as the actual base position.
      # eg 20081007 #54
      # To be robust we use the JCMTSTATE extension
      my ($refra, $refdec);
      if (exists $state{TCS_TR_BC1} && exists $state{TCS_TR_BC2} ) {
        my $ang = Astro::Coords::Angle::Hour->new( $state{TCS_TR_BC1},
                                                   units => 'rad' );
        $refra = $ang->string;
        $ang = Astro::Coords::Angle->new( $state{TCS_TR_BC2},
                                          units => 'rad' );
        $refdec = $ang->string;
      } elsif( defined( $wcs ) ) {
        # Use the RefRA/RefDec position with colons stripped out and to
        # the nearest arcsecond.
        $refra = $wcs->GetC("RefRA");
        $refdec = $wcs->GetC("RefDec");
      }
      $refra =~ s/\..*$//;
      $refdec =~ s/\..*$//;
      $refra =~ s/://g;
      $refdec =~ s/://g;

      $hdrgrp = $refra . $refdec;

    }

    my $restfreq;
    if( defined( $self->hdr( "FRQSIGLO" ) ) &&
        defined( $self->hdr( "FRQSIGHI" ) ) ) {
      $restfreq = sprintf( "%.2f", ( $self->hdr( "FRQSIGLO" ) +
                                     $self->hdr( "FRQSIGHI" ) ) /
                                     2 );
    } else {
      $self->read_wcs;
      $wcs = $self->wcs;
      $restfreq = $wcs->GetC("RestFreq");
    }

    $hdrgrp .= $self->hdr( "BWMODE" ) .
               ( uc( $self->hdr( "SAM_MODE" ) ) eq 'RASTER' ? 'SCAN' : uc( $self->hdr( "SAM_MODE" ) ) ) .
               $self->hdr( "SW_MODE" ) .
               $self->hdr( "INSTRUME" ) .
               $self->hdr( "OBS_TYPE" ) .
               $self->hdr( "IFFREQ" ) .
               $self->hdr( "SIMULATE" ) .
               $restfreq;

    # Add DATE-OBS if we're not doing a science observation.
    if( uc( $self->hdr( "OBS_TYPE" ) ) ne 'SCIENCE' ) {
      $hdrgrp .= $self->hdr( "DATE-OBS" );
    }

  }

  $self->group($hdrgrp);

  return $hdrgrp;
}

=item B<findnsubs>

Find the number of sub-frames associated by the frame by looking
at the list of raw files associated with object. Usually run
by configure().

  $nsubs = $Frm->findnsubs;

The state of the object is updated automatically.

=cut

sub findnsubs {
  my $self = shift;
  my @files = $self->raw;
  my $nsubs = scalar( @files );
  $self->nsubs( $nsubs );
  return $nsubs;
}

=item B<inout>

Similar to base class except the frame number is appended to the output suffix.

=cut

sub inout {
  my $self = shift;                     
  my $suffix = shift;      
  my $number = shift;
  if (defined $number) {
    $suffix .= sprintf( "%03d", $number );                                                        
  }
  return $self->SUPER::inout( $suffix, (defined $number ? $number : () ) );             
}

=item B<pattern_from_bits>

Determine the pattern for the raw filename given the variable component
parts. A prefix (usually UT) and observation number should be supplied.

  $pattern = $Frm->pattern_from_bits( $prefix, $obsnum );

Returns a regular expression object.

=cut

sub pattern_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  my $padnum = '0'x(5-length($obsnum)) . $obsnum;

  my $pattern = $self->rawfixedpart . $prefix . "_" . $padnum . '_\d\d_\d{4}' . $self->rawsuffix;

  return qr/$pattern/;
}

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number after the UT date in the
filename. This method is subclassed for ACSIS.

The return value is -1 if no number can be determined.

=cut

sub number {
  my $self = shift;
  my $number;

  my $raw = $self->raw;

  if( defined( $raw ) ) {
    if( ( $raw =~ /(\d+)_(\d\d)_(\d{4})(\.\w+)?$/ ) ||
        ( $raw =~ /(\d+)\.ok$/ ) ) {
      # Drop leading zeroes.
      $number = $1 * 1;
    } else {
      $number = -1;
    }
  } else {
    # No match so set to -1.
    $number = -1;
  }
  return $number;
}

=back

=head2 Accessors

=over 4

=item B<allow_header_sync>

Whether or not to allow automatic header synchronization when the
Frame is updated via either the C<file> or C<files> method.

  $Frm->allow_header_sync( 1 );

For ACSIS, defaults to true (1).

=cut

sub allow_header_sync {
  my $self = shift;

  if( ! defined( $self->{AllowHeaderSync} ) ) {
    $self->{AllowHeaderSync} = 1;
  }

  if( @_ ) { $self->{AllowHeaderSync} = shift; }

  return $self->{AllowHeaderSync};
}

=back

=head1 <SPECIALIST METHODS>

Methods specifically for ACSIS.

=over 4

=item B<subsysnrs>

List of subsysnumbers in use for this frame. If there is more than
one subsystem number this indicates a hybrid mode.

  @numbers = $Frm->subsysnrs;

In scalar context returns the total number of subsystems.

  $number_of_subsystems = $Frm->subsysnrs;

=cut

sub subsysnrs {
  my $self = shift;
  my $hdr = $self->hdr;

  my @numbers;
  if (exists $hdr->{SUBSYSNR}) {
    push(@numbers, $hdr->{SUBSYSNR});
  } else {
    @numbers = map { $_->{SUBSYSNR} } @{$hdr->{SUBHEADERS}};
  }
  return (wantarray ? sort @numbers : scalar(@numbers));
}

=back

=head1 SEE ALSO

L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Science and Technology Facilities Council.
Copyright (C) 2004-2007 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
