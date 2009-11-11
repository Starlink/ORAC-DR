package ORAC::BaseFile;

=head1 NAME

ORAC::BaseFile - Shared Base class for Frame and Group classes

=head1 SYNOPSIS

  use base qw/ ORAC::BaseFile /;


=head1 DESCRIPTION

This class contains methods that are shared by both Frame and Group
classes. For example, header and user-header manipulation. File format
specific code should not be included (use, for example, C<ORAC::BaseNDF>).

=cut

use 5.006;
use Carp;
use strict;
use warnings;
use vars qw/ $VERSION /;

use ORAC::Print;
use Astro::FITS::Header;
use Astro::FITS::HdrTrans 1.00;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are available in this class:

=head2 Constructors

The following constructors are available:

=over 4

=item B<new>

Create a new C<ORAC::BaseFile> object. In general this constructor
should not be called directly but should be called from a subclass.

  $file = ORAC::BaseFile->new( $filename );
  $file = ORAC::BaseFile->new( \@filenames );
  $file = ORAC::BaseFile->new();

The filename is optional. Multiple files are supplied as a reference
to an array.

The base class constructor should be invoked by sub-class constructors.
If this method is called with the last argument as a reference to
a hash it is assumed that this hash contains extra configuration
information ('instance' information) supplied by sub-classes.

  $file = ORAC::BaseFile->new( \%internal );

Calls the configure method to handle sub-class specific configuration.
The file arguments to configure match the arguments to the constructor.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # process subclass constructor items
  # and add the initial state for the object
  my ($frame, $args) = $class->_process_constructor_args({
                                                          AllowHeaderSync => undef,
                                                          Files => [],
                                                          RawName => [],
                                                          Format => undef,

                                                          Header => {},
                                                          Intermediates => [],

                                                          NoKeepArr => [],

                                                          Product => undef,

                                                          UHeader => {},
                                                          Tags => {},
                                                          WCS => [],
                                                         }, @_);

  bless($frame, $class);

  # If arguments are supplied then we can configure the object

  # Currently the argument will be the filename.
  $frame->configure(@$args) if @$args;

  return $frame;
}

=back

=head2 Accessor Methods

=over 4

=item B<allow_header_sync>

Whether or not to allow automatic header synchronization when the
Frame is updated via either the C<file> or C<files> method.

  $Frm->allow_header_sync( 1 );
  my $allow = $Frm->allow_header_sync;

Defaults to false (0).

=cut

sub allow_header_sync {
  my $self = shift;
  if ( @_ ) {
    $self->{AllowHeaderSync} = shift;
  }
  return $self->{AllowHeaderSync};
}

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

The first time a filename is stored the name will also be stored in
C<raw()> if no previous entries have been made in C<raw>.

If the requested index is the number "0" an exception will be thrown since
it is highly unlikely that you wanted a file name called "0".

=cut

sub file {
  my $self = shift;

  # Set it to point to first member by default
  my $index = 0;

  # Check the arguments
  if (@_  && defined $_[0]) {

    my $firstarg = shift;

    # special case zero
    if ($firstarg eq "0") {
      throw ORAC::Error::FatalError("Index out of range (0) for file() method. Possible programming error. Index should be at least 1");
    }

    # This can either be an integer for retrieval or
    # an integer + filename for setting or just a filename for setting
    # $index is the lookup into the array
    # $filenum is the lookup into the file number (starting at 1)
    # and can correspond to the supplied integer.

    my $filenum = 1;            # default if none supplied

    my $filename;               # if we have been given a filename

    # Check for int and non-zero (since strings eval as 0)
    # Cant use int() since this extracts integers from the start of a
    # string! Match a string containing only digits
    if (defined $firstarg && $firstarg =~ /^\d+$/ && $firstarg != 0) {

      # Decrement value so that we can use it as a perl array index
      $index = $firstarg - 1;

      # If we have more arguments we are setting a value
      # else wait until we return the specified value
      if (@_) {

        # we have been given a filename so store the number
        $filenum = $firstarg;

        # and store the filename
        $filename = shift(@_);

      }

    } else {

      # it seems that we are being given a filename rather than a number
      $filename = $firstarg;

    }

    # if we have a filename we should process it
    if (defined $filename) {

      # First check that the old file should not be
      # removed before we update the object
      # [Note that the erase method calls this method...]
      $self->erase($filenum) if $self->nokeep($filenum);

      # Now update the filename
      $self->files->[$index] = $self->stripfname($filename);

      # if raw is not set, update it
      $self->raw( $self->files->[$index] ) unless defined $self->raw;;

      # Make sure the nokeep flag is unset
      $self->nokeep($filenum,0);

      # Push current file onto file history array. Not previous.
      # We do this for consistency with files() method and to
      # allow cleanup to remove current files.
      $self->push_intermediates( $self->files->[$index] );

      # Sync the headers. Use the $firstarg value as that's the
      # 1-based index.
      $self->sync_headers( $filenum );
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

The first time a filename is stored the name will also be stored in
C<raw()> if no previous entries have been made in C<raw>.

=cut

sub files {
  my $self = shift;
  if (@_) {
    # get copies of current files
    my @oldfiles = @{$self->{Files}};

    # delete the old files if required
    for my $i (1..@oldfiles) {
      $self->erase( $i ) if $self->nokeep( $i );
    }

    # Store the new versions
    @{ $self->{Files} } = @_;

    # Also in raw if raw is empty
    $self->raw( @{ $self->{Files} } ) unless defined $self->raw;;

    # And store the new files on the intermediates array.
    # Note that we store new and not old to guarantee
    # that we can clear out the final files that are created if
    # necessary. This means that intermediates also includes current
    $self->push_intermediates( @_ );

    # unset noKeep flags
    for my $i (1..scalar(@_)) {
      $self->nokeep( $i, 0);
    }

    # Sync the headers.
    for my $i ( 1..scalar( @_ ) ) {
      $self->sync_headers( $i );
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
  if (@_) {
    $num = shift;
  }

  # Retrieve the Nth file name (start counting at 1)
  my $fname = $self->file($num);
  return unless defined $fname;

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

=item B<fits>

Return (or set) the C<Astro::FITS::Header> object associated with
the FITS header from the raw data. If you simply want to access
individual FITS headers then you probably should be using
the C<hdr> method.

  $Frm->fits( $fitshdr );
  $fitshdr = $Frm->fits;

Translated FITS headers are available using the C<uhdr> method.

If no FITS header has been associated with this object, one
is automatically created from the C<hdr>. This allows the
header to be derived from either a FITS object or a normal
hash.

=cut

sub fits {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    # Test its type unless it is undef
    if (defined $arg) {
      croak "Argument to fits() must be of class Astro::FITS::Header"
        unless UNIVERSAL::isa($arg, "Astro::FITS::Header");
    }
    $self->{FitsHdr} = $arg;
    # clear the tied version to force a resync
    $self->{Header} = undef;
  }

  # Create a new fits object if we have not got one
  # Code cribbed from OMP::Info::Obs
  my $fits = $self->{FitsHdr};
  if ( ! defined( $fits ) ) {

    # Note that the hdr() method calls the fits() method if
    # no hash exists. To prevent recursion problems we do not use
    # the accessor method here
    my $hdrhash = $self->{Header};
    if ( defined( $hdrhash ) ) {

      my @items = map { new Astro::FITS::Header::Item( Keyword => $_,
                                                       Value => $hdrhash->{$_}
                                                     ) } keys (%{$hdrhash});

      # Create the Header object.
      $fits = new Astro::FITS::Header( Cards => \@items );

      $self->{FitsHdr} =  $fits;

      # And force the old header hash to be a tie derived from this
      # object [making sure that multi-valued headers are returned as an array]
      $fits->tiereturnsref(1);
      tie my %header, ref($fits), $fits;
      $self->{Header} = \%header;

    }
  }
  return $fits;
}

=item B<format>

Data format associated with the current file().
Usually one of 'NDF' or 'FITS'. This format should be
recognisable by C<ORAC::Convert>.

=cut

sub format {
  my $self = shift;
  if (@_) {
    $self->{Format} = shift;
  }
  return $self->{Format};
}

=item B<hdr>

This method allows specific entries in the header to be accessed.  In
general, this header is related to the actual header information
stored in the file. The input argument should correspond to the
keyword in the header hash.

  $tel = $Frm->hdr("TELESCOP");
  $instrument = $Frm->hdr("INSTRUME");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->hdr("INSTRUME" => "IRCAM");
  $Frm->hdr("INSTRUME" => "SCUBA",
            "TELESCOP" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Grp->hdr->{INSTRUME} = 'SCUBA';

The header can be populated from the file by using the readhdr()
method. If a FITS header object has been set via the C<fits>
method, a new header hash will be created automatically if one
does not exist already (via a tie).

If there were two headers in the original FITS header only the
last header is returned (in scalar context). All headers are returned
in list context.

  @all = $Frm->hdr("COMMENT");
  $last = $Frm->hdr("HISTORY");

=cut

sub hdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {

    # Force a synch with the FITS header object if needed
    # Call with no arguments so there are no worries with
    # recursion loops.
    my $hdr = $self->hdr();

    if (scalar(@_) == 1) {
      # Return the value if we have a single argument
      my $key = shift;
      my $value = $hdr->{$key};
      if (ref($value) eq 'ARRAY') {
        # multi-valued
        if (wantarray) {
          return @$value;
        } else {
          # Return the last element since that is what you
          # would get if you read the header as a hash
          return $value->[-1];
        }
      } else {
        return $value;
      }
    } else {

      # Since in most cases we will be processing fewer
      # headers than we already have, it is more efficient
      # to step through each header in turn rather than
      # doing a hash push: %a = (%a, %b) although this
      # has not been verified by benchmarks
      my %new = @_;
      for my $key (keys %new) {
        # print "Storing $new{$key} in key $key\n";
        $hdr->{$key} = $new{$key};
      }
    }
  } else {
    # No arguments, return the header hash reference
    # or tie it to the new one
    my $hdr = $self->{Header};
    if ( ! defined( $hdr ) || scalar keys %$hdr == 0) {
      my $fits = $self->fits();
      if ( defined( $fits ) ) {
        my $FITS_header = $fits;
        tie my %header, ref($FITS_header), $FITS_header;
        $self->{Header} = \%header;
      }
    }
    return $self->{Header};
  }
}

=item B<hdrval>

Return the requested header entry, automatically dealing with
subheaders. Essentially overrides the standard hdr method for
retrieving a header value. Returns undef if no arguments are passed.

    $value = $Frm->hdrval( "KEYWORD" );
    $value = $Frm->hdrval( "KEYWORD", 0 );

Both return the values from the first sub-header (index 0) if the
value is not present in the primary header.

=cut

sub hdrval {
  my $self = shift;

  if ( @_ ) {
    my $keyword = shift;
    # Set a default subheader index of 0, the first subheader
    my $subindex = @_ ? shift : 0;

    my $hdrval = ( defined $self->hdr->{SUBHEADERS}->[$subindex]->{$keyword}) ?
      $self->hdr->{SUBHEADERS}->[$subindex]->{$keyword} :
        $self->hdr("$keyword");

    return $hdrval;

  } else {
    # If no args, warn the user and return undef
    orac_warn "hdrval method requires at least a keyword argument\n";
    return;
  }

}

=item B<hdrvals>

Return all the different values associated with a single FITS
header taken from all subheaders.

  @values = $Frm->hdrvals( $keyword );

Only unique values are returned. Quickly enables the caller to determine
how many distinct states are in the Frame.

=cut

sub hdrvals {
  my $self = shift;
  my $keyword = shift;
  my @values;
  my %uniq;

  # do not use hdrval since we only want to check the primary header
  # once
  my $hdr = $self->hdr;
  if (exists $self->hdr->{$keyword} ) {
    my $primary = $self->hdr->{$keyword};
    push(@values, $primary);
    $uniq{$primary}++;
  }

  # sub headers
  for my $sh (@{$hdr->{SUBHEADERS}}) {
    if (exists $sh->{$keyword}) {
      my $sec = $sh->{$keyword};
      if (!exists $uniq{$sec}) {
        push(@values, $sec);
        $uniq{$sec}++;
      }
    }
  }
  return @values;
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
file derived from this. An explicit undefined value will cause the
file() method to be invoked without arguments.

The last suffix is not removed if it consists solely of numbers.
This is to prevent truncation of raw data filenames.

=cut

sub inout {

  my $self = shift;

  my $suffix = shift;

  # Read the number
  my $num = 1;
  if (@_) {
    $num = shift;
  }

  # pass no argument if the number is not defined
  my $infile = $self->file(defined $num ? $num : ());

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

  return ($infile, $outfile) if wantarray(); # Array context
  return $outfile;                           # Scalar context
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

See also the push_intermediates() method.

=cut

sub intermediates {
  my $self = shift;
  if (@_) {
    @{ $self->{Intermediates} } = @_;
  }

  # Ensure the intermediates list is unique.
  my %seen = ();
  @{$self->{Intermediates}} = grep { ! $seen{$_} ++ } @{$self->{Intermediates}};

  if (wantarray) {

    # In an array context, return the array itself
    return @{ $self->{Intermediates} } if wantarray();

  } else {
    # In a scalar context, return the reference to the array
    return $self->{Intermediates};
  }
}

=item B<push_intermediates>

Equivalent to

  push(@{$Frm->intermediates}, @files);

but ensures that raw frames are not stored on the intermediates
array (do not want to risk deleting raw data).

Returns the number of intermediates that were stored (ie
either 0 or the number of file names supplied).

=cut

sub push_intermediates {
  my $self = shift;

  # get the input files
  my @files = @_;

  # Get the raw files.
  # This is all a bit painful given that we expect raw to
  # be stored only for an empty intermediates array but do
  # we want to take the risk?
  my %raw = map { $self->stripfname($_), undef } $self->raw;

  # filter out raw
  @files = grep { !exists $raw{$self->stripfname($_)} } @files;

  # store them
  push(@{$self->intermediates}, @files) if @files;
  return scalar(@files);
}

=item B<raw>

This method returns (or sets) the name of the raw data file(s)
associated with this object.

  $Frm->raw("raw_data");
  $filename = $Frm->raw;

This method returns the first raw data file if called in scalar
context, or a list of all the raw data files if called in list
context.

Populated automatically the first time the C<files> method is used (or during
initial object configuration).

=cut

sub raw {
  my $self = shift;
  if (@_) {
    @{$self->{RawName}} = @_;
  }
  if (wantarray) {
    return @{$self->{RawName}};
  } else {
    # do not initialise the first element so take copy
    my @raw = @{$self->{RawName}};
    return $raw[0];
  }
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
  if (@_) {
    @{ $self->{NoKeepArr} } = @_;
  }

  if (wantarray) {

    # In an array context, return the array itself
    return @{ $self->{NoKeepArr} } if wantarray();

  } else {
    # In a scalar context, return the reference to the array
    return $self->{NoKeepArr};
  }
}


=item B<product>

Set or return the "product" of the current File object.

  $self->product( 'Baselined cube' );
  $product = $self->product;

A "product" is a description of what the current Frame actually
is. For example, in an imaging pipeline this might be
"dark-subtracted" or "flat-fielded".

=cut

sub product {
  my $self = shift;
  if ( @_ ) {
    $self->{Product} = shift;
  }
  ;
  return $self->{Product};
}

# internal accessor for tags hash. Not a public interface
# use the tagretrieve and tagset methods.

sub tags {
  my $self = shift;
  return $self->{Tags};
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

  my $status = $Frm->tagretrieve('REBIN');

The current filenames are stored in the 'PREVIOUS' tag (unless the
PREVIOUS tag is requested).

If the given tag does not exist, then this function returns
false. Otherwise returns true.

Automatic header syncing is disabled inside this method.

=cut

sub tagretrieve {
  my $self = shift;
  if (@_) {
    # Do not want the files() method to trigger header rewrites of the
    # old files
    my $sync = $self->allow_header_sync();
    $self->allow_header_sync( 0 );
    my $tag = shift;
    if (exists $self->tags->{$tag}) {
      # Store the previous values
      $self->tagset( 'PREVIOUS' ) unless $tag eq 'PREVIOUS';
      # Retrieve the current values
      $self->files( @{ $self->tags->{$tag} } );
    }
    $self->allow_header_sync( $sync );
    return exists $self->tags->{$tag};
  }
  return 0;
}


=item B<uhdr>

This method allows specific entries in the user-defined header to be
accessed. The input argument should correspond to the keyword in the
user header hash.

  $tel = $Grp->uhdr("Telescope");
  $instrument = $Frm->uhdr("Instrument");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->uhdr("Instrument" => "IRCAM");
  $Frm->uhdr("Instrument" => "SCUBA",
             "Telescope" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Frm->uhdr->{Instrument} = 'SCUBA';

=cut



sub uhdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{UHeader}->{$key};
    } else {

      # Since in most cases we will be processing fewer
      # headers than we already have, it is more efficient
      # to step through each header in turn rather than
      # doing a hash push: %a = (%a, %b) although this
      # has not been verified by benchmarks
      my %new = @_;
      for my $key (keys %new) {
        # print "Storing $new{$key} in key $key\n";
        $self->{UHeader}->{$key} = $new{$key};
      }

    }
  } else {
    # No arguments, return the header hash reference
    return $self->{UHeader};
  }
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
  if ( @_ && defined( $_[0] ) ) {

    my $firstarg = shift;

    # If this is an integer, then we have to grab the second argument
    # and place that in the appropriate place in the array. Otherwise,
    # check to make sure it's an AST::FrameSet object.
    if ( defined( $firstarg ) &&
         UNIVERSAL::isa( $firstarg, "Starlink::AST::FrameSet" ) ) {

      $self->{WCS}->[0] = $firstarg;

    } elsif ( defined( $firstarg ) &&
              $firstarg =~ /^\d+$/ &&
              $firstarg != 0 ) {

      $index = $firstarg - 1;

      if ( @_ ) {

        my $wcs = shift;
        if ( UNIVERSAL::isa( $wcs, "Starlink::AST::FrameSet" ) ) {

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

=over 4

=item B<sync_headers>

This method is used to synchronize FITS headers with information
stored in e.g. the World Coordinate System.

  $Frm->sync_headers;
  $Frm->sync_headers(1);

This method takes one optional parameter, the index of the file to
sync headers for. This index starts at 1 instead of 0.

Headers are only synced if the value returned by C<allow_header_sync>
is true.

=cut

sub sync_headers {
  my $self = shift;
  return unless $self->allow_header_sync;
  warn "Stub sync_headers does nothing. Please inherit from BaseNDF or BaseFITS";
}

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

  my %new = ();                 # Hash containing the derived headers

  # Now create all the ORAC_ headers
  # First attempt is to use Astro::FITS::HdrTrans
  my %trans;
  eval {
    # we do have the advantage over HdrTrans in that we know
    # the instrument translation table to use via ORAC_INSTRUMENT
    # and this frame class. We may need to add a Frame instrument method
    # that will allow us to hint HdrTrans.
    my $hdr = $self->hdr;
    if ( ! keys %$hdr ) {
      die "This observation is missing its FITS headers";
    }
    %trans = Astro::FITS::HdrTrans::translate_from_FITS( $hdr,
                                                         prefix => 'ORAC_');

    # store them in the object and append them to the return hash
    $self->uhdr( %trans );
    %new = (%new, %trans);
  };

  # if we have no keys we can not process this observation
  if (!keys %trans) {
    die "There was an error translating headers for this observation: $@";
  }

  # Store the standardised ORACUT and ORACTIME (and ORACDATETIME)
  $new{ORACUT} = $self->uhdr("ORAC_UTDATE");
  $self->hdr( "ORACUT", $new{ORACUT});

  my $start = $self->uhdr("ORAC_UTSTART");
  my $oractime = 0;
  my $oracdatetime = '';
  if (defined $start) {
    my $base = $new{ORACUT};
    my $frac;
    if (ref($start) && $start->can("hour")) {
      # This should be the case for Astro::FITS::HdrTrans
      $frac = ($start->hour + ($start->min / 60) + ($start->sec / 3600) ) / 24;

      # ORACDATETIME is therefore easy
      $oracdatetime = $start->datetime;

    } elsif ($start < 19000101) {
      # This is the case for old UKIRT ORAC-DR header translation
      # of hours in the UT night
      $frac = $start / 24;
    } else {
      # already an oractime - rare
      $frac = int($start);
    }
    $oractime = $base + $frac;
    $new{ORACTIME} = $oractime;

    # reconstruct from oractime
    if (!$oracdatetime) {
      my $year = substr($base, 0, 4);
      my $month= substr($base, 4, 2);
      my $day  = substr($base, 6, 2);
      my $hours = $frac * 24;
      my $h = int($hours);
      my $minutes = ($hours - $h) * 60;
      my $m = int($minutes);
      my $s = ($minutes - $m) * 60;

      $oracdatetime = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year,
                              $month, $day, $h, $m, int($s));
      $new{ORACDATETIME} = $oracdatetime;
    }

  }
  $self->hdr("ORACTIME", $oractime);
  $self->hdr("ORACDATETIME", $oracdatetime);

  return %new;
}

=item B<configure>

This method is used to configure the object. It is invoked
automatically if the new() method is invoked with an argument. The
file() and readhdr()
methods are invoked by this command. A single argument is required (to provide
compatibility with subclasses) that either refers to the filename or a reference
to an array of filenames. Note that the 2 arg version is only supported by
specific subclasses (see documentation).

  $Frm->configure( $filename );
  $Frm->configure( \@files );

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

  # Return something
  return 1;
}


=item B<readhdr>

A method that is used to read header information from the group
file. This method does nothing by default since the base
class does not know the format of the file associated with an
object.

The calc_orac_headers() method is called automatically.

=cut

sub readhdr {
  my $self = shift;
  $self->calc_orac_headers;
  return;
}

=item B<translate_hdr>

Translates an ORAC-DR specific header (such as ORAC_TIME)
to the equivalent FITS header(s).

  %fits = $Frm->translate_hdr( "ORAC_TIME" );

In some cases a single ORAC-DR header can be decomposed into
multiple FITS headers (for example for SCUBA, ORAC_TIME is
a combination of the UTDATE and UTSTART). The hash returned
by translate_hdr() will include all the key/value pairs required
to generate the ORAC header.

This method will be called automatically to update hdr() values
ORAC_ keywords are updated via uhdr().

Returns an empty list if no translation is available.

=cut

sub translate_hdr {
  my $self = shift;
  my $key = shift;
  return () unless defined $key;

  # Remove leading ORAC_
  $key =~ s/^ORAC_//;

  # Each translation is performed by an individual method
  # This adds a overhead for method lookups but hopefully
  # will lend itself to subclassing
  # The translate_hdr() method itself will then not need to be
  # subclassed at all
  my $method = "from_$key";

  # get the user header
  my %newhash;
  while ( ( my $key, my $value ) = each %{$self->uhdr} ) {
    $key =~ s/^ORAC_//;
    $newhash{$key} = $value;
  }
  my $class = $newhash{_TRANSLATION_CLASS};
  if ($class && $class->can($method)) {
    return $class->$method( \%newhash );
  } else {
    return ();
  }
}

=back

=begin __PRIVATE__

=head2 Private Methods

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. For the base class this method
does nothing. It is intended for derived classes (e.g. so that ".sdf"
can be removed).

=cut


sub stripfname {

  my $self = shift;
  my $name = shift;
  return $name;
}

=item B<_process_constructor_args>

Given arguments for a constructor, locates the arguments intended
for the internal constructor initialisation and merge them with defaults
returning a reference to a hash of the processed arguments and a reference
to an array of unmodified arguments (with internal controls removed)

 ($internals, $args) = $self->_process_constructor_args( \%defaults, @_ );

=cut

sub _process_constructor_args {
  my $self = shift;
  my $defaults = shift;
  my @args = @_;

  # look for hash arg at end of remaining arguments
  my %subclass;
  %subclass = %{ pop(@args) } if (ref($args[-1]) eq 'HASH');

  # and merge with defaults
  %subclass = (%$defaults, %subclass);

  return (\%subclass, \@args);
}


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

  if (!defined $file) {
    Carp::confess("File supplied to _split_fname is not defined. Possible programming error");
  }

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

=end __PRIVATE__

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
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
