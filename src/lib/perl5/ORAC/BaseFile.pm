package ORAC::BaseFile;

=head1 NAME

ORAC::BaseFile - Shared Base class for Frame and Group classes

=head1 SYNOPSIS

  use base qw/ ORAC::BaseFile /;


=head1 DESCRIPTION

This class contains methods that are shared by both Frame and Group
classes. For example, header and user-header manipulation.

=cut

use 5.006;
use Carp;
use strict;
use warnings;
use vars qw/ $VERSION /;

use Astro::FITS::Header;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

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
  my $frame = { AllowHeaderSync => undef,
                Files => [],
                Format => undef,
                Group => undef,
                Header => {},
                Intermediates => [],
                IsGood => 1,
                NoKeepArr => [],
                Nsubs => undef,
                Product => undef,
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
  if( @_ ) { $self->{AllowHeaderSync} = shift; }
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

        # Sync the headers. Use the $firstarg value as that's the
        # 1-based index.
        $self->sync_headers( $firstarg );

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

      # Sync the headers of the first file.
      $self->sync_headers(1);

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
  }

  # Create a new fits object if we have not got one
  # Code cribbed from OMP::Info::Obs
  my $fits = $self->{FitsHdr};
  if( ! defined( $fits ) ) {

    # Note that the hdr() method calls the fits() method if
    # no hash exists. To prevent recursion problems we do not use
    # the accessor method here
    my $hdrhash = $self->{Header};
    if( defined( $hdrhash ) ) {

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
    if( ! defined( $hdr ) || scalar keys %$hdr == 0) {
      my $fits = $self->fits();
      if( defined( $fits ) ) {
	my $FITS_header = $fits;
	tie my %header, ref($FITS_header), $FITS_header;
	$self->{Header} = \%header;
      }
    }
    return $self->{Header};
  }
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

Flag to determine the current state of the frame. If isgood() is true
the Frame is valid. If it returns false the frame object may have a
problem (eg the recipe responsible for processing the frame failed to
complete).

This flag is used by the B<ORAC::Group> class to determine membership.

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
in the header and may or may not be the same as the number of
sub-frames currently stored)

Usually this value is set as part of the configure() method from the
header (using findnsubs()) or by using findnsubs() directly.

=cut

sub nsubs {
  my $self = shift;
  if (@_) { $self->{Nsubs} = shift; };
  return $self->{Nsubs};
}

=item B<product>

Set or return the "product" of the current Frame object.

  $self->product( 'Baselined cube' );
  $product = $self->product;

A "product" is a description of what the current Frame actually
is. For example, in an imaging pipeline this might be
"dark-subtracted" or "flat-fielded".

=cut

sub product {
  my $self = shift;
  if( @_ ) { $self->{Product} = shift; };
  return $self->{Product};
}

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

sub tags {
  my $self = shift;
  return $self->{Tags};
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

=over 4

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
  my $method = "_from_$key";
  # print "trying method translate $method\n";
  if ($self->can($method)) {
    return $self->$method();

  } else {
    return ();
  }
}

=item B<_from_*>

Methods to translate ORAC_ private headers to FITS headers
required by the instrument. This is the reverse of C<_to_*> called
from C<calc_orac_headers>.

These methods should only be called by C<translate_hdr>

Returns a hash containing the FITS key(s) and value(s).

   %fits = $Frm->_from_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=item B<_to_*>

Methods to translate standard FITS headers to ORAC_ headers.
These methods should be called just from C<orac_calc_headers>.

Returns the translated value.

  $val = $Frm->_to_AIRMASS_START();

The method name does not include the ORAC_ prefix.

=cut

# Generate the methods automatically from a lookup table
# This only works with one-to-one mappings of keywords.

# This method generates all the internal methods
# Expects a hash ref as argument and simply does a name
# translation without any data processing
# The hash is keyed by the ORAC_ name (without the ORAC_ prefix
# (although that will be removed if it appears)
# This is a class method (no object required)
sub _generate_orac_lookup_methods {
  my $class = shift;
  my $lut = shift;

  # Have to go into a different package
  my $p = "{\n package $class;\n";
  my $ep = "\n}"; # close the scope

  # Loop over the keys to the hash
  for my $key (keys %$lut) {

    # Get the original FITS header name
    my $fhdr = $lut->{$key};

    # Remove leading ORAC_ if it is there since the method
    # should not include it
    $key =~ s/^ORAC_//;

    # prepend ORAC_ for the actual key name
    my $ohdr = "ORAC_$key";

    # print "Processing $key and $ohdr and $fhdr\n";

    # First generate the code to generate ORAC_ headers
    my $subname = "_to_$key";
    my $sub = qq/ $p sub $subname { \$_[0]->hdr(\"$fhdr\"); } $ep /;
    eval "$sub";

    # Now the from 
    $subname = "_from_$key";
    $sub = qq/ $p sub $subname { (\"$fhdr\", \$_[0]->uhdr(\"$ohdr\")); } $ep/;
    eval "$sub";

  }

}

=back

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


=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
