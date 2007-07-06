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

use ORAC::Bounds qw/ return_bounds_header /;
use ORAC::Error qw/ :try /;
use ORAC::Print qw/ orac_warn /;

use Astro::Coords;
use DateTime;
use DateTime::Format::ISO8601;
use NDF qw/ :ndf :err /;
use Starlink::AST;

our $VERSION;

use base qw/ ORAC::Frame::NDF /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ( $VERSION = $1 );

use ORAC::Constants;

# HERE BE TRANSLATION TABLES.
my %hdr = ( AIRMASS_START => 'AMSTART',
            AIRMASS_END => 'AMEND',
            CHOP_ANGLE => 'CHOP_PA',
            CHOP_THROW => 'CHOP_THR',
            DEC_BASE => 'CRVAL1',
            DEC_SCALE => 'CDELT1',
            EQUINOX => 'EQUINOX',
            EXPOSURE_TIME => 'INT_TIME',
            GRATING_DISPERSION => 'CDELT3',
            GRATING_WAVELENGTH => 'CRVAL3',
            INSTRUMENT => 'INSTRUME',
            NUMBER_OF_EXPOSURES => 'N_EXP',
            OBJECT => 'OBJECT',
            OBSERVATION_NUMBER => 'OBSNUM',
            RA_BASE => 'CRVAL2',
            RA_SCALE => 'CDELT2',
            RECIPE => 'RECIPE',
            STANDARD => 'STANDARD',
            UTDATE => 'UTDATE',
            WAVEPLATE_ANGLE => 'SKYANG',
          );

# Take this lookup table and generate methods that can be subclassed
# by other instruments. Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Frame::ACSIS->_generate_orac_lookup_methods( \%hdr );

# Now for the translations that require calculations and whatnot.

sub _to_UTSTART {
  my $self = shift;
  my $utstart = $self->hdr->{'DATE-OBS'};
  return undef if ( ! defined( $utstart ) );
  $utstart =~ /T(\d\d):(\d\d):(\d\d)/;
  my $hour = $1;
  my $minute = $2;
  my $second = $3;
  $hour + ( $minute / 60 ) + ( $second / 3600 );
}

sub _from_UTSTART {
  my $starttime = $_[0]->uhdr("ORAC_UTSTART");
  my $startdate = $_[0]->uhdr("ORAC_UTDATE");
  $startdate =~ /(\d{4})(\d\d)(\d\d)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = int( $starttime );
  my $minute = int( ( $starttime - $hour ) * 60 );
  my $second = int( ( ( ( $starttime - $hour ) * 60 ) - $minute ) * 60 );
  my $return = ( join "-", $year, $month, $day ) . "T" . ( join ":", $hour, $minute, $second );
  return "DATE-OBS", $return;
}

sub _to_UTEND {
  my $self = shift;
  my $utend = $self->hdr->{'DATE-END'};
  return undef if ( ! defined( $utend ) );
  $utend =~ /T(\d\d):(\d\d):(\d\d)/;
  my $hour = $1;
  my $minute = $2;
  my $second = $3;
  $hour + ( $minute / 60 ) + ( $second / 3600 );
}

sub _from_UTEND {
  my $endtime = $_[0]->uhdr("ORAC_UTEND");
  my $enddate = $_[0]->uhdr("ORAC_UTDATE");
  $enddate =~ /(\d{4})(\d\d)(\d\d)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = int( $endtime );
  my $minute = int( ( $endtime - $hour ) * 60 );
  my $second = int( ( ( ( $endtime - $hour ) * 60 ) - $minute ) * 60 );
  my $return = ( join "-", $year, $month, $day ) . "T" . ( join ":", $hour, $minute, $second );
  return "DATE-END", $return;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Frame::ACSIS> object. This method
also takes optional arguments:

=item * If one argument is supplied it is assumed to be a reference
to an array containing a list of raw files associated with the
observation.

=item * If two arguments are supplied they are assumed to be the
UT date and observation number.

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

=item B<framegroup>

=cut

sub framegroup {
  my $class = shift;

  my %groupings;

  # For each file, we need to read its header and create a hash of
  # arrays with the key being the value of the SUBSYSNR header and the
  # value being the filename.
  foreach my $filename ( @_ ) {

    my $hdr = new Astro::FITS::Header::NDF( File => $filename );
    tie my %header, "Astro::FITS::Header", $hdr;

    push @{$groupings{$header{SUBSYSNR}}}, $filename;

  }

  # For each one of the groups, we need to create a new Frame object
  # using the filenames listed.
  my @Frms;
  foreach my $files ( values %groupings ) {

    push @Frms, $class->new( $files );

  }

  return @Frms;

}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Should be run after a header is set. Currently the hdr() method
calls this whenever it is updated.

Calculates ORACUT and ORACTIME.

ORACUT is the UT date in YYYYMMDD format.
ORACTIME is the time of the observation in YYYYMMDD.fraction format.

This method updates the frame header.

This method returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # header translations.
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME - in decimal UT days.
  my $uthour = $self->uhdr('ORAC_UTSTART');
  my $utday = $self->uhdr('ORAC_UTDATE');
  $self->hdr('ORACTIME', $utday + ( $uthour / 24 ) );
  $new{'ORACTIME'} = $utday + ( $uthour / 24 );

  # ORACUT - in YYYYMMDD format
  my $ut = $self->uhdr('ORAC_UTDATE');
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);
  $new{'ORACUT'} = $ut;

  return %new;
}

=item B<readhdr>

This method reads the header from the first file in the list of
files for the observation. This method sets the header in the object
(in general that is done by configure() ).

  $Frm->readhdr;

The filename can be supplied if the one stored in the object
is not required:

  $Frm->readhdr($file);

...but the header in $Frm is over-written.

All existing header information is lost. The C<calc_orac_headers>
method is invoked once the header information is read.

If there is an error during the read a reference to an empty hash
is returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no return arguments.

=cut

sub readhdr {
  my $self = shift;

  my ( $ref, $status );

  my $file = ( @_ ? shift : $self->file(1) );

  # Just read the NDF FITS header.
  try {
    my $hdr = new Astro::FITS::Header::NDF( File => $file );

    # Mark it suitable for tie with array return of multi-values...
    $hdr->tiereturnsref(1);

    # ...and store it in the object.
    $self->fits( $hdr );
  };

  # Calculate derived headers.
  $self->calc_orac_headers;

  return;

}

=item B<collate_headers>

This method is used to collect all of the modified FITS headers for a
given Frame object and return an updated C<Astro::FITS::Header> object
to be used by the C<sync_headers> method.

  my $header = $Frm->collate_headers( $file );

Takes one argument, the filename for which the header will be
returned.

=cut

sub collate_headers {
  my $self = shift;
  my $file = shift;

  return unless defined( $file );
  if( $file !~ /\.sdf$/ ) { $file .= ".sdf"; }
  return unless -e $file;

  my $header = $self->SUPER::collate_headers( $file );
  tie my %hdr, "Astro::FITS::Header::NDF", $header, tiereturnsref => 1;

  my $bounds_header = return_bounds_header( $file );
  my $merged;
  my @different;

  ( $merged, @different ) = $header->merge_primary( $bounds_header );

  foreach my $diff ( @different ) {
    foreach my $card ( $diff->allitems ) {
      $merged->append( $card );
    }
  }
  $header = $merged;

  # Calculate MJD-OBS and MJD-END from DATE-OBS and DATE-END.
  my $dateobs = DateTime::Format::ISO8601->parse_datetime( $hdr{'DATE-OBS'} );
  my $dateend = DateTime::Format::ISO8601->parse_datetime( $hdr{'DATE-END'} );
  my $mjdobs = new Astro::FITS::Header::Item( Keyword => 'MJD-OBS',
                                              Value   => $dateobs->mjd,
                                              Comment => 'MJD of start of observation',
                                              Type    => 'FLOAT' );
  my $mjdend = new Astro::FITS::Header::Item( Keyword => 'MJD-END',
                                              Value   => $dateend->mjd,
                                              Comment => 'MJD of end of observation',
                                              Type    => 'FLOAT' );
  $header->append( $mjdobs );
  $header->append( $mjdend );

  # Set the ASN_TYPE header.
  my $asntype = new Astro::FITS::Header::Item( Keyword => 'ASN_TYPE',
                                               Value   => 'obs',
                                               Comment => 'Time-based selection criterion',
                                               Type    => 'STRING' );
  $header->append( $asntype );

  return $header;
}


=item B<file_from_bits>

There is no file_from_bits() for ACSIS. Use pattern_from_bits()
instead.

=cut

sub file_from_bits {
  die "ACSIS has no file_from_bits() method. Use pattern_from_bits() instead\n";
}

sub file_from_bits_extra {
  my $self = shift;
  return $self->hdr( "SUBSYSNR" );
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
    # Construct group name.
    $self->read_wcs;
    my $wcs = $self->wcs;

    my $restfreq = $wcs->GetC("RestFreq");

    $hdrgrp = $self->hdr( "OBJECT" ) .
              $self->hdr( "BWMODE" ) .
              $self->hdr( "INSTRUME" ) .
              $self->hdr( "OBS_TYPE" ) .
              $self->hdr( "IFFREQ" ) .
              $restfreq;
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
  my $self;

  if( ! defined( $self->{AllowHeaderSync} ) ) {
    $self->{AllowHeaderSync} = 1;
  }

  if( @_ ) { $self->{AllowHeaderSync} = shift; }

  return $self->{AllowHeaderSync};
}

=back

=head1 SEE ALSO

L<ORAC::Frame::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
