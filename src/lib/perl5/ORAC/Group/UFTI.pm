package ORAC::Group::UFTI;

=head1 NAME

ORAC::Group::UFTI - class for dealing with UFTI observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::UFTI;

  $Grp = new ORAC::Group::UFTI("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to UFTI. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::UFTI> objects.

=cut

# A package to describe a UKIRT group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UKIRT;
use ORAC::General;

# Set inheritance
use base qw/ ORAC::Group::UKIRT /;

 '$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for UFTI should go here
my %hdr = (
            EXPOSURE_TIME        => "EXP_TIME",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            GAIN                 => "GAIN",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            UTEND                => "UTEND",
            UTSTART              => "UTSTART"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Group::UFTI->_generate_orac_lookup_methods( \%hdr );

# Allow for missing, undefined, and malformed headers.
sub _to_DEC_BASE {
   my $self = shift;
   my $dec = undef;
   if ( exists $self->hdr->{DECBASE} ) {
      $dec = $self->hdr->{DECBASE};

# Cope with some early data with FITS-header values starting in the
# erroneous column 10, and thus making the FITS parser think it is a
# comment.  These begin with an equals sign.  The value is then the
# first word after the removed equals sign.
      if ( defined( $dec ) && $dec =~ /^=/ ) {
         $dec =~ s/=//;
         my @words = split( /\s+/, $dec );
         $dec = $words[ 0 ];
      }
   }
   return $dec;
}

# Allow for missing, ubdefined, and malformed headers.
sub _to_RA_BASE {
   my $self = shift;
   my $ra = undef;
   if ( exists $self->hdr->{RABASE} ) {
      $ra = $self->hdr->{RABASE};

# Cope with some early data with FITS-header values starting in the
# erroneous column 10, and thus making the FITS parser think it is a
# comment.  These begin with an equals sign.  The value is then the
# first word after the removed equals sign.
      if ( defined( $ra ) && $ra =~ /^=/ ) {
         $ra =~ s/=//;
         my @words = split( /\s+/, $ra );
         $ra = $words[ 0 ];
      }
   }
   return $ra;
}

# Allow for multiple occurences of the date, the first being valid and
# the second is blank.
sub _to_UTDATE {
  my $self = shift;
  my $utdate;
  if ( exists $self->hdr->{DATE} ) {
     $utdate = $self->hdr->{DATE};

# This is a kludge to work with old data which has multiple values of
# the DATE keyword with the last value being blank (these were early
# UFTI data).  Return the first value, since the last value can be
# blank. 
     if ( ref( $utdate ) eq 'ARRAY' ) {
        $utdate = $utdate->[0];
     }
  }
  return $utdate;
}

# Use the nominal reference pixel if correctly supplied, failing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_X_REFERENCE_PIXEL{
  my $self = shift;
  my $xref;
  if ( exists $self->hdr->{RDOUT_X1} && exists $self->hdr->{RDOUT_X2} ) {
    my $xl = $self->hdr->{RDOUT_X1} - 1;
    my $xu = $self->hdr->{RDOUT_X2};
    $xref = nint( ( $xl + $xu ) / 2 );
  } else {
    $xref = 512;
  }
  return $xref;
}

sub _from_X_REFERENCE_PIXEL {
  "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

# Use the nominal reference pixel if correctly supplied, faiing that
# take the average of the bounds, and if these headers are also absent,
# use a default which assumes the full array.
sub _to_Y_REFERENCE_PIXEL{
  my $self = shift;
  my $yref;
  if ( exists $self->hdr->{RDOUT_Y1} && exists $self->hdr->{RDOUT_Y2} ) {
    my $yl = $self->hdr->{RDOUT_Y1} - 1;
    my $yu = $self->hdr->{RDOUT_Y2};
    $yref = nint( ( $yl + $yu ) / 2 );
  } else {
    $yref = 512;
  }
  return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
  "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::UFTI> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::UFTI;
   $Grp = new ORAC::Group::UFTI("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gf');
  $group->filesuffix('.sdf');

  # return the new object
  return $group;
}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT, ORACTIME and ORACDATETIME.

ORACUT is the UT date in YYYYMMDD format.

ORACTIME is the UT date with decimal days.

ORACDATETIME is the UT date in ISO8601 format: YYYY-MM-DDThh:mm:ss.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # Grab the UT datetime from the DATE-OBS header.
  my $dateobs = defined( $self->hdr->{1}->{'DATE-OBS'}) ? $self->hdr->{1}->{'DATE-OBS'} : ( defined($self->hdr->{'DATE-OBS'}) ? $self->hdr->{'DATE-OBS'} : 0 );

  # Split it into its constituent components.
  $dateobs =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = $4;
  my $minute = $5;
  my $second = $6;

  # Now set ORACTIME to be decimal UT date.
  my $date = $year . $month . $day;
  my $time = $hour / 24 + ( $minute / ( 24 * 60 ) ) + ( $second / ( 24 * 60 * 60 ) );

  $self->hdr('ORACTIME', $date + $time);

  $new{'ORACTIME'} = $date + $time;

  # ORACUT is just $date.
  $self->hdr('ORACUT', $date );
  $new{'ORACUT'} = $date;

  # And set up the ORACDATETIME header too.
  $dateobs =~ s/Z//g;
  $self->hdr( 'ORACDATETIME', $dateobs );
  $new{'ORACDATETIME'} = $dateobs;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
