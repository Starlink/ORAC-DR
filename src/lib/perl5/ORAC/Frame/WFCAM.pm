package ORAC::Frame::WFCAM;

=head1 NAME

ORAC::Frame::WFCAM - WFCAM class for dealing with observation files in
ORAC-DR with Starlink software.

=head1 SYNOPSIS

  use ORAC::Frame::WFCAM;

  $Frm = new ORAC::Frame::FWCAM("filename");
  $Frm->file("file");
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to WFCAM, allowing them to be reduced using Starlink software.
It provides a class derived from B<ORAC::Frame::WFCAM>. All the methods
available to B<ORAC::Frame::WFCAM> objects are available to
B<ORAC::Frame::WFCAM> objects. Some additional methods are supplied.

=cut

# standard error module and turn on strict
use Carp;
use strict;

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::CGS4;
use ORAC::Constants;

use NDF;
use Starlink::HDSPACK qw/ copobj /;

use base qw/ ORAC::Frame::CGS4 /;

'$Revision$' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

*pattern_from_bits = \&file_from_bits;

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

Create a new instance of a B<ORAC::Frame::WFCAM> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::WFCAM;
   $Frm = new ORAC::Frame::WFCAM("file_name");
   $Frm = new ORAC::Frame::WFCAM("UT","number");

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
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 General Methods

=over 4

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

=item B<mergehdr>

Method to propagate the FITS header from an HDS container to an NDF
Run after updating $Frm.

 $Frm->files($out);
 $Frm->mergehdr;

=cut

sub mergehdr {

  my $self = shift;
  my $status;

  my $old = ${$self->intermediates}[-2];
  if( ! defined $old ) {
    $old = $self->raw;
  }
  my $new = $self->file;

  my ($root, $rest) = $self->_split_name($old);

  if (defined $rest) {
    $status = &NDF::SAI__OK;

    # Begin NDF context
    ndf_begin();

    # Open the file
    ndf_find(&NDF::DAT__ROOT(), $root . '.header', my $indf, $status);

    # Get the fits locator
    ndf_xloc($indf, 'FITS', 'READ', my $xloc, $status);

    # Find out how many entries we have
    my $maxdim = 7;
    my @dim = ();
    dat_shape($xloc, $maxdim, @dim, my $ndim, $status);

    # Must be 1D
    if ($status == &NDF::SAI__OK && scalar(@dim) > 1) {
      $status = &NDF::SAI__ERROR;
      err_rep(' ',
              "hsd2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",
              $status);
    }

    # Read the FITS array
    my @fitsA = ();
    my $nfits;
    dat_get1c($xloc, $dim[0], @fitsA, $nfits, $status)
      if $status == &NDF::SAI__OK; # -w protection
		
    # Close the NDF file
    dat_annul($xloc, $status);
    ndf_annul($indf, $status);
		
    # Now we need to open the input file and modify the FITS entries
    ndf_open(&NDF::DAT__ROOT, $new, 'UPDATE', 'OLD', $indf, my $place,
             $status);
		
    # Check to see if there is a FITS component in the output file
    ndf_xstat($indf, 'FITS', my $there, $status);
    my @fitsB = ();
    if (($status == &NDF::SAI__OK) && ($there)) {
			
      # Get the fits locator (note the deja vu)
      ndf_xloc($indf, 'FITS', 'UPDATE', $xloc, $status);
			
      # Find out how many entries we have
      dat_shape($xloc, $maxdim, @dim, $ndim, $status);
			
      # Must be 1D
      if ($status == &NDF::SAI__OK && scalar(@dim) > 1) {
        $status = &NDF::SAI__ERROR;
        err_rep(' ',
                "hds2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",
                $status
               );
      }
			
      # Read the second FITS array
      dat_get1c($xloc, $dim[0], @fitsB, $nfits, $status)
        if $status == &NDF::SAI__OK; # -w protection
			
      # Annul the locator
      dat_annul($xloc, $status);
      ndf_xdel($indf,'FITS', $status);
    }

    # Remove duplicate headers
    my %f = map { $_, undef } @fitsA;
    @fitsB = grep { !exists $f{$_} } @fitsB;

    # Merge arrays
    push(@fitsA, @fitsB);

    # Now resize the FITS extension by deleting and creating
    # (cmp_modc requires the parent locator)
    $ndim = 1;
    $nfits = scalar(@fitsA);
    my @nfits = ($nfits);
    ndf_xnew($indf, 'FITS', '_CHAR*80', $ndim, @nfits, $xloc, $status);
		
    # Upload the FITS entries
    dat_put1c($xloc, $nfits, @fitsA, $status);
		
    # Shutdown
    dat_annul($xloc, $status);
    ndf_annul($indf, $status);
    ndf_end($status);
		
    if ($status != &NDF::SAI__OK) {
      err_flush($status);
      err_end($status);
    }
  }
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

=head1 PRIVATE METHODS

=over 4

=item B<_split_name>

Internal routine to split a 'file' name into an actual
filename (the HDS container) and the NDF name (the
thing inside the container).

Splits on '.'

Argument: string to split (eg test.i1)
Returns:  root name, ndf name (eg 'test' and 'i1')

NDF name is undef if there are no 'sub-frames'.

This routine is so simple that it may not be worth the effort.

=cut

sub _split_name {
  my $self = shift;
  my $file  = shift;

  # Split on '.'
  my ($root, $rest) = split(/\./, $file, 2);

  return ($root, $rest);
}

=back

=head1 OLD CASU STUFF

=cut

# Keywords for primary header unit

my @phukeys = ("DATE","ORIGIN","TELESCOP","INSTRUME","DHSVER","HDTFILE",
	       "OBSERVER","USERID","OBSREF","PROJECT","SURVEY","SURVEY_I",
	       "MSBID","RMTAGENT","AGENTID","OBJECT","RECIPE","OBSTYPE",
	       "OBSNUM","GRPNUM","GRPMEM","TILENUM","STANDARD","NJITTER",
	       "JITTER_I","JITTER_X","JITTER_Y","NUSTEP","USTEP_I","USTEP_X",
	       "USTEP_Y","FILTER","UTDATE","UTSTART","UTEND","DATE-OBS",
	       "DATE-END","MJD-OBS","WCSAXES","RADESYS","EQUINOX","TRACKSYS",
	       "RABASE","DECBASE","TRAOFF","TDECOFF","AMSTART","AMEND","TELRA",
	       "TELDEC","GSRA","GSDEC","READMODE","EXP_TIME","NEXP","NINT",
	       "READINT","NREADS","AIRTEMP","BARPRESS","DEWPOINT","DOMETEMP",
	       "HUMIDITY","MIRR_NE","MIRR_NW","MIRR_SE","MIRR_SW","MIRRBTNW",
	       "MIRRTPNW","SECONDAR","TOPAIRNW","TRUSSENE","TRUSSWSW",
	       "WIND_DIR","WIND_SPD","CSOTAU","TAUDATE","TAUSRC","M2_X","M2_Y",
	       "M2_Z","M2_U","M2_V","M2_W","TCS_FOC","FOC_POSN","FOC_ZERO",
	       "FOC_OFFS","FOC_FOFF","FOC_I","FOC_OFF","NFOC","NFOCSCAN");

# Keywords for extension header unit

my @ehukeys = ("INHERIT","DETECTOR","DETECTID","DROWS","DCOLUMNS",
	       "RDOUT_X1","RDOUT_X2","RDOUT_Y1","RDOUT_Y2","PIXLSIZE","GAIN",
	       "CAMNUM","HDTFILE2","DET_TEMP","CNFINDEX","PCSYSID","SDSUID",
	       "READOUT","CAPPLICN","CAMROLE","CAMPOWER","RUNID","CTYPE1",
	       "CTYPE2","CRPIX1","CRPIX2","CRVAL1","CRVAL2","CRUNIT1",
	       "CRUNIT2","CD1_1","CD1_2","CD2_1","CD2_2","PV2_1","PV2_2",
	       "PV2_3");

=over 4

=item B<phukeys>

Returns the list of primary header unit keywords 
    @phukeys = $Frm->phukeys;

=cut

sub phukeys {
    my $self = shift;

    return(@phukeys);
}

=item B<ehukeys>

Returns the list of extension header unit keywords 
    @ehukeys = $Frm->ehukeys;

=cut

sub ehukeys {
    my $self = shift;

    return(@ehukeys);
}

=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>

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

