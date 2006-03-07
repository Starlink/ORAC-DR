package ORAC::Group::IRIS2;

=head1 NAME

ORAC::Group::IRIS2 - IRIS2 class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::IRIS2("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to IRIS2. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::IRIS2> objects.

=cut

# A package to describe a IRIS2 group object for the
# ORAC pipeline

use 5.006;
use Carp;

# standard error module and turn on strict
use warnings;
use strict;

use ORAC::Group::UKIRT;

# Set inheritance
use base qw/ ORAC::Group::NDF /;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for IRIS2 should go here.
my %hdr = (
           DEC_BASE               => "CRVAL2",
           DEC_TELESCOPE_OFFSET   => "TDECOFF",
           DETECTOR_READ_TYPE     => "METHOD",
           EQUINOX                => "EQUINOX",
           EXPOSURE_TIME          => "EXPOSED",
           INSTRUMENT             => "INSTRUME",
           NUMBER_OF_EXPOSURES    => "CYCLES",
           NUMBER_OF_OFFSETS      => "NOFFSETS",
           NUMBER_OF_READS        => "READS",
           OBJECT                 => "OBJECT",
           OBSERVATION_NUMBER     => "RUN",
           OBSERVATION_TYPE       => "OBSTYPE",
           RA_BASE                => "CRVAL1",
           RA_TELESCOPE_OFFSET    => "TRAOFF",
           RECIPE                 => "RECIPE",
           SPEED_GAIN             => "SPEED",
           UTEND                  => "UTEND",
           X_DIM                  => "NAXIS1",
           Y_DIM                  => "NAXIS2",
           X_LOWER_BOUND          => "DETECXS",
           X_REFERENCE_PIXEL      => "CRPIX1",
           X_UPPER_BOUND          => "DETECXE",
           Y_LOWER_BOUND          => "DETECYS",
           Y_REFERENCE_PIXEL      => "CRPIX2",
           Y_UPPER_BOUND          => "DETECYE"
          );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
ORAC::Group::IRIS2->_generate_orac_lookup_methods( \%hdr );

sub _to_AIRMASS_START {
  my $self = shift;
  my $return;
  my $pi = atan2( 1, 1 ) * 4;
  if(defined($self->hdr->{ZDSTART})) {
    $return = 1 / cos( $self->hdr->{ZDSTART} * $pi / 180 );
  }
  return $return;
}

sub _from_AIRMASS_START {
  "ZDSTART", 180 * acos( 1 / $_[0]->uhdr("ORAC_AIRMASS_START") ) / 3.14159;
}

sub _to_AIRMASS_END {
  my $self = shift;
  my $return;
  my $pi = atan2( 1, 1 ) * 4;
  if(defined($self->hdr->{ZDEND})) {
    $return = 1 / cos( $self->hdr->{ZDEND} * $pi / 180 );
  }
  return $return;
}

sub _from_AIRMASS_END {
  "ZDEND", 180 * acos( 1 / $_[0]->uhdr("ORAC_AIRMASS_END") ) / 3.14159;
}

sub _to_GAIN {
  5.2; # hardwire in gain for now
}

sub _to_OBSERVATION_MODE {
  my $self = shift;
  my $return;
  if( $self->hdr->{IR2_GRSM} =~ /^(SAP|SIL)/i ) {
    $return = "spectroscopy";
  } else {
    $return = "imaging";
  }
  return $return;
}

sub _to_NSCAN_POSITIONS {
  1;
}

sub _to_SCAN_INCREMENT {
  1;
}

sub _to_FILTER {
  my $self = shift;
  my $return;

  if( $self->hdr->{IR2_FILT} =~ /^hole12$/i ) {
    $return = $self->hdr->{IR2_COLD};
  } else {
    $return = $self->hdr->{IR2_FILT};
  }
  $return =~ s/ //g;
  return $return;
}

sub _to_GRATING_DISPERSION {
  my $self = shift;
  my $return;

  my $grism = $self->hdr->{IR2_GRSM};
  my $filter;
  if( $self->hdr->{IR2_FILT} =~ /^OPEN$/i ) {
    $filter = $self->hdr->{IR2_COLD};
  } else {
    $filter = $self->hdr->{IR2_FILT};
  }
  $grism =~ s/ //g;
  $filter =~ s/ //g;
  if ( $grism =~ /^(sap|sil)/i ) {
    if ( uc($filter) eq 'K' || uc($filter) eq 'KS' ) {
      $return = 0.000445;
    } elsif ( uc($filter) eq 'J' ) {
      $return = 0.000233;
    }
  }
  return $return;
}

sub _to_GRATING_WAVELENGTH {
  my $self = shift;
  my $return;

  my $grism = $self->hdr->{IR2_GRSM};
  my $filter;
  if($self->hdr->{IR2_FILT} =~ /^hole12$/i ) {
    $filter = $self->hdr->{IR2_COLD};
  } else {
    $filter = $self->hdr->{IR2_FILT};
  }
  $grism =~ s/ //g;
  $filter =~ s/ //g;
  if ( $grism =~ /^(sap|sil)/i ) {
    if ( uc( $filter ) eq 'K' || uc( $filter ) eq 'KS' ) {
      $return = 2.222835;
    } elsif ( uc( $filter ) eq 'J' ) {
      $return = 1.205480;
    }
  }
  return $return;
}

sub _to_UTSTART {
  my $self = shift;
  my ($hour, $minute, $second) = split( /:/, $self->hdr->{UTSTART} );
  $hour + ($minute / 60) + ($second / 3600);
}

sub _from_UTSTART {
  my $dechour = $_[0]->uhdr("ORAC_UTSTART");
  my ($hour, $minute, $second);
  $hour = int( $dechour );
  $minute = int( ( $dechour - $hour ) * 60 );
  $second = int( ( ( ( $dechour - $hour ) * 60 ) - $minute ) * 60 );
  "UTSTART", ( join ':', $hour,
                         '0'x(2-length($minute)) . $minute,
                         '0'x(2-length($second)) . $second );
}

sub _to_UTDATE {
  my $self = shift;
  my ($year, $month, $day) = split( /:/, $self->hdr->{UTDATE} );
  join '', $year, $month, $day;
}

sub _from_UTDATE {
  my $utdate = $_[0]->uhdr("ORAC_UTDATE");
  my ($year, $month, $day);
  $utdate =~ /(\d{4})(\d{2})(\d{2})/;
  ( $year, $month, $day ) = ($1, $2, $3);
  join ':', $year, $month, $day;
}

# ROTATION, DEC_SCALE and RA_SCALE transformations courtesy Micah Johnson, from
# the cdelrot.pl script supplied for use with XIMAGE.

sub _to_ROTATION {
  my $self = shift;
  my $cd11 = $self->hdr->{CD1_1};
  my $cd12 = $self->hdr->{CD1_2};
  my $cd21 = $self->hdr->{CD2_1};
  my $cd22 = $self->hdr->{CD2_2};
  my $sgn;
  if( ( $cd11 * $cd22 - $cd12 * $cd21 ) < 0 ) { $sgn = -1; } else { $sgn = 1; }
  my $cdelt1 = $sgn * sqrt( $cd11**2 + $cd21**2 );
  my $sgn2;
  if( $cdelt1 < 0 ) { $sgn2 = -1; } else { $sgn2 = 1; }
  my $rad = 57.2957795131;
  $rad * atan2( -$cd21 / $rad, $sgn2 * $cd11 / $rad );
}

sub _to_DEC_SCALE {
  my $self = shift;
  my $cd11 = $self->hdr->{CD1_1};
  my $cd12 = $self->hdr->{CD1_2};
  my $cd21 = $self->hdr->{CD2_1};
  my $cd22 = $self->hdr->{CD2_2};
  my $sgn;
  if( ( $cd11 * $cd22 - $cd12 * $cd21 ) < 0 ) { $sgn = -1; } else { $sgn = 1; }
  abs( sqrt( $cd11**2 + $cd21**2 ) * 3600 );
}

sub _to_RA_SCALE {
  my $self = shift;
  my $cd12 = $self->hdr->{CD1_2};
  my $cd22 = $self->hdr->{CD2_2};
  sqrt( $cd12**2 + $cd22**2 ) * 3600;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::IRIS2> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::IRIS2;
   $Grp = new ORAC::Group::IRIS2("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'gi'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Do not pass objects if the constructor required
  # knowledge of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

  # Configure it
  $group->fixedpart('gi');
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

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames. For IRIS2 this
number is decimal UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # headers
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME - same format as SCUBA uses

  # First get the time of day
  my $time = $self->hdr('UTSTART');
  if (defined $time) {
    # Need to split on :
    my ($h,$m,$s) = split(/:/,$time);
    $time = $h + $m/60 + $s/3600;
  } else {
    $time = 0;
  }

  # Now get the UT date
  my $date = $self->hdr('UTDATE');
  if (defined $date) {
    my ($y,$m,$d) = split(/:/, $date);
    $date = $y . '0'x (2-length($m)) . $m . '0'x (2-length($d)) . $d;
  } else {
    $date = 0;
  }

  my $ut = $date + ( $time / 24.0 );

  # Update the header
  $self->hdr('ORACTIME', $ut);
  $self->hdr('ORACUT',   $date);

  $new{'ORACTIME'} = $ut;
  $new{ORACUT} = $date;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
