package ORAC::Frame::LCOSINISTRO;

=head1 NAME

ORAC::Frame::LCOSINISTRO - class for dealing with LCO Sinistro 1.0m
observation files in ORAC-DR

This module provides methods for handling Frame objects that are
specific to SBIG. It provides a class derived from
B<ORAC::Frame::LCO>.

=cut

# A package to describe a LCOSBIG group object for the
# ORAC pipeline

# standard error module and turn on strict
use Carp;
use strict;

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::LCO;
use ORAC::Constants;
use ORAC::Print;
use NDF;
use Starlink::HDSPACK qw/copobj/;

# Let the object know that it is derived from ORAC::Frame::LCO;
use base qw/ORAC::Frame::LCO/;

# Alias file_from_bits as pattern_from_bits.
#*pattern_from_bits = \&file_from_bits;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::LCO>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::LCOSINISTRO> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::LCOSINISTRO;
   $Frm = new ORAC::Frame::LCOSINISTRO("file_name");
   $Frm = new ORAC::Frame::LCOSINISTRO("UT","number");

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
  $self->rawfixedpart('bpl1m002-fl01-');
  $self->rawsuffix('.fits');
  $self->rawformat('FITS');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  # Dirty hacks
#  $self->uhdr("ORAC_OBSERVATION_MODE", "imaging");

  return $self;

}


=back

=head2 General Methods

=over 4

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
GMOS.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = $self->_padnum( $obsnum );

  my $flag = "." . $self->rawfixedpart . $prefix . "_" . $padnum . ".ok";
  return $flag;
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

#  my $padnum = $self->_padnum( $obsnum );

  my $letters = '['.$self->_ftypes.']';

  my $pattern = $self->rawfixedpart . $letters . '_' . $prefix . "_" .
    $obsnum . '_\d+_\d_0' . $self->rawsuffix;
  printf "Calling pattern_from_bits\n";
  return qr/$pattern/;
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

  # Get the number from the raw data filename
  # Leading zeroes are dropped
  my $letters = '['.$self->_ftypes.']';

  my $raw = $self->raw;
  my $pattern = '(\d+)-' . $letters . '(\d+)$';
  if (defined $raw && $raw =~ /$pattern/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    printf "No number match\n";
    # No match so set to -1
    $number = -1;
  }

  return $number;

}
=item B<findgroup>

Returns group name from header.  For dark observations the current obs
number is returned if the group number is not defined or is set to zero
(the usual case with IRCAM)

The group name stored in the object is automatically updated using
this value.

=cut

sub findgroup {
  my $self = shift;
#  my $extra = shift;

  my $hdrgrp;
#  use Data::Dumper;print Dumper $self->uhdr;die;
  # Use value in header if present
  if (exists $self->hdr->{DRGROUP} && defined $self->hdr->{DRGROUP}
      && $self->hdr->{DRGROUP} ne 'UNKNOWN'
      && $self->hdr->{DRGROUP} =~ /\w/) {
    $hdrgrp = $self->hdr->{DRGROUP};
  } else {
    # Create our own DRGROUP string

    $hdrgrp .=  uc($self->hdr( "OBSTYPE" ))
                . '_bin'
		. $self->uhdr( "ORAC_XBINNING" )
		.'x'
		. $self->uhdr( "ORAC_YBINNING" );
    # For non biases and darks, add the filter
    if ( uc( $self->hdr( "OBSTYPE" ) ) ne 'BIAS' and
	 uc( $self->hdr( "OBSTYPE" ) ) ne 'DARK') {
	 $hdrgrp .= "_" . $self->uhdr( "ORAC_FILTER" );
    }
    # For biases and darks, add the molecule number
    if ( uc( $self->hdr( "OBSTYPE" ) ) eq 'BIAS' or
	 uc( $self->hdr( "OBSTYPE" ) ) eq 'DARK') {
	 $hdrgrp .= "_" . $self->hdr( "MOLNUM" );
    }
    # Add DATE-OBS if we *are* doing a science observation,
    # to ensure that they are not combined into groups
    if ( uc( $self->hdr( "OBSTYPE" ) ) eq 'EXPOSE' ) {
      $hdrgrp .= $self->hdr( "DATE-OBS" );
    }

    # Add any extra information from subclass
#    $hdrgrp .= $extra if defined $extra;

  }

#  print "hdrgrp=$hdrgrp\n";
  # Update the group
  $self->group($hdrgrp);

  return $hdrgrp;
}


=item B<framegroupkeys>

For SCUBA-2 a single frame object is returned in most cases. For focus
observations each focus position is returned as a separate Frame
object. This simplifies the recipes and allows the QL and standard
recipes to work in the same way.

Observation number is also kept separate in case the pipeline gets so
far behind that the system detects the end of one observation and the
start of the next.

 @keys = $Frm->framegroupkeys;

=cut

sub framegroupkeys {
  return (qw/ OBSTYPE XBINNING YBINNING ORAC_FILTER ORAC_OBSERVATION_NUMBER/);
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

$fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for GMOS.

=cut

sub file_from_bits {
  die "Use pattern_from_bits() instead.\n";
#  my $self = shift;

#  my $prefix = shift;
#  my $obsnum = shift;

#  return $self->rawfixedpart . 'e_' . $prefix . '_' . $obsnum . '_1_1_0'. $self->rawsuffix;

}


#sub mergehdr {
#
#}

=begin __INTERNAL_METHODS

=head1 PRIVATE METHODS

=over 4

=item B<_padnum>

Pad an observation number.

 $padded = $frm->_padnum( $raw );

=cut

sub _padnum {
  my $self = shift;
  my $raw = shift;
  return sprintf( "%05d", $raw);
}

=item B<_ftypes>

Return the relevant LCO frame types.

  @codes = $frm->_ftypes();
  $codes = $frm->_ftypes();

In scalar context returns a single string with the values concatenated.

=cut

sub _ftypes {
  my $self = shift;
  my @letters = qw/ b d e f l s /;
  return (wantarray ? @letters : join("",@letters) );
}

=back

=end __INTERNAL_METHODS

=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Lister E<lt>tlister@lcogt.netE<gt>,
Paul Hirst <p.hirst@jach.hawaii.edu>
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2013 Las Cumbres Observatory Global Telescope Inc.
All Rights Reserved.

=cut

1;
