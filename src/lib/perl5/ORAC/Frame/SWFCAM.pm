package ORAC::Frame::SWFCAM;

=head1 NAME

ORAC::Frame::SWFCAM - WFCAM class for dealing with observation files in ORAC-DR with Starlink software.

=head1 SYNOPSIS

  use ORAC::Frame::SWFCAM;

  $Frm = new ORAC::Frame::SFWCAM("filename");
  $Frm->file("file");
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to WFCAM, allowing them to be reduced using Starlink software.
It provides a class derived from B<ORAC::Frame::WFCAM>. All the methods
available to B<ORAC::Frame::WFCAM> objects are available to
B<ORAC::Frame::SWFCAM> objects. Some additional methods are supplied.

=cut

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UFTI;
use ORAC::Constants;

use base qw/ ORAC::Frame::UFTI /;

'$Revision$' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

*pattern_from_bits = \&file_from_bits;

# standard error module and turn on strict
use Carp;
use strict;

# Translation tables for WFCAM should go here.

my %hdr = (
            DEC_BASE             => "DECBASE",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            DETECTOR_READ_TYPE   => "READOUT",
            EQUINOX              => "EQUINOX",
            EXPOSURE_TIME        => "EXP_TIME",
            FILTER               => "FILTER",
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
            X_UPPER_BOUND        => "RDOUT_X2",
            Y_LOWER_BOUND        => "RDOUT_Y1",
            Y_UPPER_BOUND        => "RDOUT_Y2"
          );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.

ORAC::Frame::SWFCAM->_generate_orac_lookup_methods( \%hdr );

sub _to_NUMBER_OF_OFFSETS {
  my $self = shift;
  my $njitter = $self->hdr->{NJITTER};
  my $nustep = $self->hdr->{NUSTEP};

  return $njitter * $nustep + 1;

}

sub _to_DEC_SCALE {
  return 0.4;
}

sub _to_RA_SCALE {
  return 0.4;
}

# Set the raw fixed parts for the four chips.
my %rawfixedparts = ('1' => 'w',
                     '2' => 'x',
                     '3' => 'y',
                     '4' => 'z',
                     '5' => 'v',);

# PROJP3: The cubic distortion coefficient for ZPN projection
my $projp3 = 220.0;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to those
available from B<ORAC::Frame::WFCAM>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::SWFCAM> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::SWFCAM;
   $Frm = new ORAC::Frame::SWFCAM("file_name");
   $Frm = new ORAC::Frame::SWFCAM("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods. The prefix depends
on the value of the ORAC_INSTRUMENT environment variable;
if this is set to WFCAM1, WFCAM2, WFCAM3, or WFCAM4, then
the prefix is set to 'w', 'x', 'y', or 'z', respectively.
Otherwise the prefix defaults to 'w'.

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

  # Which WFCAM chip is this?
  if( $ENV{'ORAC_INSTRUMENT'} =~ /^WFCAM([1-5])$/ ) {
    $self->rawfixedpart($rawfixedparts{lc($1)});
  } else {
    $self->rawfixedpart("w");
  }

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawsuffix('.sdf');
  $self->rawformat('HDS');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=head2 General Methods

=over 4

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

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5 digit obsnum

  my $padnum = sprintf("%05d",$obsnum);

  return $self->rawfixedpart . $prefix . "_" . $padnum . $self->rawsuffix;
}

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  my $raw = $self->pattern_from_bits( $prefix, $obsnum );

  $raw =~ /^(.*?)\.(.*?)$/;
  my $flag = "." . $1 . ".ok";

  return $flag;
}

=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number at the end of the raw data
filename.  For example a number can be extracted from strings of the
form textNNNN.sdf or textNNNN, where NNNN is a number (leading zeroes
are stripped) but not textNNNNtext (number must be followed by a decimal
point or nothing at all).

  $number = $Frm->number;

The return value is -1 if no number can be determined.

As an aside, an alternative approach for this method (especially
in a sub-class) would be to read the number from the header.

=cut

sub number {
  my $self = shift;

  my ($number);

  # Get the number from the raw data
  # Assume there is a number at the end of the string
  # (since the extension has already been removed)
  # Leading zeroes are dropped

  my $raw = $self->raw;
  if (defined $raw && $raw =~ /(\d+)(_raw)?(\.\w+)?$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}

=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;

