package ORAC::Frame;

=head1 NAME

ORAC::Frame - base class for dealing with observation frames in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame;

  $Frm = new ORAC::Frame("filename");
  $Frm->file("prefix_flat");
  $num = $Frm->number;  


=head1 DESCRIPTION

This module provides the basic methods available to all B<ORAC::Frame>
objects. This class should be used when dealing with individual
observation files (frames).

=cut

use 5.006;
use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;

use ORAC::Print;
use ORAC::Constants;

use ORAC::BaseFile;
use base qw/ ORAC::BaseFile /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);


my @ORAC_INTERNAL_HEADERS = qw/
                               AIRMASS_START
                               AIRMASS_END
                               CAMERA_NUMBER
                               CHOP_ANGLE
                               CHOP_THROW
                               CONFIGURATION_INDEX
                               DATA_UNITS
                               DEC_BASE
                               DEC_SCALE
                               DEC_TELESCOPE_OFFSET
                               DETECTOR_BIAS
                               DETECTOR_INDEX
                               DETECTOR_READ_TYPE
                               EQUINOX
                               EXPOSURE_TIME
                               FILTER
                               GAIN
                               GRATING_DISPERSION
                               GRATING_NAME
                               GRATING_ORDER
                               GRATING_WAVELENGTH
                               INSTRUMENT
                               NSCAN_POSITIONS
                               NUMBER_OF_EXPOSURES
                               NUMBER_OF_JITTER_POSITIONS
                               NUMBER_OF_MICROSTEP_POSITIONS
                               NUMBER_OF_OFFSETS
                               NUMBER_OF_READS
                               OBJECT
                               OBSERVATION_MODE
                               OBSERVATION_NUMBER
                               OBSERVATION_TYPE
                               POLARIMETRY
                               RA_BASE
                               RA_SCALE
                               RA_TELESCOPE_OFFSET
                               RECIPE
                               ROTATION
                               SCAN_INCREMENT
                               SLIT_ANGLE
                               SLIT_NAME
                               SPEED_GAIN
                               STANDARD
                               TELESCOPE
                               UTDATE
                               UTEND
                               UTSTART
                               WAVEPLATE_ANGLE
                               X_DIM
                               Y_DIM
                               X_LOWER_BOUND
                               X_REFERENCE_PIXEL
                               X_UPPER_BOUND
                               Y_LOWER_BOUND
                               Y_REFERENCE_PIXEL
                               Y_UPPER_BOUND
                               X_APERTURE
                               Y_APERTURE
                              /;

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class:

=head2 Constructors

The following constructors are available:

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame> object.  This method also
takes optional arguments: if 1 argument is supplied it is assumed to
be the name of the raw file associated with the observation.  If 2
arguments are supplied they are assumed to be the raw file prefix and
observation number.  In any case, all arguments are passed to the
configure() method which is run in addition to new() when arguments
are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame;
   $Frm = new ORAC::Frame("file_name");
   $Frm = new ORAC::Frame("UT", "number");

The base class constructor should be invoked by sub-class constructors.
If this method is called with the last argument as a reference to
a hash it is assumed that this hash contains extra configuration
information ('instance' information) supplied by sub-classes.

Note that the file format expected by this constructor is actually the
required format of the data (as returned by C<format()> method) and not
necessarily the raw format.  ORAC-DR will pre-process the data with
C<ORAC::Convert> prior to passing it to this constructor.

=cut


# NEW - create new instance of Frame

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Check last arg for a hash
  my %subclass = ();
  %subclass = %{ pop(@_) } if (ref($_[-1]) eq 'HASH');

  # Define the initial state plus include any hash information
  # from a sub-class
  my $frame = {
	       Files => [],
	       Format => undef,
	       Group => undef,
	       Header => {},
	       Intermediates => [],
	       IsGood => 1,
	       NoKeepArr => [],
	       Nsubs => undef,
	       RawFixedPart => undef,
	       RawName => undef,
	       RawSuffix => undef,
	       Recipe => undef,
	       UHeader => {},
	       Tags => {},
	       TempRaw => [],
               WCS => [],
	       %subclass
	      };

  bless($frame, $class);

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $frame->configure(@_) if @_;

  return $frame;
}

=item B<framegroup>

Create new instances of a B<ORAC::Frame> object from multiple
input files.

  @frames = ORAC::Frame->framegroup( @files );

In most cases this is identical to simply passing the files directly
to the Frame constructor. In some subclasses, frames from the same
observation will be grouped into multiple frame objects and processed
independently.

Note that framegroup() accepts multiple filenames in a list, as opposed
to the frame constructors that only take single files or reference to
an array.

=cut

sub framegroup {
  my $class = shift;
  # if there are multiple files, pass a reference to the constructor
  my $files = ( @_ > 1 ? [@_] : $_[0] );
  return ( $class->new( $files ) );
}

=back

=head2 Accessor Methods

The following methods are available for accessing the 
'instance' data.

=over 4

=cut

# Create some methods to access "instance" data
#
# With args they set the values
# Without args they only retrieve values

=item B<file>

This method can be used to retrieve or set the file names that are 
currently associated with the frame. Multiple file names can be stored
if required (for example the names associated with different 
SCUBA sub-instruments).

  $first_file = $Frm->file;     # First file name
  $first_file = $Frm->file(1);  # First file name
  $second_file= $Frm->file(2);  # Second file name
  $Frm->file(1, value);         # Set the first file name
  $Frm->file(value);            # Set the first filename
  $Frm->file(10, value);        # Set the tenth file name

Note that counting starts at 1 (and not 0 as is normal for Perl 
arrays) and that the filename can not be an integer (otherwise
it will be treated as an array index). Use files() to retrieve
all the values in an array context.

If a file has been marked as temporary (ie with the nokeep()
method) it is erased (running the erase() method) when the file
name is updated.

For example, the second file (file_2) is marked as temporary
with C<$Frm-E<gt>nokeep(2,1)>. The next time the filename is updated
(C<$Frm-E<gt>file(2,'new_file')>) the current file is erased before the
'new_file' name is stored. The temporary flag is then reset to
zero.

If a file number is requested that does not exist, the first
member is returned.

Every time the file name is updated, the new file is pushed onto
the intermediates() array. This is so that intermediate files
can be tidied up when required.

If the first argument is present but not defined the command is
treated as if you typed

 $Frm->file(1, undef);

ie the first file is set to undef.

=cut

sub file {
  my $self = shift;

  # Set it to point to first member by default
  my $index = 0;

  # Check the arguments
  if (@_  && defined $_[0]) {

    my $firstarg = shift;

    # If this is an integer then proceed
    # Check for int and non-zero (since strings eval as 0)
    # Cant use int() since this extracts integers from the start of a
    # string! Match a string containing only digits
    if (defined $firstarg && $firstarg =~ /^\d+$/ && $firstarg != 0) {

      # Decrement value so that we can use it as a perl array index
      $index = $firstarg - 1;

      # If we have more arguments we are setting a value
      # else wait until we return the specified value
      if (@_) {

        # First check that the old file should not be
        # removed before we update the object
        # [Note that the erase method calls this method...]
        $self->erase($firstarg) if $self->nokeep($firstarg);

        # Now update the filename
        $self->files->[$index] = $self->stripfname(shift);

        # Make sure the nokeep flag is unset
        $self->nokeep($firstarg,0);

        # Push onto file history array
        push(@{$self->intermediates}, $self->files->[$index]);

      }
    } else {
      # Since we are updating, Erase the existing file if required
      $self->erase(1) if $self->nokeep(1);

      # Just set the first value
      $self->files->[0] = $self->stripfname($firstarg);

      # Make sure the nokeep flag is unset
      $self->nokeep(1,0);

      # Push onto file history array
      push(@{$self->intermediates}, $self->files->[0]);

    }
  }

  # If index is greater than number of files stored in the
  # array return the first one
  $index = 0 if ($index > $self->nfiles - 1);

  # Nothing else of interest so return specified member
  return ${$self->files}[$index];

}

=item B<files>

Set or retrieve the array containing the current file names
associated with the frame object.

    $Frm->files(@files);
    @files = $Frm->files;

    $array_ref = $Frm->files;

In a scalar context the array reference is returned.
In an array context, the array contents are returned.

The file() method can be used to set or retrieve individual
filenames.

The previous files are stored as intermediates (similarly to the C<file>
method behaviour) and the C<nokeep> flag is respected.

Note: It is possible to set and retrieve the array members using
the array reference rather than the file() method:

  $first = $Frm->files->[0];

In this approach, the file numbering starts at 0. The file() method
is the recommended way of addressing individual members of this
array since the file() method could do extra processing of the
string (especially when setting the value, for example the automatic
deletion of temporary files).

=cut

sub files {
  my $self = shift;
  if (@_) { 
    # get copies of current files
    my @oldfiles = @{$self->{Files}};

    # delete the old files if required and store on intermediates array
    for my $i (1..@oldfiles) {
      $self->erase( $i ) if $self->nokeep( $i );
    }
    push(@{$self->intermediates}, @oldfiles);

    # Store the new versions
    @{ $self->{Files} } = @_;

    # unset noKeep flags
    for my $i (1..scalar(@_)) {
      $self->nokeep( $i, 0);
    }

  }

  if (wantarray) {

    # In an array context, return the array itself
    return @{ $self->{Files} };

  } else {
    # In a scalar context, return the reference to the array
    return $self->{Files};
  }
}

=item B<format>

Data format associated with the current file().
Usually one of 'NDF' or 'FITS'. This format should be
recognisable by C<ORAC::Convert>.

=cut

sub format {
  my $self = shift;
  if (@_) { $self->{Format} = shift; }
  return $self->{Format};
}

=item B<group>

This method returns the group name associated with the observation.

  $group_name = $Frm->group;
  $Frm->group("group");

This can be configured initially using the findgroup() method.
Alternatively, findgroup() is run automatically by the configure()
method.

=cut


sub group {
  my $self = shift;
  if (@_) { $self->{Group} = shift;}
  return $self->{Group};
}

=item B<intermediates>

An array containing all the intermediate file names used
during processing. Filenames are pushed onto this array
whenever the file() method is used to update the current
file information.

  $Frm->intermediates(@files);
  @files = $Frm->intermediates;
  push(@{$Frm->intermediates}, $file);
  $first = $Frm->intermediates->[0];

As for the files() method, returns an array reference when
called in a scalar context and an array of file names when
called from an array context.

The array does not store information relating to the position of the
file in the files() array [ie was it stored as C<$Frm-E<gt>file(1)> or
C<$Frm-E<gt>file(2)>]. The order simply reflects the order the files
were given to the file() method.

=cut

sub intermediates {
  my $self = shift;
  if (@_) { @{ $self->{Intermediates} } = @_;}

  if (wantarray) {

    # In an array context, return the array itself
    return @{ $self->{Intermediates} } if wantarray();

  } else {
    # In a scalar context, return the reference to the array
    return $self->{Intermediates};
  }
}


=item B<isgood>

Flag to determine the current state of the frame. If isgood()
is true the Frame is valid. If it returns false the frame
object may have a problem (eg the recipe responsible for 
processing the frame failed to complete).

This flag is used by the B<ORAC::Group> class to determine
membership.

=cut

sub isgood {
  my $self = shift;
  if (@_) { $self->{IsGood} = shift;  }
  $self->{IsGood} = 1 unless defined $self->{IsGood};
  return $self->{IsGood};
}

=item B<nokeep>

Flag used to determine whether the current filename should be
erased when the file() method is next used to update the current
filename.

  $Frm->erase($i) if $Frm->nokeep($i);

  $Frm->nokeep($i, 1);  # make ith file temporary
  $Frm->nokeep($i, 0);  # Make ith file permanent

  $nokeep = $Frm->nokeep($i);

The mandatory first argument specifies the file number associated with
this flag (same scheme as used by the file() method). An optional
second argument can be used to set the flag. 'True' indicates that the
file should not be kept, 'false' indicates that the file is permanent.

=cut

sub nokeep {
  my $self = shift;

  croak 'Usage: $Frm->nokeep(file_number,[value]);'
    unless @_;

  my $num = shift;

  # Convert this number to an array index
  my $index = $num - 1;

  # If we have another argument we are setting the value
  if (@_) {
    $self->nokeepArr->[$index] = shift;
  }

  return $self->nokeepArr->[$index];

}

=item B<nokeepArr>

Array of flags. Used internally by nokeep() method.  Set or retrieve
the array containing the flags used by the nokeep() method to
determine whether the current filename should be erased when the
file() method is next used to update the current filename.

    $Frm->nokeepArr(@flags);
    @flags = $Frm->nokeepArr;

    $array_ref = $Frm->nokeepArr;

In a scalar context the array reference is returned.
In an array context, the array contents are returned.

The nokeep() method can be used to set or retrieve individual
flags (the numbering scheme is different).

Note: It is possible to set and retrieve the array members using
the array reference rather than the nokeep() method:

  $first = $Frm->nokeepArr->[0];

In this approach, the numbering starts at 0. The nokeep() method
is the recommended way of addressing individual members of this
array since it could do extra processing of the
string.

=cut

sub nokeepArr {
  my $self = shift;
  if (@_) { @{ $self->{NoKeepArr} } = @_;}

  if (wantarray) {

    # In an array context, return the array itself
    return @{ $self->{NoKeepArr} } if wantarray();

  } else {
    # In a scalar context, return the reference to the array
    return $self->{NoKeepArr};
  }
}

=item B<nsubs>

Return the number of sub-frames associated with this frame.

nfiles() should be used to return the current number of sub-frames
associated with the frame (nsubs usually only reports the number given
in the header and may or may not be the same as the number of sub-frames
currently stored)

Usually this value is set as part of the configure() method from
the header (using findnsubs()) or by using findnsubs() directly.

=cut

sub nsubs {
  my $self = shift;
  if (@_) { $self->{Nsubs} = shift; };
  return $self->{Nsubs};
}

# Method to return/set the filename of the raw data
# Initially this is the same as {File}


=item B<raw>

This method returns (or sets) the name of the raw data file(s)
associated with this object.

  $Frm->raw("raw_data");
  $filename = $Frm->raw;

This method returns the first raw data file if called in scalar
context, or a list of all the raw data files if called in list
context.

=cut

sub raw {
  my $self = shift;
  if (@_) { $self->{RawName} = \@_; }
  return wantarray ? @{$self->{RawName}} : $self->{RawName}->[0];
}

=item B<tempraw>

An array of flags, one per raw file, indicating whether the raw
file is temporary, and so can be deleted, or real data (don't want
to delete it).

  $Frm->tempraw( @istemp );
  @istemp = $Frm->tempraw;

If a single value is given, it will be applied to all raw files

  $Frm->tempraw( 1 );

In scalar context returns true if all frames are temporary,
false if all frames are permanent and undef if some frames are temporary
whilst others are permanent.

  $alltemp = $Frm->tempraw();

=cut

sub tempraw {
  my $self = shift;
  if (@_) {
    my @rawfiles = $self->raw;
    my @flags;
    if (scalar(@_) == 1) {
      @flags = map { $_[0] } @rawfiles;
    } else {
      @flags = @_;
      if (@flags != @rawfiles) {
        croak "Number of tempraw flags (".@flags.") differs from number of registered raw files (".@rawfiles.")\n";
      }
    }
    @{$self->{TempRaw}} = @flags;
  }

  if (wantarray) {
    # will be empty if nothing specified so that will default to
    # undef if the array is read
    return @{$self->{TempRaw}};
  } else {
    my $istemp = 0;
    my $isperm = 0;
    for my $f (@{$self->{TempRaw}}) {
      if ($f) {
        $istemp = 1;
      } else {
        $isperm = 1;
      }
    }
    if ($istemp && $isperm) {
      return undef;
    } elsif ($istemp) {
      return 1;
    } else {
      # Default case if no tempraw has been specified
      return 0;
    }
  }
}

=item B<rawfixedpart>

Return (or set) the constant part of the raw filename associated
with the raw data file. (ie the bit that stays fixed for every 
observation)

  $fixed = $self->rawfixedpart;

=cut

sub rawfixedpart {
  my $self = shift;
  if (@_) { $self->{RawFixedPart} = shift; }
  return $self->{RawFixedPart};
}

=item B<rawformat>

Data format associated with the raw() data file.
Usually one of 'NDF', 'HDS' or 'FITS'. This format should be
recognisable by C<ORAC::Convert>.

=cut

sub rawformat {
  my $self = shift;
  if (@_) { $self->{RawFormat} = shift; }
  return $self->{RawFormat};
}


=item B<rawsuffix>

Return (or set) the file name suffix associated with
the raw data file.

  $suffix = $self->rawsuffix;

=cut

sub rawsuffix {
  my $self = shift;
  if (@_) { $self->{RawSuffix} = shift; }
  return $self->{RawSuffix};
}

# Method to return the recipe name
# If an argument is supplied the recipe is set to that value
# If the recipe is undef then the findrecipe method is invoked to set it


=item B<recipe>

This method returns the recipe name associated with the observation.
The recipe name can be set explicitly but in general should be
set by the findrecipe() method.

  $recipe_name = $Frm->recipe;
  $Frm->recipe("recipe");

This can be configured initially using the findrecipe() method.
Alternatively, findrecipe() is run automatically by the configure()
method.

=cut


sub recipe {
  my $self = shift;
  if (@_) { $self->{Recipe} = shift;}
  return $self->{Recipe};
}


# Return the hash reference containing the tags

sub tags {
  my $self = shift;
  return $self->{Tags};
}

=item B<wcs>

This method can be used to retrieve or set the World Coordinate System
that is currently associated with the frame. Multiple WCSs can be
stored if required (for example the WCSs associated with different
ACSIS sub-instruments).

  $first_wcs = $Frm->wcs;     # First WCS
  $first_wcs = $Frm->wcs(1);  # First WCS
  $second_wcs= $Frm->wcs(2);  # Second WCS
  $Frm->wcs(1, value);         # Set the first WCS
  $Frm->wcs(value);            # Set the first WCS
  $Frm->wcs(10, wcs);        # Set the tenth WCS

Note that counting starts at 1 (and not 0 as is normal for Perl
arrays).

If a WCS number is requested that does not exist, the first member is
returned.

If the first argument is present but not defined the command is
treated as if you typed

  $Frm->wcs(1, undef);

ie the first wcs is set to undef.

=cut

sub wcs {
  my $self = shift;

  # Set it to point to first member by default.
  my $index = 0;

  # Check the arguments.
  if( @_ && defined( $_[0] ) ) {

    my $firstarg = shift;

    # If this is an integer, then we have to grab the second argument
    # and place that in the appropriate place in the array. Otherwise,
    # check to make sure it's an AST::FrameSet object.
    if( defined( $firstarg ) &&
        UNIVERSAL::isa( $firstarg, "Starlink::AST::FrameSet" ) ) {

      $self->{WCS}->[0] = $firstarg;

    } elsif( defined( $firstarg ) &&
             $firstarg =~ /^\d+$/ &&
             $firstarg != 0 ) {

      $index = $firstarg - 1;

      if( @_ ) {

        my $wcs = shift;
        if( UNIVERSAL::isa( $wcs, "Starlink::AST::FrameSet" ) ) {

          $self->{WCS}->[$index] = $wcs;

        }
      }
    }
  }

  $index = 0 if ( $index > $#{$self->{WCS}} - 1);

  # Nothing else of interest so return specified member.
  return $self->{WCS}->[$index];

}

=back

=head2 General Methods

The following methods are provided for manipulating
B<ORAC::Frame> objects:

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames. For IRCAM this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

  %translated = $Frm->calc_orac_headers;

This method updates the frame user header and returns a hash
containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();  # Hash containing the derived headers

  # ORACTIME
  # For IRCAM the keyword is simply RUTSTART
  # Just return it (zero if not available)
  my $time = $self->hdr('RUTSTART');
  $time = 0 unless (defined $time);
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # ORACUT
  # For IRCAM this is simply the IDATE header value
  my $ut = $self->hdr('IDATE');
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);

  # Now create all the ORAC_ headers
  # First attempt is to use Astro::FITS::HdrTrans
  my %trans;
  eval {
    die "HdrTrans not yet enabled\n";
    # we do have the advantage over HdrTrans in that we know
    # the instrument translation table to use via ORAC_INSTRUMENT
    # and this frame class. We may need to add a Frame instrument method
    # that will allow us to hint HdrTrans.
    my $hdr = $self->hdr;
    %trans = Astro::FITS::HdrTrans::translate_from_FITS( $hdr,
							prefix => 'ORAC_');

    # store them in the object and append them to the return hash
    $self->uhdr( %trans );
    %new = (%new, %trans);
  };

  # if we have no values do it the old way
  if (!keys %trans) {
    # go through an array of headers and translate the
    # ones we can find with associated methods

    # Loop over all the headers
    # Do nothing if a translation method does not exist
    # This makes it safe for everyone
    for my $key ( @ORAC_INTERNAL_HEADERS ) {
      my $method = "_to_$key";
  #    print "Trying method $method\n";
      if ($self->can($method)) {
        #      print "Running method $method\n";
        # This returns a single value
        $new{"ORAC_$key"} = $self->$method();
        $self->uhdr("ORAC_$key", $new{"ORAC_$key"});
      }
    }
  }

  return %new;
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file(), raw(), readhdr(), findgroup(), findrecipe and findnsubs()
methods are invoked by this command. Arguments are required.  If there
is one argument it is assumed that this is the raw filename. If there
are two arguments the filename is constructed assuming that argument 1
is the prefix and argument 2 is the observation number.

  $Frm->configure("fname");
  $Frm->configure("UT","num");

Multiple raw file names can be provided in the first argument using
a reference to an array.

=cut

sub configure {
  my $self = shift;

  # If two arguments (prefix and number) 
  # have to find the raw filename first
  # else assume we are being given the raw filename
  my @fnames;
  if (scalar(@_) == 1) {
    my $ref = shift;
    @fnames = ( ref $ref ? @$ref : $ref );
  } elsif (scalar(@_) == 2) {
    @fnames = ( $self->file_from_bits(@_) );
  } else {
    croak 'Wrong number of arguments to configure: 1 or 2 args only';
  }

  # Set the filenames
  for my $i (1..scalar(@fnames)) {
    $self->file($i, $fnames[$i-1]);
  }

  # Set the raw data file name
  $self->raw(@fnames);

  # Populate the header
  $self->readhdr;

  # Find the group name and set it
  $self->findgroup;

  # Find the recipe name
  $self->findrecipe;

  # Find nsubs
  $self->findnsubs;

  # Return something
  return 1;
}

=item B<data_detection_tasks>

When the 'task' looping scheme is enabled, this method returns the name
of the remote task that should be queried for new data. These task names
must be registered with the C<ORAC::Inst::Defn> module.

  @tasks = $Frm->data_detection_tasks();

Returns an empty list in the base class.

=cut

sub data_detection_tasks {
  return ();
}

=item B<erase>

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specified the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}


=item B<file_exists>

Method to determine whether the Frame file() exists on disk or not.
Returns true if the file is there, false otherwise. Effectively
equivalent to using C<-e> but allows for the possibility that the
information stored in file() does not directly relate to the
file as stored on disk (e.g. a .sdf extension). The base class is
very simplistic (ie does not assume extensions).

  $exists = $Frm->file_exists($i)

The optional argument refers to the file number.

=cut

sub file_exists {
  my $self = shift;
  if (-e $self->file(@_)) {
    return 1;
  }
  return 0;
}



=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

=cut

sub file_from_bits {

  # Tim decrees that this must be subclassed.
  die "The base class version of file_from_bits() should not be used\n -- please subclass this method\n";
}

sub file_from_bits_extra {
  my $self = shift;
  return undef;
}

=item B<findgroup>

Returns group name from header.  If we cannot find anything sensible,
we return 0.  The group name stored in the object is automatically
updated using this value.

=cut

sub findgroup {

  my $self = shift;

  my $hdrgrp = $self->hdr('GRPNUM');
  my $amiagroup;

  if ($self->hdr('GRPMEM')) {
    $amiagroup = 1;
  } elsif (!defined $self->hdr('GRPMEM')){
    $amiagroup = 1;
  } else {
    $amiagroup = 0;
  }

  # Is this group name set to anything useful
  if (!$hdrgrp || !$amiagroup ) {
    # if the group is invalid there is not a lot we can do
    # so we just assume 0
    $hdrgrp = 0;
  }

  $self->group($hdrgrp);

  return $hdrgrp;

}

=item B<findnsubs>

Find the number of sub-frames associated with the frame by looking in
the header. Usually run by configure().

In the base class this method looks for a header keyword of 'NSUBS'.

  $nsubs = $Frm->findnsubs;

The state of the object is updated automatically.

=cut

sub findnsubs {
  my $self = shift;
  my $nsubs = $self->hdr->{N_SUBS};
  $self->nsubs($nsubs);
  return $nsubs
}

=item B<findrecipe>

Method to determine the recipe name that should be used to reduce the
observation.  The default method is to look for an "ORAC_RECIPE" entry
in the user header. If one cannot be found, we assume QUICK_LOOK.

  $recipe = $Frm->findrecipe;

The object is automatically updated to reflect this recipe.

=cut


sub findrecipe {
  my $self = shift;

  my $recipe = $self->uhdr('ORAC_RECIPE');

  # Check to see whether there is something there
  # if not try to make something up

  if (!defined($recipe) or $recipe !~ /./) {
    orac_warn "Cannot determine recipe - defaulting to QUICK_LOOK\n";
    $recipe = 'QUICK_LOOK';
  }

  # Update
  $self->recipe($recipe);

  return $recipe;
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This method should be implemented by a sub-class.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  die "The base class version of flag_from_bits() should not be used\n -- please subclass this method\n";

}


=item B<gui_id>

Returns the identification string that is used to compare the
current frame with the frames selected for display in the
display definition file.

Arguments:

 number - the file number (as accepted by the file() method)
          Starts counting at 1. If no argument is supplied
          a 1 is assumed.

To return the ID associated with the second frame:

 $id = $Frm->gui_id(2);

If nfiles() equals 1, this method returns everything after the last
suffix (using an underscore) from the filename stored in file(1). If
nfiles E<gt> 1, this method returns everything after the last
underscore, prepended with 's$number'. ie if file(2) is test_dk, the
ID would be 's2dk'; if file() is test_dk (and nfiles = 1) the ID would
be 'dk'. A special case occurs when the suffix is purely a number (ie
the entire string matches just "\d+"). In that case the number is
translated to a string "num" so the second frame in "c20010108_00024"
would return "s2num" and the only frame in "f2001_52" would return
"num".

Returns C<undef> if the file name is not defined.

=cut

sub gui_id {
  my $self = shift;

  # Read the number
  my $num = 1;
  if (@_) { $num = shift; }

  # Retrieve the Nth file name (start counting at 1)
  my $fname = $self->file($num);
  return undef unless defined $fname;

  # Split on underscore
  my (@split) = split(/_/,$fname);
  my ($junk, $fsuffix) = $self->_split_fname( $fname );
  @split = @$junk;

  my $id = $split[-1];

  # If we have a number translate to "num"
  $id = "num" if ($id =~ /^\d+$/);

  # Find out how many files we have
  my $nfiles = $self->nfiles;

  # Prepend wtih s$num if nfiles > 1
  # This is to make it simple for instruments that only ever
  # store one frame (eg UFTI)
  $id = "s$num" . $id if $nfiles > 1;

  return $id;

}


=item B<inout>

Method to return the current input filename and the new output
filename given a suffix.  For the base class the input filename is
chopped at the last underscore and the suffix appended when the name
contains at least 2 underscores. The suffix is simply appended if
there is only one underscore. This prevents numbers being chopped when
the name is of the form ut_num.

Note that this method does not set the new output name in this
object. This must still be done by the user.

Returns $in and $out in an array context:

   ($in, $out) = $Frm->inout($suffix);

Returns $out in a scalar context:

   $out = $Frm->inout($suffix);

Therefore if in=file_db and suffix=_ff then out would
become file_db_ff but if in=file_db_ff and suffix=dk then
out would be file_db_dk.

An optional second argument can be used to specify the
file number to be used. Default is for this method to process
the contents of file(1).

  ($in, $out) = $Frm->inout($suffix, 2);

will return the second file name and the name of the new output
file derived from this.

The last suffix is not removed if it consists solely of numbers.
This is to prevent truncation of raw data filenames.

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1; 
  if (@_) { $num = shift; }

  my $infile = $self->file($num);

  # Chop off at last underscore
  # Must be able to do this with a clever pattern match
  # Want to use s/_.*$// but that turns a_b_c to a and not a_b

  # instead split on underscore and recombine using underscore
  # but ignoring the last member of the split array
  my ($junk, $fsuffix) = $self->_split_fname( $infile );

  # Suffix is ignored
  my @junk = @$junk;

  # We only want to drop the SECOND underscore. If we only have
  # two components we simply append. If we have more we drop the last
  # This prevents us from dropping the observation number in
  # ro970815_28
  # We special case when the last thing is a number
  if ($#junk > 1 && $junk[-1] !~ /^\d+$/) {
    @junk = @junk[0..$#junk-1];
  }

  # Need to strip a leading underscore if we are using join_name
  $suffix =~ s/^_//;
  push(@junk, $suffix);

  my $outfile = $self->_join_fname(\@junk, '');

  # Generate a warning if output file equals input file
  orac_warn("inout - output filename equals input filename ($outfile)\n")
    if ($outfile eq $infile);

  return ($infile, $outfile) if wantarray();  # Array context
  return $outfile;                            # Scalar context
}


=item B<nfiles>

Number of files associated with the current state of the object and
stored in file(). This method lets the caller know whether an
observation has generated multiple output files for a single input.

=cut

sub nfiles {
  my $self = shift;
  my $num = $#{$self->files} + 1;
  return $num;
}

# Supply a method to return the number associated with the observation

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
  if (defined $raw && $raw =~ /(\d+)(\.\w+)?$/) {
    # Drop leading 00
    $number = $1 * 1;
  } else {
    # No match so set to -1
    $number = -1;
  }

  return $number;

}

=item B<pattern_from_bits>

Determine the pattern for the raw filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $pattern = $Frm->pattern_from_bits($prefix, $obsnum);

Returns a regular expression object.

=cut

sub pattern_from_bits {

  # Tim decrees that this must be subclassed.
  die "The base class version of pattern_from_bits() should not be used\n -- please subclass this method\n";
}

=item B<tagset>

Associate the current filenames with a key (or tag). Once a tag
is initialised (it can be any string) the C<tagretrieve> method
can be used to copy these filenames back into the object so that
the C<files()> method will use those rather than the current
values. This allows the data reduction steps to be "rewound".

  $Frm->tagset('REBIN');

The tag is case insensitive.

=cut

sub tagset {
  my $self = shift;
  if (@_) {
    my $tag = shift;
    $self->tags->{$tag} = [ $self->files ];
  }
}

=item B<tagretrieve>

Retrieve the files names from the tag and make them the default
filenames for the object.

  $Frm->tagretrieve('REBIN');

Nothing happens if the tag does not previously exist.
The current filenames are stored in the 'PREVIOUS' tag (unless the
PREVIOUS tag is requested).

=cut

sub tagretrieve {
  my $self = shift;
  if (@_) {
    my $tag = shift;
    if (exists $self->tags->{$tag}) {
      # Store the previous values
      $self->tagset( 'PREVIOUS' ) unless $tag eq 'PREVIOUS';
      # Retrieve the current values
      $self->files( @{ $self->tags->{$tag} } );
    }
  }
}


=item B<template>

Method to change the current filename of the frame (file())
so that it matches a template. e.g.:

  $Frm->template("something_number_flat");

Would change the first file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

  $Frm->template("something_number_dark", 2);

would change the second filename to match "something_number_dark".
The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

The Nth filename is modified (ie file(N)).
There are no return arguments.

=cut

sub template {
  my $self = shift;
  my $template = shift;

  my $fnum = 1;
  if (@_) { $fnum = shift; };

  my $num = $self->number;
  # Change the first number
  $template =~ s/_\d+_/_${num}_/;

  # Update the filename
  $self->file($fnum, $template);

}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=cut

# Private method for removing file extensions from the filename strings
# In the base class this does nothing. It is up to the derived classes
# To do something special with this.

=over 4


=item B<_split_fname>

Given a file name, splits it into an array and a suffix. The first
array contains the separate components of the file name (in the case
of the base class these are the parts joined by underscores). The
second argument suffix information.

  ($bitsref, $suffix) = $frm->_split_fname( $file );
  @bits = @$bitsref;

A suffix is anything after the first "." in the filename.

=cut

sub _split_fname {
  my $self = shift;
  my $file = shift;

  # Split the thing on dots first
  my @dots = split(/\./, $file, 2);

  my $suffix;
  $suffix = $dots[1] if $#dots > 0;

  # split on underscores
  my @us = split(/_/, $dots[0]);

  return \@us, $suffix;

}

=item B<_join_fname>

Reverse of C<split_fname>.

   $file = $frm->_join_fname(\@bits, $suffix);

=cut

sub _join_fname {
  my $self = shift;
  my ($bits, $suffix) = @_;
  $suffix = '' unless defined $suffix;

  my $root = join('_', @$bits);

  my $file = $root;
  $file .= ".$suffix" if length($suffix) > 0;

  return $file;
}

=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;

