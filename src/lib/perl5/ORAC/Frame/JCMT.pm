package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in
ORAC-DR.

=head1 SYNOPSIS

  use ORAC::Frame::JCMT;

  $Frm = new ORAC::Frame::JCMT( "filename" );

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to JCMT instruments. It provides a class derived from
B<ORAC::Frame::NDF>. All the methods available to B<ORAC::Frame>
objects are also available to B<ORAC::Frame::JCMT> objects.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;

use vars qw/ $VERSION /;
use Carp;
use base qw/ ORAC::Frame::NDF /;

use JSA::Headers qw/ read_jcmtstate /;
use ORAC::Error qw/ :try /;

$VERSION = '1.01';

# Map AST Sky SYSTEM to JCMT TRACKSYS
my %astToJCMT = (
                 AZEL => "AZEL",
                 GAPPT => "APP",
                 GALACTIC => "GAL",
                 ICRS => "ICRS",
                 FK4 => "B1950",
                 FK5 => "J2000",
                );


=head1 PUBLIC METHODS

The following methods are available in this class in addition to those
available from B<ORAC::Frame>.

=head2 General Methods

=over 4

=item B<jcmtstate>

Return a value from either the first or last entry in the JCMT STATE
structure.

  my $value = $Frm->jcmtstate( $keyword, 'end' );

If the supplied keyword does not exist in the JCMT STATE structure,
this method returns undef. An optional second argument may be given,
and must be either 'start' or 'end'. If this second argument is not
given, then the first entry in the JCMT STATE structure will be used
to obtain the requested value.

Both arguments are case-insensitive.

=cut

sub jcmtstate {
  my $self = shift;

  my $keyword = uc( shift );
  my $which = shift;

  if( defined( $which ) && uc( $which ) eq 'END' ) {
    $which = 'END';
  } else {
    $which = 'START';
  }

  # First, check our cache.
  if( exists $self->{JCMTSTATE} ) {
    return $self->{JCMTSTATE}->{$which}->{$keyword};
  }

  # Get the first and last files in the Frame object.
  my $first = $self->file( 1 );
  my $last = $self->file( $self->nfiles );

  # Reference to hash bucket in cache to simplify
  # references in code later on
  my $startref = $self->{JCMTSTATE}->{START} = {};
  my $endref = $self->{JCMTSTATE}->{END} = {};

  # if we have a single file read the start and end
  # read the start and end into the cache regardless
  # of what was requested in order to minimize file opening.
  if ($first eq $last ) {
    my %values = read_jcmtstate( $first, [qw/ start end /] );
    for my $key ( keys %values ) {
      $startref->{$key} = $values{$key}->[0];
      $endref->{$key} = $values{$key}->[1];
    }
  } else {
    my %values = read_jcmtstate( $first, 'start' );
    %$startref = %values;
    %values = read_jcmtstate( $last, 'end' );
    %$endref = %values;

  }
  return $self->{JCMTSTATE}->{$which}->{$keyword};
}

=item B<find_base_position>

Determine the base position of a data file. If the file name
is not provided it will be read from the object.

  %base = $Frm->find_base_position( $file );

Returns hash with keys

  TCS_TR_SYS   Tracking system for base
  TCS_TR_BC1   Longitude of base position (radians)
  TCS_TR_BC2   Latitude of base position (radians)

The latter will be absent if this is an observation of a moving
source. In addition, returns sexagesimal strings of the base
position as

  TCS_TR_BC1_STR
  TCS_TR_BC2_STR

=cut

sub find_base_position {
  my $self = shift;
  my $file = shift;
  $file = $self->file unless defined $file;

  my %state;

  # First read the FITS header (assume that TRACKSYS presence implies BASEC1/C2)
  if (defined $self->hdr("TRACKSYS") ) {
    $state{TCS_TR_SYS} = $self->hdr("TRACKSYS");

    if ($state{TCS_TR_SYS} ne 'APP' &&
        defined $self->hdr("BASEC1") &&
        defined $self->hdr("BASEC2") ) {
      # converting degrees to radians
      for my $c (qw/ C1 C2 /) {
        my $ang = Astro::Coords::Angle->new( $self->hdr("BASE$c"), units => "deg");
        $state{"TCS_TR_B$c"} = $ang->radians;
      }
    }
  } else {
    # Attempt to read from JCMTSTATE
    try {
      $state{TCS_TR_SYS} = $self->jcmtstate( "TCS_TR_SYS" );
      print "Got $state{TCS_TR_SYS}\n";
      if ($state{TCS_TR_SYS} ne 'APP') {
        for my $i (qw/ TCS_TR_BC1 TCS_TR_BC2 / ) {
          $state{$i} = $self->jcmtstate( $i );
        }
      }
    };

    # if that doesn't work we probably have SCUBA-2 processed images
    # or some very odd ACSIS files
    if (!exists $state{TCS_TR_SYS}) {
      # need the WCS
      my $wcs = $self->read_wcs( $file );

      # if no WCS read, attempt to read it from FITS headers
      # QL images use this technique. Need the raw header, not a merged one
      if (!defined $wcs) {
        my $fits = Astro::FITS::Header::NDF->new( File => $file );
        $wcs = $fits->get_wcs;
      }

      if (defined $wcs) {
        # Find a Sky frame
        my $skytemplate = Starlink::AST::SkyFrame->new( "MaxAxes=3,MinAxes=1" );
        my $skyframe = $wcs->FindFrame( $skytemplate, "" );

        if (defined $skyframe) {
          # Get the sky reference position and system
          my $astsys = $wcs->Get("System");
          if ( exists $astToJCMT{$astsys}) {
            $state{TCS_TR_SYS} = $astToJCMT{$astsys};
          } else {
            warnings::warnif("Could not understand coordinate frame $astsys. Using ICRS");
            $state{TCS_TR_SYS} = "ICRS";
          }

          if ($state{TCS_TR_SYS} ne "APP") {
            $state{TCS_TR_BC1} = $wcs->Get("SkyRef(1)");
            $state{TCS_TR_BC2} = $wcs->Get("SkyRef(2)");
          }
        } else {
          # look for a specframe
          my $spectemplate = Starlink::AST::SpecFrame->new( "MaxAxes=3" );
          my $findspecfs = $wcs->FindFrame( $spectemplate, ",," );
          my $specframe = $findspecfs->GetFrame( 2 );
          ($state{TCS_TR_BC1}, $state{TCS_TR_BC2}) =
            $specframe->GetRefPos( Starlink::AST::SkyFrame->new("System=J2000") );
          $state{TCS_TR_SYS} = "J2000"; # by definition
        }
      }
    }
  }

  # See if we managed to read a tracking system
  if (!exists $state{TCS_TR_SYS}) {
    croak "Completely unable to read a tracking system from file $file !!!\n";
  }

  # if we have base positions, create string versions
  if (exists $state{TCS_TR_BC1} && exists $state{TCS_TR_BC2} ) {
    for my $c (qw/ 1 2 /) {
      my $class = "Astro::Coords::Angle" . ($c == 1 ? "::Hour" : "");
      my $ang = $class->new( $state{"TCS_TR_BC$c"},
                             units => 'rad' );
      $ang->str_ndp(0); # no decimal places
      $ang = $ang->string;
      $ang =~ s/\D//g; # keep numbers
      $state{"TCS_TR_BC$c"."_STR"} = $ang;
    }
  }

  return %state;
}

=cut

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness <t.jenness@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council. All
Rights Reserved.

=cut

1;
