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
use NDF;
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
  return if ( ! defined( $utstart ) );
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
  return if ( ! defined( $utend ) );
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

=item B<framegroup>

Create new instances of objects (of this class) from the input files
in the current frame.

 @frames = ORAC::Frame->framegroup( @files );

For ACSIS a single frame object is returned for single sub-system observations
and multiple frame objects returned in multi-subsystem mode. One caveat is that
if the multi-subsystem mode looks like a hybrid mode (bandwidth mode and IF frequency
identical) then a single frame object is returned.

=cut

sub framegroup {
  my $class = shift;

  my %groupings;

  # For each file, we need to read its header and create a hash of
  # arrays with the key being the value of the BWMODE and IFFREQ headers and the
  # value being the filename. SUBSYSNR does not handle the hybrid modes that are meant
  # to be combined.
  foreach my $filename ( @_ ) {

    my $hdr = new Astro::FITS::Header::NDF( File => $filename );
    tie my %header, "Astro::FITS::Header", $hdr;
    push @{$groupings{$header{BWMODE}.$header{IFFREQ}}}, $filename;
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

  if( ! defined( $self->hdr ) || scalar( keys( %{$self->hdr} ) ) == 0 ) {
    $self->readhdr;
  }

  # Get the generic headers from the base class and append RA/Dec/Freq bounds information
  my $header = $self->SUPER::collate_headers( $file );
  my $bounds_header = return_bounds_header( $file );

  # Store the items so that we only append once for efficiency
  my @toappend;
  @toappend = $bounds_header->allitems if defined $bounds_header;

  # Calculate MJD-OBS and MJD-END from DATE-OBS and DATE-END.
  my $dateobs = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-OBS" ) );
  my $dateend = DateTime::Format::ISO8601->parse_datetime( $self->hdr( "DATE-END" ) );
  my $mjdobs = new Astro::FITS::Header::Item( Keyword => 'MJD-OBS',
                                              Value   => $dateobs->mjd,
                                              Comment => 'MJD of start of observation',
                                              Type    => 'FLOAT' );
  my $mjdend = new Astro::FITS::Header::Item( Keyword => 'MJD-END',
                                              Value   => $dateend->mjd,
                                              Comment => 'MJD of end of observation',
                                              Type    => 'FLOAT' );
  push(@toappend, $mjdobs, $mjdend);

  # Set the ASN_TYPE header.
  my $asntype = new Astro::FITS::Header::Item( Keyword => 'ASN_TYPE',
                                               Value   => 'obs',
                                               Comment => 'Time-based selection criterion',
                                               Type    => 'STRING' );
  push(@toappend, $asntype);

  $header->append( \@toappend );
  return $header;
}


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

    # Get the WCS.
    $self->read_wcs;
    my $wcs = $self->wcs;

    # Check to see what tracking system we're in. To get this, we need
    # to make some NDF calls to get into the JCMTSTATE structure.
    my $trsys;
    my $status = &NDF::SAI__OK;
    ndf_begin();
    ndf_find( &NDF::DAT__ROOT(), $self->file, my $indf, $status );
    ndf_xstat( $indf, 'JCMTSTATE', my $there, $status );

    if( $there ) {
      ndf_xloc( $indf, 'JCMTSTATE', 'READ', my $xloc, $status );
      dat_there( $xloc, 'TCS_TR_SYS', my $trsys_there, $status );

      if( $trsys_there ) {
        my( @trsys, $el );
        cmp_getvc( $xloc, 'TCS_TR_SYS', 10000, @trsys, $el, $status );
        if( $status == &NDF::SAI__OK ) {
          $trsys = $trsys[0];
        }
      }
      dat_annul( $xloc, $status );
    }

    ndf_annul( $indf, $status );
    ndf_end( $status );

    if( defined( $trsys ) && $trsys =~ /APP/ ) {

      # We're tracking in geocentric apparent, so instead of using the
      # RefRA/RefDec position (which will be moving with the object)
      # use the object name.
      $hdrgrp = $self->hdr( "OBJECT" );

    } else {

      # Use the RefRA/RefDec position with colons stripped out and to
      # the nearest arcsecond.
      my $refra = $wcs->GetC("RefRA");
      my $refdec = $wcs->GetC("RefDec");
      $refra =~ s/\..*$//;
      $refdec =~ s/\..*$//;
      $refra =~ s/://g;
      $refdec =~ s/://g;

      $hdrgrp = $refra . $refdec;

    }

    my $restfreq = $wcs->GetC("RestFreq");

    $hdrgrp .= $self->hdr( "BWMODE" ) .
               $self->hdr( "SAM_MODE" ) .
               $self->hdr( "SW_MODE" ) .
               $self->hdr( "INSTRUME" ) .
               $self->hdr( "OBS_TYPE" ) .
               $self->hdr( "IFFREQ" ) .
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

=cut

sub inout {
  my $self = shift;
  my $suffix = shift;

  # Check to see if we have a file number to use. If we don't, then
  # just use the standard inout method (no need to duplicate code).
  if( ! @_ ) {
    if( wantarray ) {
      my ($in, $out) = $self->SUPER::inout( $suffix );
      return ( $in, $out );
    } else {
      my $out = $self->SUPER::inout( $suffix );
      return $out;
    }
  }

  # We have a file number to use, so shift it off the argument list.
  my $number = shift;

  # The suffix of the output file is going to be the given suffix with
  # the zero-padded number appended to the end.
  my $outsuffix = $suffix . sprintf( "%03d", $number );

  my $infile = $self->file( $number );

  # Strip off everything after the last underscore.
  my ( $junk, $fsuffix ) = $self->_split_fname( $infile );

  my @junk = @$junk;

  if( $#junk > 1 && $junk[-1] !~ /^\d+$/ ) {
    @junk = @junk[0..$#junk-1];
  }

  # Strip the leading underscore off the new suffix.
  $outsuffix =~ s/^_//;
  push( @junk, $outsuffix );

  my $outfile = $self->_join_fname( \@junk, '' );

  # Generate a warning if output file equals input file
  orac_warn("inout - output filename equals input filename ($outfile)\n")
    if ($outfile eq $infile);

  return ($infile, $outfile) if wantarray();  # Array context
  return $outfile;                            # Scalar context

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
  return (wantarray ? @numbers : scalar(@numbers));
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
