package ORAC::Group::SWFCAM;

=head1 NAME

ORAC::Group::SWFCAM - class for dealing with WFCAM observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group::SWFCAM;

  $Grp = new ORAC::Group::SWFCAM("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to WFCAM. It provides a class derived from B<ORAC::Group::UFTI>.
All the methods available to ORAC::Group objects are available
to B<ORAC::Group::SWFCAM> objects.

=cut

# A package to describe a SWFCAM group object for the
# ORAC pipeline.

use 5.006;
use strict;
use warnings;
use vars qw/$VERSION/;
use ORAC::Group::UFTI;
use ORAC::General;

# Set inheritance.
use base qw/ ORAC::Group::UFTI /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for WFCAM should go here.
my %hdr = (
           EXPOSURE_TIME        => "EXP_TIME",
           DEC_BASE             => "DECBASE",
           DEC_TELESCOPE_OFFSET => "TDECOFF",
           DETECTOR_READ_TYPE   => "READOUT",
           EQUINOX              => "EQUINOX",
           GAIN                 => "GAIN",
           INSTRUMENT           => "INSTRUME",
           NUMBER_OF_EXPOSURES  => "NEXP",
           OBJECT               => "OBJECT",
           OBSERVATION_NUMBER   => "OBSNUM",
           OBSERVATION_TYPE     => "OBSTYPE",
           RA_BASE              => "RABASE",
           RA_TELESCOPE_OFFSET  => "TRAOFF",
           RECIPE               => "RECIPE",
           STANDARD             => "STANDARD",
           UTDATE               => "UTDATE",
           UTEND                => "UTEND",
           UTSTART              => "UTSTART",
           X_LOWER_BOUND        => "RDOUT_X1",
           X_REFERENCE_PIXEL    => "CRPIX1",
           X_UPPER_BOUND        => "RDOUT_X2",
           Y_LOWER_BOUND        => "RDOUT_Y1",
           Y_REFERENCE_PIXEL    => "CRPIX2",
           Y_UPPER_BOUND        => "RDOUT_Y2",
          );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Group::SWFCAM->_generate_orac_lookup_methods( \%hdr );

# Set the group fixed parts for the four chips.
my %groupfixedpart = ( '1' => 'gw',
                       '2' => 'gx',
                       '3' => 'gy',
                       '4' => 'gz',
                       '5' => 'gv',
                     );

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Group.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group::SWFCAM> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group::SWFCAM;
   $Grp = new ORAC::Group::SWFCAM("group_name");

This method calls the base class constructor but initialises
the group with a file suffix of '.sdf' and a fixed part
of 'g'.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

# Do not pass objects if the constructor required knowledge
# of fixedpart() and filesuffix()
  my $group = $class->SUPER::new(@_);

# Which WFCAM chip is this? We need to know so we know what
# to call the group file.
  my $fixedpart;
  if( $ENV{'ORAC_INSTRUMENT'} =~ /^SWFCAM([1-5])$/ ) {
    $fixedpart = $groupfixedpart{$1};
  } else {
    $fixedpart = $groupfixedpart{'1'};
  }

# Configure the object.
  $group->fixedpart($fixedpart);
  $group->filesuffix('.sdf');

# And return the new object.
  return $group;
}

=back

=head2 General Methods

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

ORACTIME Is calculated - this is the time of the observation
as UT day + fraction of day.

ORACUT is simply YYYYMMDD.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

This method updates the frame header. Returns a hash containing
the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

# Run the base class first to get the ORAC_ headers.
  my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# For WFCAM this comes from DATE-OBS, which is in the
# form YYYY-MM-DDThh:mm:ssZ. We need to convert that into
# YYYYMMDD.fraction
  my $ut = $self->hdr("DATE-OBS");
  $ut =~ /(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z/;
  my $utdate = '0'x(4-length(int($1))) . $1 .
               '0'x(2-length(int($2))) . $2 .
               '0'x(2-length(int($3))) . $3;

  my $uttime = ( $4 / 24 ) + ( $5 / 1440 ) + ( $6 / 86400 );

  $self->hdr("ORACTIME", $utdate + $uttime);
  $new{'ORACTIME'} = $utdate + $uttime;

# And ORACUT. Since this is YYYYMMDD, we've already got
# it in $utdate.
  $self->hdr("ORACUT", $utdate);
  $new{'ORACUT'} = $utdate;

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
