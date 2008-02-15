package ORAC::Frame::JCMT_DAS;

=head1 NAME

ORAC::Frame::JCMT_DAS - DAS class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::JCMT_DAS;

  $Frm = new ORAC::Frame::JCMT_DAS("filename");
  $Frm->file("file");
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to DAS observations taken at the JCMT. It provides
a class derived from B<ORAC::Frame>. All the methods available to
B<ORAC::Frame> objects are available to B<ORAC::Frame::JCMT_DAS> objects.
Some additional methods are supplied.

=cut

# Standard error module and turn on strict.
use Carp;
use strict;
use 5.006;
use warnings;
use ORAC::Frame::GSD;
use ORAC::Constants;
use ORAC::Print;

use vars qw/ $VERSION /;

# Let the object know that it is derived from ORAC::Frame
use base qw/ ORAC::Frame::GSD /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# For reading in the header.
use GSD;

=head1 PUBLIC METHODS

The following are modifications to standard ORAC::Frame methods.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::DAS> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::DAS;
   $Frm = new ORAC::Frame::DAS("file_name");
   $Frm = new ORAC::Frame::DAS("UT","number");

This method runs the base class constructor and then modifies
the rawsuffix and rawfixedpart to be '.dat' and '_das_'
respectively. As such, it can only be used on data at JCMT.

=cut

sub new {

  my $proto = shift;
  my $class = ref( $proto ) || $proto;

  my $self = $class->SUPER::new( );

  # Configure the initial state.
  $self->rawfixedpart('obs_het_');
  $self->rawsuffix('.dat');
  $self->rawformat('GSD');
  $self->format('GSD');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 Subclassed Methods

The following methods are provided for manipulating
B<ORAC::Frame::DAS> objects. These methods override those
provided by B<ORAC::Frame>.

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

ORACTIME is calculated - this is the time of the observation as
UT day + fraction of day.

ORACUT is simply read from UTDATE converted to YYYYMMDD.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();

  my $ut = $self->hdr('C3DAT');
  my $time = $self->hdr('C3UT');

  # At this point $ut is in YYYY.MMDD and $time is decimal hours.
  # We want it so ORACTIME is in decimal UT date and ORACUT is YYYYMMDD.

  my $oracut;
  ( $oracut = $ut ) =~ s/\.//g;

  my $oractime = $oracut + ( $time / 24.0 );

  # Update the headers.
  $self->hdr( 'ORACTIME', $oractime );
  $self->hdr( 'ORACUT', $oracut );

  $new{'ORACTIME'} = $oractime;
  $new{'ORACUT'} = $oracut;

  return %new;
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), and findrecipe() methods
are invoked by this command. Arguments are required.
If there is one argument it is assumed that this is the
raw filename. If there are two arguments the filename is
constructed assuming that arg 1 is the prefix and arg2 is the
observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

=cut

sub configure {
  my $self = shift;

  # Run base class configure.
  $self->SUPER::configure( @_ );

  # Return something.
  return 1;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied. For DAS observations the prefix is ignored.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and the two may be used interchangably for JCMT_DAS.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = '0'x(4-length($obsnum)) . $obsnum;

  # DAS summit naming
  return $self->rawfixedpart . $padnum . $self->rawsuffix;
}

=item B<findgroup>

Return the group associated with the Frame. This group is constructed
from header information. The group name is automatically updated in
the object via the group() method.

The group membership can be set using the DRGROUP keyword in the
header. If this keyword exists and is not equal to 'UNKNOWN' the
contents will be returned.

Alternatively, if DRGROUP is not specified the group name is constructed
from the following keywords: C1SNA1 (target name), C6MODE (switch mode),
C4ODCO (observation mode), C3CONFIGNR (DAS configuration mode), C12BW
(bandwidth), C7VR (target velocity), C12VREF (target velocity reference
frame), and C12RF (rest frequency). Other keywords are used depending on
various modes. If the switch mode is beam, then the C4THROW (chop throw)
and C4POSANGLE (chop angle) keywords are also used. If the switch mode
is frequency, then the XXXXXXX (unknown) keyword is also used. If the
observation mode is sample, then the C4RA2000 (RA in J2000), C4EDEC2000
(Dec in J2000), C4SX (x offset position) and C4SY (y offset position)
keywords are also used.

=cut

sub findgroup {
  my $self = shift;
  my $group;

  if (exists $self->hdr->{DRGROUP} && $self->hdr->{DRGROUP} ne 'UNKNOWN'
      && $self->hdr->{DRGROUP} =~ /\w/) {
    $group = $self->hdr->{DRGROUP};
  } else {
    # construct group name

    $group = ( defined( $self->hdr('C1SNA1') ) ? $self->hdr('C1SNA1') : '' ) .
             ( defined( $self->hdr('C6MODE') ) ? $self->hdr('C6MODE') : '' ) .
             ( defined( $self->hdr('C4ODCO') ) ? $self->hdr('C4ODCO') : '' ) .
             ( defined( $self->hdr('C3CONFIG') ) ? $self->hdr('C3CONFIG') : '' ) .
#             $self->hdr('C12BW') .
             ( defined( $self->hdr('C7VR') ) ? $self->hdr('C7VR') : '' ) .
             ( defined( $self->hdr('C12VREF') ) ? $self->hdr('C12VREF') : '' );
#             $self->hdr('C12RF');

    # Now the extra bits. First, check if the switch mode
    # (contained in C6MODE) is BEAMSWITCH.
    if( defined( $self->hdr('C6MODE') ) &&
        $self->hdr('C6MODE') eq 'BEAMSWITCH' ) {
      $group .= ( defined( $self->hdr('C4THROW') ) ? $self->hdr('C4THROW') : '' ) .
                ( defined( $self->hdr('C4POSANGLE') ) ? $self->hdr('C4POSANGLE') : '' );
    }

    # Check if switch mode is FREQ_SWITCH.
    if( defined( $self->hdr('C6MODE') ) &&
        $self->hdr('C6MODE') eq 'FREQ_SWITCH' ) {

    }

    # Check if the observation mode (in C4ODCO) is SAMPLE.
    if( defined( $self->hdr('C4ODCO') ) &&
        $self->hdr('C4ODCO') eq 'SAMPLE' ) {
      $group .= ( defined( $self->hdr('C4RA2000') ) ? $self->hdr('C4RA2000') : '' ) .
                ( defined( $self->hdr('C4EDEC2000') ) ? $self->hdr('C4EDEC2000') : '' ) .
                ( defined( $self->hdr('C4SX') ) ? $self->hdr('C4SX') : '' ) .
                ( defined( $self->hdr('C4SY') ) ? $self->hdr('C4SY') : '' );
    }

  }

  # Update $group
  $self->group($group);

  return $group;
}

=item B<findrecipe>

Return the recipe associated with the frame. The state of the
object is automatically updated via the recipe() method.

The recipe is determined by looking in the FITS header of the
frame. If the 'DRRECIPE' header is present and not set to
'UNKNOWN' then that is assumed to specify the recipe directly.
Otherwise, the recipe is set to 'REDUCE_DAS'.

=cut

sub findrecipe {
  my $self = shift;

  my $recipe = undef;
  if( defined( $self->hdr('DRRECIPE') ) &&
      $self->hdr('DRRECIPE') ne 'UNKNOWN' &&
      $self->hdr('DRRECIPE') =~ /\w/) {
    $recipe = $self->hdr('DRRECIPE');
  } else {
    $recipe = 'REDUCE_DAS';
  }

  # Update the recipe.
  $self->recipe($recipe);

  return $recipe;
}

=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Frame::GSD>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
