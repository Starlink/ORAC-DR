package ORAC::Calib;

=head1 NAME

ORAC::Calib - base class for selecting calibration frames in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Calib;

  $Cal = new ORAC::Calib;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $bias = $Cal->bias;


=head1 DESCRIPTION

This module provides the basic methods available to all ORAC::Calib
objects.  This class should be used for selecting calibration frames.

Unless specified otherwise, a calibration frame is selected by first,
the nearest reduced frame; second, explicit specification via the
-calib command line option (handled by the pipeline); third, by search
of the appropriate index file.

Note this version: Index files not implemented.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use ORAC::Inst::Defn qw/ orac_determine_calibration_search_path /;
use File::Spec;
use File::Copy;

$VERSION = '1.0';

# Setup the object structure

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a ORAC::Calib object.
The object identifier is returned.

  $Cal = new ORAC::Calib;

=cut

# NEW - create new instance of Calib.

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $obj = {};                 # Anon hash reference
  $obj->{Thing1} = {};          # ditto
  $obj->{Thing2} = {};          # ditto

  bless($obj, $class);

  # Take no arguments at present
  return $obj;

}

=back

=head2 Accessor Methods

=over 4

=cut

# Frossie's things
# ----------------

=item B<thing>

Returns the hash that can be used for checking the validity of
calibration frames. This is a combination of the two hashes
stored in C<thingone> and C<thingtwo>. The hash returned
by this method is readonly.

  $hdr = $Cal->thing;

=cut

sub thing {
  return { %{$_[0]->thingone}, %{$_[0]->thingtwo} };
}

=item B<thingone>

Returns or sets the hash associated with the header of the object
(frame or group or whatever) needed to match calibration criteria
against.

Ending sentences with a preposition is a bug.

=cut

sub thingone {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing1} = $arg;
  }

  return $self->{Thing1};
}

=item B<thingtwo>

Returns or sets the hash associated with the user defined header of
the object (frame or group or whatever) against which calibration
criteria are applied.

=cut

sub thingtwo {

  my $self = shift;

  # check that we have been passed a hash
  if (@_) {
    my $arg = shift;
    croak("Argument is not a hash") unless ref($arg) eq "HASH";
    $self->{Thing2} = $arg;
  }

  return $self->{Thing2};
}


=back

=head2 General Methods

=over 4

=item B<find_file>

Returns the full path and filename of the requested file (the first
file found in the search path).

  $filename = $Cal->find_file("fs_izjhklm.dat");

croaks if the file can not be found. It's likely that this is a bit
drastic but it will indicate something bad is going on before some
other unexpected behaviour occurs.  See
B<ORAC::Inst::Defn::orac_determine_calibration_search_path> for
information on setting up calibration directories.

=cut

sub find_file {
  my $self = shift;

  my $file = shift;
  croak "No file supplied to find_file() method"
    if ! defined $file;

  # Get the search path and also look in ORAC_DATA_OUT
  my @directories = ($ENV{ORAC_DATA_OUT},
                     orac_determine_calibration_search_path( $ENV{'ORAC_INSTRUMENT'} ));

  foreach my $directory (@directories) {
    if ( -e ( File::Spec->catdir( $directory, $file ) ) ) {
      return File::Spec->catdir( $directory, $file );
    }
  }

  croak "Could not find '$file' in dirs ".join(",",@directories)
    ." (possible programming error or your environment variables are incorrect)";

}

=item B<retrieve_by_column>

Returns the value for the specified column in the specified index.

  $value = $Cal->retrieve_by_column( "readnoise", "ORACTIME" );

The first argument is a queryable

=cut

sub retrieve_by_column {
  my $self = shift;
  my $index = shift;
  my $column = uc( shift );

  return if ! defined( $index );
  return if ! defined( $column );

  my $method = $index . "index";

  my $basefile = $self->$method->choosebydt('ORACTIME', $self->thing, 0 );
  croak "Unable to find suitable calibration data from $index"
    unless defined $basefile;

  my $ref = $self->$method->indexentry( $basefile );
  if ( exists( $ref->{$column} ) ) {
    return $ref->{$column};
  }
  return;
}

=back

=head1 DYNAMIC METHODS

These methods create methods for the standard calibration schemes for subclasses.
By default calibration "xxx" needs to create standard accessors for "xxxnoupdate",
"xxxname" and "xxxindex".

=over 4

=item B<GenericIndex>

Helper routine that creates an index object and returns it. Updates the
object based on the root name.

 $index = $Cal->CreateIndex( "flat", "dynamic" );

Where the first argument should match the root name of the index and rules
file. The second argument can have three modes:

  dynamic - index file is assumed to be in ORAC_DATA_OUT
  static  - index file is assumed to be in the calibration tree
  copy    - index file will be copied to ORAC_DATA_OUT from
            ORAC_DATA_CAL if not present in ORAC_DATA_OUT

If a third argument is supplied it is assumed to be an ORAC::Index
object to be stored in the calibration object.

=cut

sub GenericIndex {
  my $self = shift;
  my $root = shift;
  my $modestr = (shift || "dynamic");

  # The key for the internal object hash
  my $key = ucfirst($root) . "Index";

  # Store anything that we've been given
  if (@_) {
    $self->{$key} = shift;
  }

  # Now create one if required
  if (!defined $self->{$key}) {
    my $indexfile;
    my $idxroot = "index.$root";
    if ($modestr =~ /dynamic|copy/) {
      $indexfile = File::Spec->catfile( $ENV{ORAC_DATA_OUT}, $idxroot );
      if ( $modestr eq 'copy' && ! -e $indexfile ) {
        my $static = $self->find_file( $idxroot );
        croak "$root index file could not be located\n" unless defined $static;
        copy( $static, $indexfile );
      }

    } else {
      $indexfile = $self->find_file($idxroot);
      croak "$root index file could not be located\n" unless defined $indexfile;
    }
    my $rulesfile = $self->find_file("rules.$root");
    croak "$root rules file could not be located\n" unless defined $rulesfile;
    $self->{$key} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{$key};
}

=item B<GenericIndexAccessor>

Generic method for retrieving or setting the current value based on index
and verification. Uses ORACTIME to verify.

  $val = $Cal->GenericIndexAccessor( "sky", 0, 1, 0, 1, @_ );

First argument indicates the root name for methods to be called. ie "sky" would
call "skyname", "skynoupdate", and "skyindex".

Second argument controls whether the time comparison should be
nearest in time (0), or earlier in time (-1).

Third argument controls croaking behaviour. False indicates that the method
should croak if a suitable calibration can not be found. True indicates
that it should return undef. If a code ref is provided, it will be executed
if no suitable calibration is found. If it returns a defined value it
will be assumed to be a valid match, and if it returns undef the method
will croak as no suitable calibration will be available. This allows defaults
to be inserted.

Fourth argument controls whether calibration object verification is
not done.

Fifth argument controls whether warnings are displayed when searching
through the index file for a suitable calibration. Default is to warn.

  $val = $Cal->GenericIndexAccessor( "mask", 0, sub { return "bpm.sdf" }, @_ );

=cut

sub GenericIndexAccessor {
  my $self = shift;
  my $root = shift;
  my $timesearch = shift;
  my $nocroak = shift;
  my $noverify = shift;
  my $warn = shift;

  my $namemeth = $root ."name";
  my $indexmeth = $root ."index";
  my $noupmeth = $root . "noupdate";

  # if we are setting, accept the value and return
  return $self->$namemeth(shift) if @_;

  my $ok;
  if ( ! $noverify ) {
    $ok = $self->$indexmeth->verify($self->$namemeth,$self->thing,$warn);

    # happy ending - frame is ok
    return $self->$namemeth() if $ok;

    croak("Override $root is not suitable! Giving up") if $self->$noupmeth;
  } else {
    $ok = 1;
  }

  # not so good
  if (defined $ok) {
    # Choose time selection method
    my $choosemeth;
    if (!$timesearch) {
      $choosemeth = "choosebydt";
    } elsif ($timesearch == -1) {
      $choosemeth = "chooseby_negativedt";
    } else {
      croak "Unable to decide on time selection method with arg '$timesearch'";
    }

    my $match = $self->$indexmeth->$choosemeth('ORACTIME',$self->thing,$warn);

    # Error behaviour
    if (!defined $match) {
      if (ref($nocroak) eq 'CODE') {
        $match = $nocroak->();
        croak "No suitable $root found from default callback"
          unless defined $match;
        return $match;
      } elsif ($nocroak) {
        return undef;
      }
      croak "No suitable $root frame was found in index file";
    }
    $self->$namemeth($match);
  } else {
    croak("Error in $root frame calibration checking - giving up");
  }

}

=item B<GenericIndexEntryAccessor>

Like C<GenericIndexAccessor> except that a particular value from the index
is retrieved rather than a indexing key (filename).

No verification is performed.

  $val = $Cal->GenericIndexAccessor( "sky", "INDEX_COLUMN", @_ );

First argument indicates the root name for methods to be called. ie "sky" would
call "skycache", "skynoupdate", and "skyindex".

If a reference to an array or columns is given in argument 2, all values
are checked and the row reference is returned instead of a single value.

  $entryref = $Cal->GenericIndexAccessor( "sky", [qw/ col1 col2 /], @_ );

=cut

sub GenericIndexEntryAccessor {
  my $self = shift;
  my $root = shift;
  my $col  = shift;

  my $cachemeth = $root ."cache";
  my $indexmeth = $root ."index";
  my $noupmeth = $root . "noupdate";

  # Handle arguments
  return $self->$cachemeth(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined. This effectively allows the command-line
  # value to be used to override without verifying its suitability
  if ($self->$noupmeth) {
    my $cache = $self->$cachemeth;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $match = $self->$indexmeth->choosebydt('ORACTIME',$self->thing);
  croak "No suitable $root value found in index file"
    unless defined $match;

  # This gives us the filename, we now need to get the actual value
  # of the readnoise.
  my $rowref = $self->$indexmeth->indexentry( $match );
  if (ref($col) eq 'ARRAY') {
    for my $c (@$col) {
      next if exists $rowref->{$c};
      croak "Unable to find column $c for index file entry $match";
    }
    # Return entire row
    return $rowref;
  } else {
    if (exists $rowref->{$col}) {
      return $rowref->{$col};
    } else {
      croak "Unable to obtain $col from index file entry $match\n";
    }
  }
}

=item B<CreateBasicAccessors>

Dynamically create default accessors for "xxxnoupdate", "xxxname" and "xxxindex" methods.

 __PACKAGE__->CreateAccessors( "xxx", "yyy", "zzz" );

=cut

sub CreateBasicAccessors {
  my $caller = shift;
  my %methods = @_;

  my $header = "{\n package $caller;\n use strict;\n use warnings;\nuse Carp;\n";
  my $footer = "\n}\n1;\n";

  # noupdate
  my $noupdate = q{
sub PREFIXnoupdate {
  my $self = shift;
  if (@_) { $self->{PREFIXNoUpdate} = shift; }
  return $self->{PREFIXNoUpdate};
}
};

  # name
  my $name = q{
sub PREFIXname {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    HANDLEARRAY
    $self->{PREFIX} = $arg unless $self->PREFIXnoupdate;
  }
  return $self->{PREFIX};
}

# Allow "cache" to be a synonym
*PREFIXcache = *PREFIXname;
};

  # index
  my $index = q{
sub PREFIXindex {
  my $self = shift;
  return $self->GenericIndex( "PREFIX", INDEXMODE, @_ );
}
};

  # Array handling code for name/cache method
  my $array = q{
  my @values;
  if (ref($arg) eq 'ARRAY') {
    @values = @$arg;
  } else {
    @values = ($arg, @_);
  }
  $arg = \@values;
};

  # Now construct the methods using string eval
  for my $m (sort keys %methods) {
    my $string = $header;
    $string .= $noupdate;
    $string .= $name;
    $string .= $index;
    $string .= $footer;

    # Handle array processing
    if ($methods{$m}->{isarray}) {
      $string =~ s/HANDLEARRAY/$array/g;
    } else {
      $string =~ s/HANDLEARRAY//g;
    }

    # Handle index location
    my $imode;
    if ($methods{$m}->{staticindex}) {
      $imode = '"static"';
    } elsif ($methods{$m}->{copyindex}) {
      $imode = '"copy"';
    } else {
      $imode = '"dynamic"';
    }
    $string =~ s/INDEXMODE/$imode/g;

    # Replace prefix with requested name
    $string =~ s/PREFIX/$m/g;

    # run the code
    my $retval = eval $string;
    if (!$retval) {
      croak "Error running method creation code: $@\n Code: $string\n";
    }
  }
  return;
}

=back

=head1 SEE ALSO

L<ORAC::Group> and
L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
