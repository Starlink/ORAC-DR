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

=head1 

Provide a system for converting data formats. Currently the
only output format supported are:

  NDF     - simple NDF files
  HDS     - HDS containers with .HEADER and .Inn NDFs

The only input formats supported are:

  NDF     - simple NDF files
  FITS    - FITS file
  UKIRTIO - UKIRT I/O file

In many cases the NDF format is used as the intermediate format for
all conversions (should probably use PDLs as the intermediate
format....)

Uses the Starlink CONVERT package (via monoliths) where necessary.

Can be used to convert from instrument specific NDF files (eg
multi-frame CGS4 data or I- and O- frames for IRCAM) to HDS formats
usable by the pipeline (either as HDS containers or NDFs with combined
I and O information).

=cut


use strict;
use Carp;
use vars qw/$VERSION/;

use File::Basename;  # Get file suffix
use File::Spec;      # Not really necessary -- a bit anal I suppose
use NDF;
use Starlink::HDSPACK; # copobj

use ORAC::Print;
use ORAC::Msg::ADAM::Control;
use ORAC::Msg::ADAM::Task;
use ORAC::Constants qw/:status/;        #  Constants

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

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
  
  $conv->{AMS} = undef;        # Messaging
  $conv->{ConvObjects} = {};   # Conversion objects - 1 per convert monolith
  $conv->{InFile} = undef;
  $conv->{OverWrite} = 0;      # Do not overwrite files of same name

  bless($conv, $class);

  # Check if $CONVERT_DIR exists
  unless (defined $ENV{CONVERT_DIR}) {
    orac_err("CONVERT_DIR not defined. Can not convert data\n");
    return undef;
  }


  # Start message system (should just return if already started)
  my $status = ORAC__OK;
  # This check is a bit dodgy. I add it to stop the error message
  # occuring concerning whether the AMS is currently running or not.
  $conv->{AMS} = new ORAC::Msg::ADAM::Control;
  $status = $conv->{AMS}->init;

  return undef if $status != ORAC__OK;
  return $conv;

}


=back

=head2 Accessor Methods

=over 4

The following methods are available for accessing the 
'instance' data.

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

=item B<objref>

Hash containing convert task objects. These are the actual
ORAC::Msg::ADAM::Task objects related to each Starlink CONVERT
monolith that is required.

  $mon = $Cvt->objref->{monolith_name};

=cut

sub objref {
  my $self = shift;
 
  if (@_) { 
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{ConvObjects} = $arg;
  }
 
  return $self->{ConvObjects};
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

  $nrefile = $Cvt->convert;
  $newfile = $Cvt->convert($oldfile, { IN => 'FITS', OUT => 'NDF' });

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

Returns the new filename (derived from the input filename).

Output filename is written to the current working directory of the
CONVERT monoliths (defaults to the CWD of the program when the
monoliths were launched - no attempt is made to correct the
CWD of the monoliths before conversion).

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
    return undef;
  }

  # If the input format is the same as the output just return
  # Make sure directory path is removed
  if ($options{'IN'} eq $options{OUT}) {
    return basename($filename);
  }

  # Set the overwrite flag
  $self->overwrite($options{OVERWRITE}) if exists $options{OVERWRITE};

  my $outfile = undef;

  # Since the options are somewhat limited by the current instrument
  # selection -- do not implement a generic conversion system using
  # intermediates for all formats. Simply make some specific conversion
  # routines to do the obvious conversions and worry about it later.

  # Implement FITS2NDF
  if ($options{'IN'} eq 'FITS' && $options{'OUT'} eq 'NDF') {
    orac_print("Converting from FITS to NDF...\n");
    $outfile = $self->fits2ndf;
    orac_print("...done\n");
  } elsif ($options{'IN'} eq 'UKIRTIO' && $options{OUT} eq 'HDS') {
    # Implement UKIRTio2HDS
    orac_print "Converting from UKIRT I/O files to HDS container...\n";
    $outfile = $self->UKIRTio2hds;
    orac_print "...done\n";
  } else {
    orac_err "Error finding a conversion routine to handle $options{IN} -> $options{OUT}\n";
    return undef;
  }

  # Now from NDF convert to the desired output format
  # NOT YET IMPLEMENTED

  # Return the name of the converted file
  # Make sure that we dont return a full path (the conversion occurred
  # in the current directory even if we read from a remote directory)

  return basename($outfile);
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

  return undef;

}

=item B<mon>

Returns a ORAC::Msg::ADAM::Task object using a path of name_$$
in the messaging system.

  $object = $Cvt->mon($name);

Returns undef if a monolith can not be contacted or fails to start.

Populates the object using the objref() method.

=cut

sub mon {
  my $self = shift;
  
  croak "Usage: Convert->mon(name)" unless scalar (@_) == 1;

  # Get the name
  my $mon = shift;
  
  # Append pid
  my $name = $mon . "_$$";

  # Now look up object in the message storage area
  my $obj;
  if (exists $ {$self->objref}{$name}) {
    return $ {$self->objref}{$name};
  } else {

    # Find the full path to the monolith
    my $fullname = File::Spec->catfile($ENV{CONVERT_DIR}, $mon);

    # Create a new object
    $obj = new ORAC::Msg::ADAM::Task($name, $fullname,
				     { MONOLITH => "$mon"}
				    );
    if ($obj->contactw) {
      $ {$self->objref}{$name} = $obj;
    } else {
      return undef;
    }

  }

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
  } else {
    return undef;
  }

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
    return undef;
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
    return undef;
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
    return undef;
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
    return undef;
  }

  # First we need to create a container file in the current directory
  my $status = &NDF::SAI__OK;
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
    return undef;
  }

  # Everything okay - return the file name (with .sdf)
  return $output . ".sdf";


}



=back


=head1 SEE ALSO

The Starlink CONVERT package.

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut



1;

