package ORAC::Convert;

=head1 NAME

ORAC::Convert - Methods for converting data formats

=head1 SYNOPSIS

  use ORAC::Convert

  $conv = new ORAC::Convert;
  $outfile = $conv->convert($infile, {IN => 'FITS', OUT => 'NDF'});

  $outfile = $conv->convert($infile, { OUT => 'NDF'});

  $outfile = $conv->fits2ndf($infile);

  $conv->infile($infile);
  $outfile = $conv->convert;  # uses infile()

=head1 DESCRIPTION

Provide a system for converting data formats. Currently the
only output format supported are:

  NDF     - simple NDF files
  HDS     - HDS containers with .HEADER and .Inn NDFs
  FITS    - Simple FITS files

The only input formats supported are:

  NDF     - simple NDF files
  FITS    - FITS file
  UKIRTIO - UKIRT I/O file
  HDS     - HDS containers with .HEADER and .Inn NDFs
            In general this can only be converted to a NDF or FITS
            output file if there is only one data frame in the container.
  GMEF    - Gemini Multi-Extension FITS.
  INGMEF  - Isaac Newton Group Multi-Extension FITS.

In many cases the NDF format is used as the intermediate format for
all conversions (should probably use PDLs as the intermediate
format....)

Uses the Starlink CONVERT package (via monoliths) where necessary.

Can be used to convert from instrument specific NDF files (eg
multi-frame CGS4 data or I- and O- frames for IRCAM) to HDS formats
usable by the pipeline (either as HDS containers or NDFs with combined
I and O information).

The output filename is always related to the input filename
(usually simply with a change of suffix).

=cut


use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;

use File::Basename;  # Get file suffix
use File::Spec;      # Not really necessary -- a bit anal I suppose
use NDF;
use Starlink::HDSPACK qw/copy_hdsobj copobj 
  delete_hdsobj create_hdsobj set_hdsobj/; # copobj/creobj/delobj/setobj

use ORAC::Print;
use ORAC::Msg::EngineLaunch; # To launch convert monolith
use ORAC::Constants qw/:status/;        #  Constants

$VERSION = '1.0';

=head1 METHODS

The following methods are provided:

=head2 Constructors

=over 4

=item B<new>

Object constructor. Should always be used before initiating a conversion.

  $Cvt = new ORAC::Convert;

Returns undef if there was an error creating the object. No arguments
are required.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $conv = {};  # Anon hash

  $conv->{EngineLaunch} = new ORAC::Msg::EngineLaunch;
  $conv->{InFile} = undef;
  $conv->{OverWrite} = 0;      # Do not overwrite files of same name

  bless($conv, $class);

  # Check if $CONVERT_DIR exists
  unless (defined $ENV{CONVERT_DIR}) {
    orac_err("CONVERT_DIR not defined. Can not convert data\n");
    return;
  }

  # Message system will start on demand

  # Return the object
  return $conv;

}


=back

=head2 Accessor Methods

The following methods are available for accessing the 
'instance' data.

=over 4

=item B<engine_launch_object>

Returns the C<ORAC::Msg::EngineLaunch> object that can be used
to launch algorithm engines as required by the particular
conversion.

 $messys = $self->messys_launch_object;

=cut

sub engine_launch_object {
  my $self = shift;
  return $self->{EngineLaunch};
}


=item B<infile>

Method for storing or retreiving the current input filename.
Used by default if omitted from convert() methods.

  $infile = $Cvt->infile;

=cut

sub infile {
  my $self = shift;
  if (@_) { $self->{InFile} = shift;  }
  return $self->{InFile};
}

=item B<overwrite>

Method for storing or retreiving the flag governing whether
a file should be overwritten if it already exists.

If false, the file will be converted regardless.

=cut

sub overwrite {
  my $self = shift;
  if (@_) { $self->{OverWrite} = shift;  }
  return $self->{OverWrite};
}

=back

=head2 General Methods

=over 4

=item B<convert>

Convert a file to the format specified by options.

  ($infile, $outfile) = $Cvt->convert;
  @files = $Cvt->convert($oldfile, { IN => 'FITS', OUT => 'NDF' });

File is optional - uses infile() to retrieve the name if not specified.
The options hash is optional (assumed to be last argument). If not
specified the input format will be guessed and the output format
will be set to NDF.

Recogised keywords in the hash are:

  IN  => input format (NDF, UKIRTio or FITS)
  OUT => desired output format (NDF or HDS)

If 'IN' is not specified it will try to derive the format from
name.

The output format is set to NDF if non-specified.

Returns a list containing the input filename and output filename.
Neither of these filenames has any directory structure removed.

Output filename is written to the current working directory of the
CONVERT monoliths (defaults to the CWD of the program when the
monoliths were launched - no attempt is made to correct the
CWD of the monoliths before conversion).

Will return an undefined output file if the conversion failed.

=cut

sub convert {
  my $self = shift;

  croak ('Usage: $obj->convert(filename, \%options)')
    unless scalar(@_) < 3;

  # Pop the options hash off the top
  my %options = ( OUT => 'NDF');
  if (ref($_[-1]) eq 'HASH') {
    my $href = pop;
    foreach my $key (keys %$href) {
      $options{uc($key)} = uc($$href{$key}); 
    }
  }

  # If we have any args left assume that it is the filename
  my $filename;
  if (@_) {
    $filename = shift;
    $self->infile($filename);
  } else {
    $filename = $self->infile($filename);
  }

  unless (exists $options{IN}) {
    # Input format not specified
    # guess from name
    $options{'IN'} = $self->guessformat;
  }

  # Guess will be undef if the format could not be determined
  # if that is the case return undef and raise an error
  unless (defined $options{'IN'}) {
    orac_err("Could not determine data format of $filename\n");
    return ($filename,undef);
  }

  if (!-e $filename) {
    orac_err("Provided filename '$filename' does not exist and so can not convert it\n");
    return ($filename, undef);
  }

  # If the input format is the same as the output just return
  if ($options{'IN'} eq $options{OUT}) {

    my $outfile = basename( $filename );

    if (-l $outfile && !-e $outfile) {
      orac_err("Error reading input file '$filename'\n");
      orac_err("Link exists in output directory but it does not point to an existing file\n");
      my $pointee = readlink( $outfile );
      if (defined $pointee) {
	if ($filename eq $pointee) {
	  orac_err("The link does point to the correct place but the file at the other end is missing\n");
	} else {
	  orac_err("The link does not point to the correct place. Please remove ORAC_DATA_OUT/$outfile and retry ['$filename' ne '$pointee']\n");
	}
      }

      return ($filename,undef);
    }

    unless( -e $outfile ) {
      symlink( $filename, $outfile ) ||
      do {
        orac_err("Error creating symlink from ORAC_DATA_OUT to '$filename'\n");
        orac_err("$!\n");
        return ($filename,undef);
      };
    } else {
      orac_warn("Symlink from ORAC_DATA_OUT to $filename already exists. Continuing...\n");
    }
    return ( $filename, $outfile );
  }

  # Set the overwrite flag
  $self->overwrite($options{OVERWRITE}) if exists $options{OVERWRITE};

  my $outfile = undef;

  # Since the options are somewhat limited by the current instrument
  # selection -- do not implement a generic conversion system using
  # intermediates for all formats. Simply make some specific conversion
  # routines to do the obvious conversions and worry about it later.

  if ($options{'IN'} eq 'FITS' && $options{'OUT'} eq 'NDF') {
    # Implement FITS2NDF
    orac_print("Converting from FITS to NDF...\n");
    $outfile = $self->fits2ndf;
    orac_print("...done\n");

  } elsif ($options{'IN'} eq 'HDS' && $options{'OUT'} eq 'FITS') {
    # Implement HDS2FITS
#    orac_print("Converting from HDS to FITS...\n");
#    $outfile = $self->hds2ndf;
#    my ($base, $dir, $suffix) = fileparse($outfile, '.sdf');
#    $base =~ s/_raw//;
#    my $outfile2 = $base . $suffix;
#    rename($outfile,$outfile2);
#    $self->infile($outfile2);
#    $outfile = $self->ndf2fits;
#    unlink $outfile2;
#    orac_print("...done\n");
    # Implement HDS2MEF
      orac_print("Converting from HDS to MEF...\n");
      $outfile = $self->hds2mef;
      orac_print("...done\n");
  } elsif ($options{'IN'} eq 'HDS' && $options{'OUT'} eq 'WFCAM_MEF') {
      orac_print("Converting WFCAM file from HDS to MEF...\n");

      # Try to do this using the Cirdr Perl modules. If either of them
      # fail, we'll fall back to use the convert_mon-based routines.
      my $isok = eval { require Cirdr::Opt; 1; };
      if( ! $isok ) {

        orac_warn "Error in loading Cirdr::Opt: $@\n";

        # Couldn't load Cirdr::Opt for some reason, so fall back to
        # use the convert_mon-based routines.
        $outfile = $self->hds2mef;

      } else {

        # Import the required method.
        Cirdr::Opt->import( qw/ cir_wfcam_convert / );

        # Now try to get Cirdr::Primitives.
        $isok = eval { require Cirdr::Primitives };
        if( ! $isok ) {

          orac_warn "Error in loading Cirdr::Primitives: $@\n";

          # Oops, couldn't load this one either.
          $outfile = $self->hds2mef;

        } else {

          # Import the required list of constants.
          Cirdr::Primitives->import( qw/ :constants / );

          # At this point we've got both of the Cirdr modules, so
          # use the appropriate method.
          $outfile = $self->hds2mef_wfcam;

        }
      }

      orac_print("...done\n");

  } elsif ($options{'IN'} eq 'HDS' && $options{OUT} eq 'NDF') {
    # Implement HDS2NDF
    orac_print "Converting from HDS container to merged NDF...\n";
    $outfile = $self->hds2ndf;
    orac_print "...done\n";

  } elsif ($options{'IN'} eq 'UKIRTIO' && $options{OUT} eq 'HDS') {
    # Implement UKIRTio2HDS
    orac_print "Converting from UKIRT I/O files to HDS container...\n";
    $outfile = $self->UKIRTio2hds;
    orac_print "...done\n";

  } elsif ($options{'IN'} eq 'GMEF' && $options{'OUT'} eq 'HDS') {
    # Implement GMEF2HDS
    # GMEF is Gemini Multi-Extension Fits
    # FITS2NDF can actually handle this, given the right options
    orac_print("Converting from GEMINI ME-FITS to HDS...\n");
    $outfile = $self->gmef2hds;
    orac_print("...done\n");

  } elsif ($options{'IN'} eq 'GMEF' && $options{'OUT'} eq 'NDF') {
    # Implement GMEF2NDF
    # GMEF is Gemini Multi-Extension Fits
    # FITS2NDF can actually handle this, given the right options
    orac_print("Converting from GEMINI ME-FITS to NDF...\n");
    $outfile = $self->gmef2hds;
    $self->infile($outfile);
    $outfile = $self->hds2ndf;
    orac_print("...done\n");

  } elsif ($options{'IN'} eq 'INGMEF' && $options{'OUT'} eq 'HDS') {
    # Implement INGMEF2HDS
    # INGMEF is Isaac Newton Group Multi-Extension Fits
    # FITS2NDF can actually handle this, given the right options
    orac_print("Converting from ING ME-FITS to HDS...\n");
    $outfile = $self->ingmef2hds;
    orac_print("...done\n");


  } else {
    orac_err "Error finding a conversion routine to handle $options{IN} -> $options{OUT}\n";
    return ($filename,undef);
  }

  # Now from NDF convert to the desired output format
  # NOT YET IMPLEMENTED

  # Return the name of the converted file

  return ( $filename, $outfile );
}


=item B<guessformat>

Given 'name' try to guess data format.

  $format = $Cvt->guessformat("test.sdf");

If no name is supplied, infile() is used to retrieve the current
filename.

=cut

sub guessformat {
  my $self = shift;

  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Check via file extension
  my $suffix = (fileparse($name, '\..*' ) )[-1]; 

  # Could also do this by checking the suffix AND trying to open
  # file (eg ndf_open or see if first line is SIMPLE = T)

  $suffix eq '.sdf' && ( return 'NDF'); # Could be DST or HDS container
  $suffix eq '.fits' && (return 'FITS');
  $suffix eq '.fit' && (return 'FITS');

  return;
}

=item B<mon>

Returns the algorithm engine object, launching it if required.

  $object = $Cvt->mon($name);

Returns undef if a monolith can not be contacted or fails to start.
This is launched using C<ORAC::Msg::LaunchEngine>.

=cut

sub mon {
  my $self = shift;

  croak "Usage: Convert->mon(name)" unless scalar (@_) == 1;

  # Get the name
  my $mon = shift;

  return $self->engine_launch_object->engine( $mon );

}

=back

=head2 Data Conversion Methods

=over 4

=item B<fits2ndf>

Convert a fits file to an NDF.
Returns the output name.

  $newfile = $Cvt->fits2ndf;

Retrieves the input filename from the object via the infile()
method.

=cut

sub fits2ndf {
  my $self = shift;

  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Generate an outfile
  # First Remove any suffices and retrieve the rootname
  # basename requires us to know the extension if FITS, FIT, fit etc
  my $out = (fileparse($name, '\..*'))[0];

  # We know that an NDF ends with .sdf -- append it.
  my $ndf = $out . ".sdf";

  # Check the output file name and whether we are allowed to
  # overwrite it.
  if (-e $ndf && ! $self->overwrite) {
    # Return early
    orac_warn "The converted file ($ndf) already exists - won't convert again\n";
    return $ndf;
  }

  # Check to see if fits2ndf monolith is running
  my $status = ORAC__ERROR;
  if (defined $self->mon('fits2ndf')) {

    # Do the conversion
    $status = $self->mon('fits2ndf')->obeyw("fits2ndf","in=$name out=$out proexts profits fmtcnv='true'");

  }

  # Return the filename (append .sdf) if everything okay.
  if ($status == ORAC__OK) {
    return $ndf;
  }
  return;
}

=item B<ndf2fits>

Convert an NDF file to a FITS file.

=cut

sub ndf2fits {
  my $self = shift;

  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Generate an outfile
  # First Remove any suffices and retrieve the rootname
  # basename requires us to know the extension if FITS, FIT, fit etc
  my $out = (fileparse($name, '\..*'))[0];

  # We know that an NDF ends with .sdf -- append it.
  my $fitsfile = $out . ".fit";
#  $out .= ".I1";

  # Check the output file name and whether we are allowed to
  # overwrite it.
  if (-e $fitsfile && ! $self->overwrite) {
    # Return early
    orac_warn "The converted file ($fitsfile) already exists - won't convert again\n";
    return $fitsfile;
  }

  # Check to see if fits2ndf monolith is running
  my $status = ORAC__ERROR;
  if (defined $self->mon('ndf2fits')) {

    # Do the conversion
    $status = $self->mon('ndf2fits')->obeyw("ndf2fits","in=$out out=$fitsfile profits proexts");

  }

  # Return the filename (append .sdf) if everything okay.
  if ($status == ORAC__OK) {
    return $fitsfile;
  }
  
  return;
}

sub hds2mef_wfcam {
  my $self = shift;

#    use Cirdr::Primitives qw(:constants);
#    use Cirdr::Opt qw(cir_wfcam_convert);
  require ORAC::Frame::WFCAM;

  # Check for the input file

  unless (-e $self->infile) {
    orac_err "Input filename (".$self->infile.") does not exist -- can not convert\n";
    return;
  }

  # Read the input file - we only want the basename (we know .sdf suffix)

  my ($base,$dir,$suffix) = fileparse($self->infile,'.sdf');

  # The HDS file for the HDS system is the base name and directory 
  # but no suffix

  my $hdsfile = File::Spec->catfile($dir,$base);

  # Get an output file name

  my $outfile = $base . ".fit";

  # Check for the existence of the output file in the current dir
  # and whether we can overwrite it.

  if (-e $outfile && ! $self->overwrite) {
    orac_warn "The converted file ($outfile) already exists - won't convert again\n";
    return $outfile;
  }

  # Get the standard fits keywords

  my @phukeys = &ORAC::Frame::WFCAM::phukeys;
  my @ehukeys = &ORAC::Frame::WFCAM::ehukeys;
  my $nphu = @phukeys;
  my $nehu = @ehukeys;

  # Do the conversion

  my $errmsg;
  my $retval = cir_wfcam_convert($hdsfile,$outfile,\@phukeys,$nphu,\@ehukeys,
                                 $nehu,$errmsg);
  if ($retval != &CIR_OK) {
    orac_err("Couldn't convert $hdsfile -- $errmsg\n");
    return(undef);
  }
  return($outfile);
}

=item B<hds2mef>

Convert a HDS file into a multi-extension FITS file

=cut

sub hds2mef {
    my $self = shift;

    # Need CFITSIO now, so load it

    require Astro::FITS::CFITSIO;
    Astro::FITS::CFITSIO->import(qw(:constants :longnames));

    # Check for the input file

    unless (-e $self->infile) {
        orac_err "Input filename (".$self->infile.") does not exist -- can not convert\n";
        return;
    }

    # Read the input file - we only want the basename (we know .sdf suffix)

    my ($base,$dir,$suffix) = fileparse($self->infile,'.sdf');

    # The HDS file for the HDS system is the base name and directory 
    # but no suffix

    my $hdsfile = File::Spec->catfile($dir,$base);

    # Get an output file name

    my $outfile = $base . ".fit";

    # Check for the existence of the output file in the current dir
    # and whether we can overwrite it.

    if (-e $outfile && ! $self->overwrite) {
        orac_warn "The converted file ($outfile) already exists - won't convert again\n";
        return $outfile;
    }

    # Define a file prefix for the temporary FITS files.

    my $prefix = "tmp_" . time;
    my $fitsfile = $prefix . "*";

    # Right, now convert each of the NDF components to a FITS file...
    # First check to see if fits2ndf monolith is running

    my $status = ORAC__ERROR;
    if (defined $self->mon('convert_mon')) {

        # Do the conversion

        $status = $self->mon('convert_mon')->obeyw("ndf2fits","in=$hdsfile out=$fitsfile profits encoding=\'FITS-IRAF\'");
    }

    # Check to make sure this succeeded

    if ($status != ORAC__OK) {
	orac_err "ndf2fits failed\n";
	return;
    }

    # Get a list of all of the temporary FITS files created in this last
    # operation. (NB: the HEADER extension is alphabetically first before
    # the I extensions, so this will put this in the correct order).

    my @alltmp = sort glob $fitsfile;
    my $ntmp = @alltmp;

    # Create the output file

    my $fitstatus = 0;
    my $optr = Astro::FITS::CFITSIO::create_file($outfile,$fitstatus);
    if ($fitstatus != 0) {
	unlink @alltmp;
	orac_err "Couldn't create output file $outfile\n";
	return;
    }

    # Now loop for each of the temporary files...

    my $ifileno;
    for ($ifileno = 0; $ifileno < $ntmp; $ifileno++) {
        my ($naxis,@naxes,$bitpix);

        # Open the input temporary file. Get the size of the image if it's
	# not the primary

	my $ifile = $alltmp[$ifileno];
        my $iptr = Astro::FITS::CFITSIO::open_file($ifile,
						   &Astro::FITS::CFITSIO::READONLY,$fitstatus);
        if ($fitstatus != 0) {
	    unlink @alltmp;
	    orac_err "Couldn't open temporary FITS file $ifile\n";
	    return;
	}

        # Copy the input image to the output file... 

        $iptr->copy_hdu($optr,0,$status);

        # Resize the PHU to get rid of silly starlink 'feature'...

	if ($ifileno == 0) {
	    $naxis = 0;
	    @naxes = ();
            $bitpix = &Astro::FITS::CFITSIO::BYTE_IMG;
            $optr->resize_img($bitpix,$naxis,\@naxes,$status);
	}

        # Close up the input file

        $iptr->close_file($fitstatus);
    }

    # Now close up the output file

    $optr->close_file($fitstatus);

    # Now tidy up and get out of here

    unlink @alltmp;
    return($outfile);
}

=item B<gmef2hds>

Convert a GEMINI multi-extension FITS file to an HDS container

=cut

sub gmef2hds {
  my $self = shift;

  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Generate an outfile
  # First Remove any suffices and retrieve the rootname
  # basename requires us to know the extension if FITS, FIT, fit etc
  my $out = (fileparse($name, '\..*'))[0];

  # Fix up gemini file name scheme :-)
  $out =~s/S/_/;

  # We know that an HDS ends with .sdf -- append it.
  my $hds = $out . ".sdf";

  # Check the output file name and whether we are allowed to
  # overwrite it.
  if (-e $hds && ! $self->overwrite) {
    # Return early
    orac_warn "The converted file ($hds) already exists - won't convert again\n";
    return $hds;
  }

  # Check to see if fits2ndf monolith is running.
  my $status = ORAC__ERROR;
  if (defined $self->mon('fits2ndf')) {

    # Do the conversion.
    my $extable = File::Spec->catfile($ENV{'ORAC_DATA_CAL'},"extable.txt");
    orac_print "Using extable: $extable\n";
    $status = $self->mon('fits2ndf')->obeyw("fits2ndf","container=true encodings=FITS-IRAF extable=$extable in=$name out=$out profits=true fmtcnv=true");

    # This leaves us with an invalid file as the HEADER doesn't contain 
    # a data array with a value, and it's of the wrong data type.  First
    # copy the HEADER structure, delete the original HEADER, and replace
    # it with a new HEADER structure of type NDF.  [There is no renobj
    # yet, hence the copy then delete.]  Then create the DATA_ARRAY
    # structure containing a dummy one-element data array.
    my $hstat;
    $hstat = copy_hdsobj("$out.HEADER", "$out.FITS_HEADER");
    $hstat = delete_hdsobj("$out.HEADER") if $hstat;
    $hstat = create_hdsobj("$out.HEADER","NDF") if $hstat;
    $hstat = create_hdsobj("$out.HEADER.DATA_ARRAY", "ARRAY") if $hstat;
    $hstat = create_hdsobj("$out.HEADER.DATA_ARRAY.DATA", "_REAL", [1])
      if $hstat;
    $hstat = set_hdsobj("$out.HEADER.DATA_ARRAY.DATA", [1]) if $hstat;

    # Move the FITS component of FITS_HEADER to the FITS
    # airlock/extension of NDF HEADER.  Finally delete the original
    # HEADER structure.
    $hstat = create_hdsobj("$out.HEADER.MORE","EXT") if $hstat;
    $hstat = copy_hdsobj("$out.FITS_HEADER.FITS","$out.HEADER.MORE.FITS") if $hstat;
    $hstat = delete_hdsobj("$out.FITS_HEADER") if $hstat;

    $status = ($hstat ? ORAC__OK : ORAC__ERROR );

  }

  # Return the filename (append .sdf) if everything okay.
  if ($status == ORAC__OK) {
    return $hds;
  }
  
  return;
}

=item B<ingmef2hds>

Convert an ING format Multi-Extension FITS file into an HDS container.

=cut

sub ingmef2hds {
  my $self = shift;

  my $name;
  if (@_) {
    $name = shift;
  } else {
    $name = $self->infile;
  }

  # Generate an outfile
  # First remove any suffices and retrieve the rootname.  The
  # basename requires us to know the extension if FITS, FIT, fit etc
  my $out = (fileparse($name, '\..*'))[0];

  # We know that an HDS ends with .sdf -- append it.
  my $hds = $out . ".sdf";

  # Check the output file name and whether we are allowed to
  # overwrite it.
  if (-e $hds && ! $self->overwrite) {
    # Return early
    orac_warn "The converted file ($hds) already exists - won't convert again\n";
    return $hds;
  }

  # Check to see if FITS2NDF monolith is running.
  my $status = ORAC__ERROR;
  if (defined $self->mon('fits2ndf')) {

    # Do the conversion.
    my $extable = File::Spec->catfile($ENV{'ORAC_DATA_CAL'}, "extable.txt");
    orac_print "Using extable: $extable\n";
    my $param = "container=true encodings=FITS-WCS profits=true fmtcnv=true";
    $status = $self->mon('fits2ndf')->obeyw("fits2ndf","extable=$extable in=$name out=$out $param");

    # This leaves us with an invalid file as the HEADER doesn't contain 
    # a data array with a value, and it's of the wrong data type.  First
    # copy the HEADER structure, delete the original HEADER, and replace
    # it with a new HEADER structure of type NDF.  [There is no renobj
    # yet, hence the copy then delete.]  Then create the DATA_ARRAY
    # structure containing a dummy one-element data array.
    my $hstat;
    $hstat = copy_hdsobj("$out.HEADER", "$out.FITS_HEADER");
    $hstat = delete_hdsobj("$out.HEADER") if $hstat;
    $hstat = create_hdsobj("$out.HEADER","NDF") if $hstat;
    $hstat = create_hdsobj("$out.HEADER.DATA_ARRAY", "ARRAY") if $hstat;
    $hstat = create_hdsobj("$out.HEADER.DATA_ARRAY.DATA", "_REAL", [1]) if $hstat;
    $hstat = set_hdsobj("$out.HEADER.DATA_ARRAY.DATA", [1]) if $hstat;

    # Move the FITS component of FITS_HEADER to the FITS
    # airlock/extension of NDF HEADER.  Finally delete the original
    # HEADER structure.
    $hstat = create_hdsobj("$out.HEADER.MORE","EXT") if $hstat;
    $hstat = copy_hdsobj("$out.FITS_HEADER.FITS","$out.HEADER.MORE.FITS")
      if $hstat;
    $hstat = delete_hdsobj("$out.FITS_HEADER") if $hstat;

    $status = ($hstat ? ORAC__OK : ORAC__ERROR );

  }

  # Return the filename (append .sdf) if everything okay.
  if ($status == ORAC__OK) {
    return $hds;
  }
  
  return;
}

=item B<UKIRTio2hds>

Converts observations that are taken as a header file plus multiple
NDFs into a single HDS container that contains a .HEADER NDF and
.Inn NDFs for each of the nn data files. This is the scheme used for
IRCAM and CGS4 data at UKIRT.

  $hdsfile = $Cvt->UKIRTio2hds;

This routine assumes the old UKIRT data acquisition system (at least for
IRCAM and CGS4) is generating the data files. The name of the header
file (aka the O-file) must be stored in the object (via the infile()
method) before running this method. The I files are assumed to be in
the directory C<../idir> relative to the header file with a starting
character of 'i' rather than 'o' and are multiple files with
suffixes of '_1', '_2' etc. The new output file
is named 'cYYYYMMDD_NNNNN' where the date is retrieved from the IDATE header
keyword and observation number from the OBSNUM header keyword.

Returns undef on error.

=cut

sub UKIRTio2hds {
  my $self = shift;

  # Get the directory name and file name from the infile()
  # Match any suffix -- anything after a '.'
  my ($ofile, $odir, $suffix) = fileparse($self->infile, '\..*');

  # Make sure that the O-file exists (also infile() may not return .sdf suffix)
  my $ondfname = File::Spec->catfile($odir, $ofile); # guaranteed no suffix
  $ondfname .= ".sdf";

  unless (-e $ondfname) {
    orac_err "Input filename ($ondfname) does not exist -- can not convert\n";
    return;
  }

  # Theres a limit to what can be derived from first principals.
  # we really need to know the format of the file names
  # Whilst the I files do contain the name of the O file parent
  # the O file does not contain the name of the I file root.

  # Read the header of the O file
  my ($href, $status) = fits_read_header($ondfname);

  if ($status != &NDF::SAI__OK) {
    orac_err "Error reading FITS header from O-file $ondfname\n";
    err_annul($status);
    return;
  }

  # Calculate the output filename from the FITS header information
  my $num = 0 x (5 - length($href->{OBSNUM})) . $href->{OBSNUM};
  my $output = 'c' . $href->{IDATE} . "_$num";

  # Check for the existence of the output file in the current dir
  # and whether we can overwrite it.
  if (-e $output.'.sdf' && ! $self->overwrite) {
    # Return early
    $output .= '.sdf';
    orac_warn "The converted file ($output) already exists - won't convert again\n";
    return $output;
  }

  # Construct idir -- without assuming unix!
  my $idir = File::Spec->catdir($odir, File::Spec->updir, 'idir');

  # Read in a list of the O-files
  opendir(IDIR, $idir) || do {
    orac_err "ORAC::Convert::UKIRTio2hds: Error opening IDIR: $idir\n";
    return;
  };

  # Calculate the I file root name
  # ie change 'o' to 'i' and use the root
  my $root;
  ($root = $ofile) =~ s/^o/i/;
  $root .= '_';  # add underscore to constrain pattern match

  # Read all the Ifiles that look like they are related to the O file
  my @ifiles = grep /^$root/, readdir IDIR;
  closedir IDIR;

  # print "IFILES: @ifiles\n";

  # Check that we have found some files
  if ($#ifiles == -1) {
    orac_err "No I-files found in IDIR ($idir) -- can not convert\n";
    return;
  }

  # First we need to create a container file in the current directory
  $status = &NDF::SAI__OK;
  my @dims = ();
  hds_new($output, substr($output, 0, &NDF::DAT__SZNAM),'ORAC_HDS', 0,
    @dims, my $floc, $status);

  # Then open the header file  
  hds_open(File::Spec->catfile($odir,$ofile), 'READ', my $oloc, $status);

  # Copy the header NDF
  dat_copy($oloc, $floc, 'HEADER', $status);

  # Close the header file
  dat_annul($oloc, $status);

  # Open the header NDF file and turn on history recording
  ndf_open($floc, "header", 'UPDATE', 'OLD', my $indf, my $place, $status);
  ndf_happn("ORAC::Convert", $status);
  ndf_hcre($indf, $status);
  ndf_annul($indf, $status);

  # Now loop over all the I-files and copy them in
  my $n = 0;
  for my $ifile (@ifiles) {
    # Abort loop if bad status
    last if $status != &NDF::SAI__OK;
    $n++;

    # Open the I-file
    hds_open(File::Spec->catfile($idir,$ifile), 'READ', my $iloc, $status);

    # Copy it
    dat_copy($iloc, $floc, "i$n", $status);

    # Close the file
    dat_annul($iloc, $status);

    # Open the NDF file and turn on history recording
    ndf_open($floc, "i$n", 'UPDATE', 'OLD', my $indf, my $place, $status);
    ndf_happn("ORAC::Convert", $status);
    ndf_hcre($indf, $status);
    ndf_annul($indf, $status);

  }

  # Close the output file
  dat_annul($floc, $status);

  # Check for errors
  if ($status != &NDF::SAI__OK) {
    err_flush($status);
    orac_err "Error copying I and O files to ouput container file\n";
    return;
  }

  # Everything okay - return the file name (with .sdf)
  return $output . ".sdf";


}


=item B<hds2ndf>

Converts frames taken as HDS container files (container file with
.HEADER and .I1) to a simple NDF file. This method only works
for the first frame (.I1). 

  $ndf = $Cvt->hds2ndf;

If the input HDS has a .I1 component with FITS headers, then the
resulting NDF file has the FITS headers from both the .HEADER and
the .I1 components merged. Otherwise, the resulting NDF has the
FITS headers from just the .HEADER component. No warning is given
if more than one component exists (all higher numbers are ignored).

=cut

sub hds2ndf {
  my $self = shift;

  # Check for the input file
  unless (-e $self->infile) {
    orac_err "Input filename (".$self->infile.") does not exist -- can not convert\n";
    return;
  }

  # Read the input file - we only want the basename (we know .sdf suffix)
  my ($base, $dir, $suffix) = fileparse($self->infile, '.sdf');

  # The HDS file for HDS system in sthe base name and directory but no suffix
  my $hdsfile = File::Spec->catfile($dir, $base);

  # Construct the output file name. This is just the input with _raw
  # appended (no .sdf)
  my $outfile = $base . '_raw';

  # Check for the existence of the output file in the current dir
  # and whether we can overwrite it.
  if (-e $outfile.'.sdf' && ! $self->overwrite) {
    # Return early
    $outfile .= '.sdf';
    orac_warn "The converted file ($outfile) already exists - won't convert again\n";
    return $outfile;
  }

  # Start new error context
  my $status = &NDF::SAI__OK;
  err_begin($status);

  # Copy the base frame (.i1) to the output name
  $status = copobj($hdsfile . '.i1', $outfile, $status);

  # Now the hard part -- we have to read in the FITS array from the
  # header and the FITS array from the data and merge them
  # First open the header (can't use fits_read_header)

  # Begin NDF context
  ndf_begin();

  # Open the file
  ndf_find(&NDF::DAT__ROOT(), $hdsfile . '.header', my $indf, $status);

  # Get the fits locator
  ndf_xloc($indf, 'FITS', 'READ', my $xloc, $status);

  # Find out how many entries we have
  my $maxdim = 7;
  my @dim = ();
  dat_shape($xloc, $maxdim, @dim, my $ndim, $status);

  # Must be 1D
  if ($status == &NDF::SAI__OK && scalar(@dim) > 1) {
    $status = &NDF::SAI__ERROR;
    err_rep(' ',"hsd2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",
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
  ndf_open(&NDF::DAT__ROOT, $outfile, 'UPDATE', 'OLD', $indf, my $place,
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
      err_rep(' ',"hds2ndf: Dimensionality of .HEADER FITS array should be 1 but is $ndim",$status);
    }

    # Read the second FITS array
    dat_get1c($xloc, $dim[0], @fitsB, $nfits, $status)
      if $status == &NDF::SAI__OK; # -w protection

    # Annul the locator
    dat_annul($xloc, $status);
    ndf_xdel($indf,'FITS', $status);
  }

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

  # End error context and return string
  if ($status != &NDF::SAI__OK) {
    err_flush($status);
    err_end($status);
    return;
  }

  err_end($status);

  return $outfile .'.sdf';


}

=back


=head1 SEE ALSO

The Starlink CONVERT package.

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Jim Lewis E<lt>jrl@ast.cam.ac.ukE<gt>
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

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

