package ORAC::Recipe::PrimitiveParser;

=head1 NAME

ORAC::Recipe::PrimitiveParser - Parse primitives

=head1 SYNOPSIS

  use ORAC::Recipe::PrimitiveParser;

  $parser = ORAC::Recipe::PrimitiveParser->new( Frame => $frm,
                                                Instrument => $inst );

  # Read primitive, parse, eval and return code ref
  # Returns ORAC::Recipe::Primitive
  $prim = ORAC::Recipe::PrimitiveParser->find( "_PRIM_" );
  $status = $prim->code()->( @arguments );

  # Return text required to embed call to primitive inside primitive
  $text = ORAC::Recipe::PrimitiveParser->embed( "_PRIM_" );

=head1 DESCRIPTION

Locate, parse and evaluate primitive code. Primitives are read at run
time and can make use of the Frame object for context switching when
choices are available.

Primitives are cached for performance reasons and are re-read if the
modification time of a primitive has changed.

=cut

use strict;
use warnings;
use Carp;

use Time::HiRes;
use Scalar::Util qw/ blessed /;

use ORAC::TempFile;
use ORAC::Constants qw/ :status /;
use ORAC::Print;
use ORAC::Recipe::Primitive;
use ORAC::Inst::Defn qw/ orac_determine_primitive_search_path orac_list_generic_observing_modes /;

our $VERSION = '1.0';

# Cached version of object. Most recently created object. Returned
# when the core methods are used as class methods from within recipes.

my $THIS;

# Cache is indexed by full path to primitive
# Values are ORAC::Recipe::Primitive objects
#     Code => reference to code ref for compiled primitive
#     ModTime => timestamp of last modification for primitive
#     Text => text form of primitive for debugging

my %PRIMCACHE;

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Insantiate a new object.

  $prim = ORAC::Recipe::Primitive->new( );

A C<ORAC::Frame> object and instrument name can be provided.

  $prim = ORAC::Recipe::Primitive->new( Frame => $frm, Instrument => $inst );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $parser = bless {
                      Frame => undef,
                      Instrument => undef,
                      Debug => 0,
                      DisableCompile => 0,
                     }, $class;

  my %args = @_;
  for my $key (keys %args) {
    my $method = lc( $key );
    $parser->$method( $args{$key} ) if $parser->can($method);
  }

  # store in cache
  $THIS = $parser;

  return $parser;
}

# Return either the blessed object that was supplied or the current
# cached version
sub _get_self {
  my $given = shift;
  return $given if ref($given);
  return $THIS;
}

=back

=head2 Accessors

=over 4

=item B<frame>

Return (or set) the C<ORAC::Frame> object to be associated with this
object. The frame object controls the primitive search path when there is
a choice of primitive.

  $prim->frame( $Frm );
  $Frm = $prim->frame;

=cut

sub frame {
  my $self = _get_self(shift);
  if (@_) {
    my $arg = shift;
    if (!defined $arg) {
      # will be okay - clears the frame
    } elsif (blessed($arg)) {
      # make sure it is the right type of object
      croak "Frame must be a ORAC::Frame object"
        unless $arg->isa( "ORAC::Frame" );
    } else {
      croak "Frame must be a ORAC::Frame object not unblessed scalar";
    }
    $self->{Frame} = $arg;
  }
  return $self->{Frame};
}

=item B<instrument>

Name of instrument to be used for this parse.

  $prim->instrument( $inst );

The instrument is used to retrieve the correct search path from
C<orac_determine_primitive_search_path>. See also C<ORAC::Inst::Defn>.

=cut

sub instrument {
  my $self = _get_self(shift);
  if (@_) {
    $self->{Instrument} = shift;
  }
  return $self->{Instrument};
}

=item B<instrument>

Flag to control whether debug output is embedded in the primitive
during parsing.

  $prim->debug( 1 );

=cut

sub debug {
  my $self = _get_self(shift);
  if (@_) {
    $self->{Debug} = shift;
  }
  return $self->{Debug};
}

=item B<nocompile>

If set, the compilation phase will not occur. This is useful for examining the
contents of a parsed recipe without worrying about syntax errors in the recipe.

Default is false.

=cut

sub nocompile {
  my $self = shift;
  if (@_) {
    $self->{DisableCompile} = shift;
  }
  return $self->{DisableCompile};
}

=back

=head2 General Methods

=item B<find>

Locate the supplied primitive, read it and return the
C<ORAC::Recipe::Primitive> object.

 $prim = $parser->find( "_PRIMITIVE_" );

If a path is included that primitive will be opened directly (rather
than using the search heuristics).

The directory search path can be overridden by passing in an optional
reference to an array of directories.

 $prim = $parser->find( "_PRIMITIVE_", \@directories );

This is useful for recipes where the search parameters differ.

If the "nocompile" object attribute is true the parsed primitive will not
be compiled.

=cut

sub find {
  my $self = _get_self(shift);
  my $prim_name = shift;
  my $dirs = shift;

  # read the file
  my $prim = $self->_read_primitive( $prim_name, (defined $dirs ? $dirs : () ) );
  
  # Parse it
  $self->_expand_primitive( $prim );

  # Compile it if necessary
  $self->_compile_primitive( $prim ) unless $self->nocompile;

  return $prim;
}

=item B<embed>

Return the execution code required to embed a particular primitive
inside a recipe or primitive.  Optionally takes a second argument
containing the primitive arguments as a single string.

  @lines = $parser->embed( "_MY_PRIMITIVE_", $arguments );
  $lines = $parser->embed( "_MY_PRIMITIVE_" );

The 3rd argument is a reference to  an array containing information similar to the caller() function.
If used, the array should contain

   Name of the primitive calling this primitive
   Line number from that primitive
   Number of times this primitive has been called already from the caller

  @lines = $prser->embed( "_MY_PRIMITIVE_", $arguments, \@caller );

Requires $_PRIM_DEPTH_ and $_PRIM_CALLERS to be in scope.

=cut

sub embed {
  my $self = _get_self(shift);
  my $primitive = shift;
  my $arguments = shift;
  my $caller = shift;
  return () unless defined $primitive;
  my $class = ref($self);

  my @lines;

  # Want to get the primitive object as a code ref
  # Then want to call it with the Frame, Group, Cal objects et al
  # and then the optional primitive arguments

  # Standard error checking
  push(@lines, "{"); # new scope for local variables
  push(@lines, "my \$_prim_object = $class" . "->find(\"$primitive\");");
  push(@lines, "ORAC::Error::FatalError->throw('Could not get primitive object \"$primitive\"') unless defined \$_prim_object;");
  push(@lines, "my \$_prim_code = \$_prim_object->code();");
  push(@lines, "ORAC::Error::FatalError->throw('Could not get compiled primitive \"$primitive\"') unless defined \$_prim_code;");

  # Convert the arguments to a hash form
  my $primargs = $self->_parse_prim_arguments( $arguments );

  # Store the call history in local array for retrieval by primitive
  push(@lines, "my \@_THIS_PRIM_CALLERS_ = @\$_PRIM_CALLERS_; push(\@_THIS_PRIM_CALLERS_,[".
       (defined $caller ? join(",", map { '"'. $_ .'"'} @$caller) : "" )
       ."]);");

  # Now run the routine
  push(@lines, "my \$_prim_exit_status = \$_prim_code->(\$_PRIM_DEPTH_,\\\@_THIS_PRIM_CALLERS_,\$Frm,\$Grp,\$Cal,\$Display,\$Mon,\$ORAC_Recipe_Info,$primargs);");
  push(@lines,"return \$_prim_exit_status if \$_prim_exit_status != ORAC__OK;");
  push(@lines, "orac_loginfo( 'Primitive Arguments' => \$_PRIM_ARGS_STRING_ );"); # Reset loginfo on exit
  push(@lines, "}"); # close scope

  if (wantarray) {
    return @lines;
  } else {
    return join("\n",@lines);
  }

}

=begin __PRIVATE__

=head2 Internal Methods

=over 4

=item B<_store_prim_params>

This class method is used during recipe execution to store primitive-specific
parameters that can be retrieved later in the recipes.

Is not reliable outside the context of the recipe execution environment and should
not be called by external routines.

  $parser->_store_prim_params( $prim_name, \%arguments );

=cut

my %_PRIMITIVE_PARAMETERS;
sub _store_prim_params {
  my $class = shift;
  my $primitive = shift;
  my $params = shift;

  $_PRIMITIVE_PARAMETERS{$primitive} = $params;
  return;
}

=item B<_find_prim_params>

Retrieve parameters associated with the specified primitive.

  $hashref = $parser->_find_prim_params( $primitive_name );
  %hash = $parser->_find_prim_params( $primitive_name );

Throws exception if the primitive has not previously been registered.

Optional second argument can be used to indicate the calling primitive
and line number to aid in error message reporting.

  $hashref = $parser->_find_prim_params( $primitive_name, $caller, $cal_line );

=cut

sub _find_prim_params {
  my $self = shift;
  my $primname = shift;
  my $caller = shift;
  my $lineno = shift;
  if (exists $_PRIMITIVE_PARAMETERS{$primname} ) {
    if (wantarray) {
      return %{$_PRIMITIVE_PARAMETERS{$primname}};
    } else {
      return $_PRIMITIVE_PARAMETERS{$primname};
    }
  }

  my $errmsg = "Requested primitive ('$primname') has not stored any parameters yet.";
  if (defined $caller) {
    $errmsg .= " Called from primitive '$caller'";
    $errmsg .= " line $lineno" if defined $lineno;
  }
  $errmsg .= "\n";

  throw ORAC::Error::FatalError( $errmsg );
}

=item B<_clear_prim_params>

Remove all cached parameters. This is called at the start of a recipe to reset
state.

  $parser->_clear_prim_params;

=cut

sub _clear_prim_params {
  %_PRIMITIVE_PARAMETERS = ();
}

=item B<_read_primitive>

Reads the specified primitive from the recipe directory.  An
C<ORAC::Recipe::Primitive> object containing the primitive is
returned. The parser object is not updated.

  $primitive = $parser->_read_primitive( $primitive_name );

The location of the recipe is determined first by seeing whether a
path has been specified, then looking in the directory specified with
C<ORAC_PRIMITIVE_DIR> and then the ORAC repository directories
specified from C<ORAC::Inst::Defn>. The last requires an instrument
is available.

The C<ORAC_PRIMITIVE_DIR> environment variable is similar to a normal
C<PATH> variable in that multiple directories can be supplied if
separated by colons.

If multiple matches are found and a Frame object is present, the Frame
object will be queried to determine the correct primitive to choose.
If no Frame object is registered and there is an ambiguity, the routine
will throw an exception.

If the primitive can not be found an exception is thrown.

The search directories can be overridden by passing in a reference to an
array of directories. This is useful for searching non-standard locations
or searching for top level recipes.

 $recipe = $parser->_read_primitive( $recipe_name, \@dirs );

Directories are ignored if the primitive name includes a full path.
It is an error if search directories are provided and the primitive
can not be found.

=cut

sub _read_primitive {
  my $self = shift;
  my $name = shift;
  my $dirs = shift;

  # List of files that should be read
  my @found;

  # See whether we have been given a path
  my ($vol, $dir, $file) = File::Spec->splitpath( $name );
  if ($dir || $vol) {
    # we have to read this file
    @found = ($name);

    if (!-e $name) {
      throw ORAC::Error::FatalError("Path given to '$name' but that file does not exist", ORAC__FATAL);
    }

  } else {

    # list of dirs for error report
    my @searched; 

    # search in override path
    if (defined $dirs) {
      @found = $self->_search_path( $dirs, $name );
      if (!@found) {
        my $str = join("\n",@$dirs);
        throw ORAC::Error::FatalError("Could not find and/or open '$name' in any of:\n$str\n",
                                      ORAC__FATAL);
      }
    }

    # if we can find the primitive in ORAC_PRIMITVE_DIR that must trump all other options
    # and we should not require the instrument
    if (!@found && exists $ENV{ORAC_PRIMITIVE_DIR}) {
      # create a search path
      my @path = $self->_split_path_env_var($ENV{ORAC_PRIMITIVE_DIR});

      # look for the primitive
      @found = $self->_search_path( \@path, $name);
      @searched = @path;
    }

    if (!@found) {
      # if we did not find it in ORAC_PRIMITIVE_DIR we now need to know the instrument
      my $instrument = $self->instrument;

      # Check that it is defined
      throw ORAC::Error::FatalError( "_read_primitive: Instrument not defined.",
                                     ORAC__FATAL) unless defined $instrument;

      # Create the search path using instrument
      my @path = orac_determine_primitive_search_path( $instrument );
      # If the path array is empty add cwd (should not happen in oracdr)
      @path = ( File::Spec->curdir ) unless @path;

      # Now search the directory structure for primitive name
      @found = $self->_search_path( \@path, $name);

      unless (@found) {
        push(@searched, @path);
        my $str = join("\n", @searched);
        throw ORAC::Error::FatalError( "Could not find primitive named $name in any of:\n\n$str\n", ORAC__FATAL);
      }
    }
  }

  return $self->_retrieve_relevant_file( @found );
}

=item B<_retrieve_relevant_file>

Given a set of files (with full path), return the
C<ORAC::Recipe::Primitive> object for the most relevant
file. Ambiguities are resolved by using the Frame object.

  $prim = $recipe->_retrieve_relevant_file( @files );

=cut

sub _retrieve_relevant_file {
  my $self = shift;
  my @found = @_;

  # We now have an array of all possible primitives/recipes that match
  # this name. If we only have one match we can read it without
  # further ado or confusion. If we don't have any we can raise an exception

  my $foundpath;

  if (@found) {

    if ($#found == 0) {

      $foundpath = $found[0]

    } else {
      # If we have primitives/recipes in multiple places we have to decide
      # whether we want them. We only want one primitive/recipe from each
      # type of observation mode. If there is a primitive/recipe that is
      # entirely instrument related (no observing mode) we need to
      # select that one and only that one regardless of its position.

      # remove general if we have any other option
      @found = grep { $_ !~ /general/ } @found if @found > 1;

      # instrument directories are upper case. Mode directories are
      # lower case.

      my %best;
      my @modes = orac_list_generic_observing_modes();
      for my $path (@found) {

        # Determine mode.
        my $thismode;
        for my $mode (@modes) {
          # Check for match over word boundary
          if ($path =~ /\b$mode\b/) {
            $thismode = $mode;
            last;
          }
        }
	
        # if it did not match a generic mode it must be a
        # specific observation - call it INST
        $thismode = "INST" unless defined $thismode;

        # If it is a specific instrument in a generic directory
        # we will only choose it if it is first in the search path
        # Store path in hash associated with mode (or INST)
        # unless we have already done so (since we are going through
        # the paths in priority order)
        $best{$thismode} = $path unless exists $best{$thismode};

      }

      # Get final list of keys
      my @keys = keys %best;

      # We now have a hash of possible choices. If the INST key was
      # set we use it without any messing about
      if (exists $best{INST}) {
        $foundpath = $best{INST};
      } elsif ($#keys == 0) {
        # We only have one choice remaining so should not be
        # switching
        $foundpath = $best{$keys[0]};
      } else {
        # Else we have a choice of observing modes
        # Need to query the frame
        my $Frm = $self->frame();
        throw ORAC::Error::FatalError("Have a choice of primitive but no frame object registered")
          if !defined $Frm;

        # get the observation mode
        my $obsmode = $Frm->uhdr("ORAC_OBSERVATION_MODE");
        throw ORAC::Error::FatalError("There were ambiguities in file selection but ORAC_OBSERVATION_MODE header was not set")
          unless defined $obsmode;

        if (exists $best{$obsmode}) {
          $foundpath = $best{$obsmode};
        } else {
          throw ORAC::Error::FatalError("There were ambiguities in file selection that could not be resolved by an observation mode of '$obsmode'");
        }

      }

    }

  }

  if (defined $foundpath) {
    # Read modification time of path - we need it regardless of whether we read from the cache or not
    my @stat = stat( $foundpath );
    my $mtime = $stat[9];

    # First look up in cache
    if (exists $PRIMCACHE{$foundpath}) {
      # look at modification date
      if ($mtime == $PRIMCACHE{$foundpath}->mtime ) {
        # same file
        return $PRIMCACHE{$foundpath};
      }
    }
    
    # Cache either empty or invalid so we must read the file
    my $contents = $self->_slurp_file($foundpath);
    $PRIMCACHE{$foundpath} = ORAC::Recipe::Primitive->new( original => $contents,
                                                           path => $foundpath,
                                                           mtime => $mtime );
    return $PRIMCACHE{$foundpath};
  }

  # if we have got here then we have nothing
  my $str = join(",",@found);
  throw ORAC::Error::FatalError("Could not find a primitive to read from list: $str");
}

=item B<_search_path>

Search for file in search path. Return an array of all the files
which match the name in the order in which they are located. In 
scalar context return the first name.

  $first = $parser->_search_path( \@path, $name );
  @found = $parser->_search_path( \@path, $name );

Returns an empty list or undef on error depending on context.

The search path is specified as a reference to an array of directories.

A class method.

=cut

sub _search_path {
  my $self = shift;

  my @found;
  for my $dir ( @{ $_[0] } ) {
    my $file = File::Spec->catfile($dir, $_[1]);
    if (-e $file) {
      push(@found, $file);
      return $file unless wantarray();
    }
  }
  # this is correct in scalar and array context since we have
  # already returned the first one we found if we are in a scalar
  # context
  return @found;
}

=item B<_slurp_file>

Open file, read all lines, close it.

  $linesref = $parser->_slurp_file($path);

Returns an array reference.

A class method.

=cut

sub _slurp_file {
  my $self = shift;
  my $file = shift;
  my $fh = new IO::File("< $file");
  my @contents;
  @contents = <$fh> if defined $fh;
  return \@contents;
}

=item B<_split_path_env_var>

Split a standard PATH-type string (ie colon separated directories)
into a perl array.

  @path = $parser->_split_path_env_var( $ENV{PATH} );

No attempt is made (yet) to check that the directories in the path
are valid.

A class method.

=cut

sub _split_path_env_var {
  my $self = shift;
  return split(/:/, $_[0]);
}

=item B<_expand_primitive>

Given a ORAC::Recipe::Primitive object adding in the required
code to turn it into a subroutine (if it has not already been processed).

 $parser->_expand_primitive( $prim );

=cut

sub _expand_primitive {
  my $self = shift;
  my $prim = shift;
  return if defined $prim->code;

  # sometimes we need the class
  my $class = ref($self);

  # we have to go through the primitive adding code to handle error checking and
  # code for calling embedded child primitives
  my @children;

  # first thing we have to do is add a subroutine wrapper to the whole thing
  # and infrastructure for 
  my @parsed;
  push(@parsed, "#line 1 ".$prim->name() ."_header");
  push(@parsed, "package ORAC::Recipe::Execution;");
  push(@parsed, "use strict; use warnings;");
  push( @parsed, "sub {\n" );

  # Read primitive depth first
  push(@parsed, "my \$_PRIM_DEPTH_ = shift;");

  # and the call tree
  push(@parsed, "my \$_PRIM_CALLERS_ = shift;");

  # increment recursion depth by one
  push(@parsed, "\$_PRIM_DEPTH_++;");
  push(@parsed,"die \"Primitive depth very high (\$_PRIM_DEPTH_). Possible recursive primitive\" if \$_PRIM_DEPTH_ > 10;");

  # Update the CURRENT_PRIMITIVE
  push(@parsed, "ORAC::Recipe::Execution->current_primitive( \"".$prim->name.
       "\", \$_PRIM_CALLERS_);");

  # read subroutine args
  for my $ARG (qw/ $Frm $Grp $Cal $Display $Mon $ORAC_Recipe_Info / ) {
    push(@parsed, "my $ARG = shift;");
  }

  # Sort out precanned variables
  push(@parsed, "my \$ORAC_PRIMITIVE = \"".$prim->name."\";");
  push(@parsed, "my \$DEBUG = ". 
       ($self->debug ? 1 : 0) .";"); # burn in debug status
  push(@parsed, "my %". $prim->name ." = \@_;");
  push(@parsed, "my \$_PRIM_ARGS_ = \\%". $prim->name.";");
  push(@parsed, "my \$_PRIM_ARGS_STRING_ = ORAC::General::convert_args_to_string( \%\$_PRIM_ARGS_ );");
  push(@parsed, "orac_loginfo( 'Primitive Arguments' => \$_PRIM_ARGS_STRING_ );");
  push(@parsed, "my \$_PRIM_EPOCH_ = &Time::HiRes::gettimeofday();");
  push(@parsed, "orac_logkey(\"".$prim->name."\");");

  # Promote the recipe parameters to a recipe global variable
  push(@parsed, "my \%RECPARS = %{\$ORAC_Recipe_Info->{Parameters}};");

  # convert $Mon to a tied hash since for historical reasons we have to use %Mon{} not $Mon->{}
  push(@parsed, "my \%Mon;");
  push(@parsed, "  if (tied \%\$Mon) {",
       "my \$obj = tied \%\$Mon;",
       "tie \%Mon, ref(\$obj), \$obj; # re-tie",
       "} else {",
       "\%Mon = \%\$Mon;",
       "}");

  # Loop over each line in the primitive

  # Keep track of whether we are in pod or not
  my $inpod = 0;

  # Hash to keep track of external primitives that have been requested
  my %inserted_primargs;

  # Need to find out if a primitive argument hash is being referenced. We can not
  # embed this code directly in the primitive because in some cases the hash lookup
  # occurs in a multi-line expression. Therefore do an initial pass that simply
  # looks for primitives hashes

  for my $line ($prim->original) {
    # do not want to look in pods
    if ($line =~ /^=cut\z/) {
      $inpod = 0;
    } elsif ($line =~ /^=/) {
      $inpod = 1;
    }
    next if $inpod;
    # Check for call to another primitive argument hash
    # Make sure we handle commented code
    # Match multiple times and store the result.  This deals with a line
    # that refers to two primitives (presumably including the current one)
    my $clean = $line;
    $clean =~ s/\#.*//;
    while ($clean =~ /(_\w+_){/g) {
      my $arg_prim = $1;
      next if $arg_prim eq $prim->name;
      $inserted_primargs{$arg_prim}++;
    }
  }
  # now insert the code to enable each lookup
  # note that we change the values in the hash to correspond to 
  # line numbers in @parsed so that they can be located easily
  # later on.
  my %declared_primargs;
  for my $extprim (keys %inserted_primargs) {
    # print "Looking for args from $extprim inside ".$prim->name."\n";
    push(@parsed, "my \%$extprim = $class". "->_find_prim_params(\"$extprim\",\"".$prim->name."\");");
    $inserted_primargs{$extprim} = $#parsed;
    $declared_primargs{$extprim} = "my \%$extprim;";
  }

  if ($self->debug) {
    push( @parsed, 'orac_print(">>Entering '.$prim->name().'\n","green");');
    push( @parsed, "my \$_primitive_start_time = [Time::HiRes::gettimeofday];" );
  }

  # somewhere to keep primitive arguments that have been moved
  my %previous_primargs;

  # Keep track of how many times a particular primitive has been embedded
  my %embed_count;

  # first line of the primitive proper
  push( @parsed, "#line 1 " . $prim->name() );

  # Keep track of line number so that error messages report line in original primitive
  $inpod = 0;
  my $lineno = 0;
  for my $line ($prim->original) {
    $lineno++;

    # check to see if this is a pod directive
    # special case =cut
    if ($line =~ /^=cut\z/) {
      $inpod = 0;
    } elsif ($line =~ /^=/) {
      $inpod = 1;
    }

    # if we are still in pod we can just store the line and skip. Once
    # the parser is working properly it may be better to simply skip
    # pod lines since users won't see the comments and they won't need
    # to so long as we keep track of primitive line number
    if ($inpod) {
      push(@parsed, $line);
      next;
    }

    # Check for primitive insert directives
    if ($line =~ /^\s*_/ ) {
      $line =~ s/^\s+//;	# zap leading blanks
      $line =~ s/\s*$//;        # Zap trailing blanks
      my ($primitive_name, $rest) = split(/\s+/,$line,2);
      $rest = '' unless defined $rest; # -w protection for next line

      $embed_count{$primitive_name}++;
      push(@parsed, "#line 1 ".$prim->name() . "_calling$primitive_name");
      push(@parsed, $self->embed($primitive_name, $rest,
                                 [$prim->name(), $lineno, $embed_count{$primitive_name} ]) );
      push(@children, $primitive_name);

      # If it turns out we need this primitive results immediately
      # we remove the previous line that was handling the args and
      # add it here. 
      if (exists $inserted_primargs{$primitive_name}) {
        my $earlier;
        if (exists $previous_primargs{$primitive_name}) {
          $earlier = $previous_primargs{$primitive_name};
        } else {
          my $prevpos = $inserted_primargs{$primitive_name};
          $earlier = $parsed[$prevpos];

          # remove the lexical declaration (bit of a hack)
          # we need to expand scope to primitive since we do not know if multiple
          # primitive calls to the same primitive will result in declaration in the same scope
          $earlier =~ s/^\s*my\s*//;

          # replace previous entry with a declaration only
          $parsed[$prevpos] = $declared_primargs{$primitive_name};

          # there is a chance that this primitive will be called multiple times
          # so we need to store the line for later
          $previous_primargs{$primitive_name} = $earlier;
        }
        push(@parsed, $earlier);
      }

      # Reset line count
      push(@parsed, "#line ".($lineno+1) ." ". $prim->name() );

    } elsif ($line =~ /->obeyw(.*)/) {
      # an obeyw
      my $arguments = $1;

      $arguments =~ s/\"/ /g;

      # Try to extract a meaningful monolith name
      my $remote = '';
      if ($line =~ /Mon{(.*)}->/) {
        $remote = $1;
        # strip none word characters
        $remote =~ s/\W//g;
      }

      # Add the following debug line if the obeyw is not commented out
      # and debugging is enabled.
      my $debug_obey = 0;
      if ($self->debug && $line !~ /\#.+->obeyw/) {
        push(@parsed,
             '{ my $__PREFIX = "?";'."\n",
             '  if( $Frm->can( "number" ) ) { $__PREFIX = $Frm->number; } elsif( $Frm->can( "name" ) ) { $__PREFIX = $Frm->name; };' . "\n",
             '  orac_debug( $__PREFIX . ":"."'.$prim->name .'".'."\":($remote)\t$arguments\n\"); }\n");
        my ($monolith, $task, $args) = $self->_parse_obey_line( $line );
        $monolith = "<Unknown Monolith>" unless defined $monolith;
        push(@parsed,'orac_print("++ Calling '.$task .' in '. $monolith.' ","green");');
        $debug_obey = 1;
      }

      # Now check to see whether it starts with a comment character
      # (Note that the xemacs syntax recognition does not understand #
      # in a pattern match)
      # or if somebody has put an equals sign in and is checking it
      # themselves.
      if ($line !~ /(\#|=).+?->obeyw/x) {

        my (undef, $rtask, $rargs ) = $self->_parse_obey_line( $line );
        # Now add the OBEYW status checking lines
        # prepending the OBEYW_STATUS line
        # Put it in a block of its own to prevent warnings
        # relating to the masking of $OBEYW_STATUS in a earlier
        # declaration in same scope
        push (@parsed,
              "#line 1 ".$prim->name()."_calling_$remote",
              "{  # Create block to prevent warnings from my OBEYW_STATUS",
              "orac_loginfo( 'Primitive Arguments' => undef);",  # clear arguments
              "orac_loginfo( 'Engine Arguments' => \"$rargs\");",
              "orac_logkey( \"".$prim->name."->"."\".uc(\"$rtask\") );",
              ($debug_obey ? "my \$_obey_start_time = [Time::HiRes::gettimeofday];" : ""),
              "#line $lineno ". $prim->name,
              'my $OBEYW_STATUS = ' .$line,
              "#line 3 ".$prim->name()."_calling_$remote",
              "orac_loginfo( 'Engine Arguments' => undef );",
              "orac_loginfo( 'Primitive Arguments' => \$_PRIM_ARGS_STRING_ );", # put back arguments
              "orac_logkey( \"". $prim->name ."\");",
             );

        # If debugging add a statement before the status is checked
        # so that we can store the status value in the file
        push(@parsed,
             'orac_print("took ".sprintf("%.3f",Time::HiRes::tv_interval($_obey_start_time))." seconds\n","green");',
             'orac_debug( "Returned with status = ". $OBEYW_STATUS . "\n");'."\n",
            ) if $debug_obey;

        # Now complete the obey error checking
        push(@parsed,
             $self->_check_obey_status_string($line),
             "\n}\n"
            );

        # the line number now needs to be reset to one greater than the current
        # line
        push(@parsed, "#line ".($lineno+1)." ". $prim->name() );

      } else {
        # Just push the line on as is

        # reset line number
        push(@parsed, "#line $lineno ". $prim->name() );
        push (@parsed, $line);

        # Add simple return notification
        push(@parsed,
             'orac_debug( "Returned from obey. Status intercepted\n");'."\n"
            ) if $debug_obey;

      }

    } elsif ($line =~ /\$ORAC_STATUS/ && $line =~ /=/) {
      # Check that it has ORAC_STATUS and that the line has an
      # assignment (should check that the ORAC_STATUS is to the left of the
      # = and that ORAC_STATUS is to the left of a #)
      # Put on the current line
      push (@parsed, $line);

      # Add the status checking code
      # unless there is a comment before the ORAC_STATUS
      push (@parsed, 
            "#line 1 ". $prim->name() ."_checking_status",
            $self->_check_status_string)
        unless $line =~ /\#.+?\$ORAC_STATUS/;

      # line number should now be one more than it was
      push(@parsed, "#line ".($lineno+1)." ". $prim->name() );


    } else {
      push(@parsed,$line);
    }

  }

  push(@parsed, "#line 1 ".$prim->name()."_footer");

  # Add the timing information
  if ($self->debug) {
    push(@parsed, 'my $_primitive_elapsed_time = Time::HiRes::tv_interval($_primitive_start_time);');
    push(@parsed, 'my $_p_execute_elapsed = sprintf("%.3f", $_primitive_elapsed_time);');
    push(@parsed, 'orac_print("<< '.$prim->name. ' took $_p_execute_elapsed seconds to run\n","green");');
  }

  # At the end of the primitive file the primitive arguments hash and close the sub
  push(@parsed, $class . "->_store_prim_params(\"".$prim->name."\", \\%".$prim->name.");");
  push(@parsed, " return ORAC__OK;");
  push(@parsed, "}","# End primitive". $prim->name,"");


  # Store the parsed/expanded version of primitive
  chomp(@parsed); # remove new lines characters
  $prim->content( @parsed );

  # Store the children
  $prim->children( @children );

  return;
}

=item B<_compile_primitive>

Compile the expanded and parsed primitive. The result is stored in the 
C<code> accessor of the Primitive object.

  $parser->_compile_primitive( $prim );

=cut

sub _compile_primitive {
  my $self = shift;
  my $prim = shift;

  # Trigger parse if necessary
  $self->_expand_primitive( $prim ) if !$prim->content;

  my @parsed = $prim->content;

  # and compile the code
  my $program = join("\n", @parsed);
#  print $program;

  local $@;
  my $sub = eval "$program";
  if (ref($sub) && ref($sub) eq 'CODE') {
    # successful compile
    $prim->code( $sub );
  } else {
    throw ORAC::Error::FatalError("Error compiling primitive ".$prim->name.": $@");
  }

}

=item B<_check_status_string>

Provides the code for automatic status checking of recipes.

  $string = $parser->_check_status_string;

=cut

sub _check_status_string {

  my @newlines =  (' if ($ORAC_STATUS != ORAC__OK) {' ,
		   '   orac_err ("Error in pipeline\n"); ' ,
		   '   return $ORAC_STATUS; ' ,
		   ' } ');

  # Add newlines to each line of the text so that it appears
  # correctly when recipe is listed
  for (@newlines) { $_ .= "\n" }

  # Return the extra lines.
  return @newlines;

}

=item B<_check_obey_status_string>

Provides the code for automatic status checking of obeyw()
in recipes.

  $string = $parser->_check_obey_status_string( $obey_line );

Checks also for the special case of ORAC__BADENG as the 
return value. In that case, the monolith is removed from
the message system so that next time it is required
a new one is launched.

=cut

sub _check_obey_status_string {
  my $self = shift;

  # Get the name of the monlith from the obeyw
  my $line = shift;
  my ($monolith, $task, $args) = $self->_parse_obey_line($line);

  # Need to be careful of what gets expanded when the
  # lines are added to the recipe and what gets expanded
  # when the recipe is executed.

  my $montext = (defined $monolith ? $monolith : "(None)");
  my @statuslines = (
		     'if ($OBEYW_STATUS != ORAC__OK) {',
		     "  orac_err (\"Error in obeyw to monolith $montext (task=$task): \$OBEYW_STATUS\\n\");" ,
		     '  my $obeyw_args = "'. $args . '";',
		     '  orac_print("Arguments were: ","blue");',
                     '  orac_print("$obeyw_args\n\n","red"); '
		    );

  # If we have been unable to determine the monolith name we can not
  # add the following - could use splice rather than two pushes
  if (defined $monolith) {
    push (@statuslines,
	  '  if ($OBEYW_STATUS == ORAC__BADENG) {',
	  "    orac_err(\"Monolith $monolith seems to be dead. Removing it...\\n\");",
	  "    delete \$Mon{$monolith};",
	  '  }'
	 );
  }

  # finish 
  push (@statuslines,
	'  return $OBEYW_STATUS;',
	'}'
       );

  # Add newlines to each line of the text so that it appears
  # correctly when recipe is listed
  for (@statuslines) { $_ .= "\n" }

  # Return the extra lines.
  return @statuslines;

}

=item B<_parse_obey_line>

Split the line containing the obeyw into the Monolith name,
the task name and the argument string.

 ($mon, $task, $args) = $parser->_parse_obey_line( $line );

=cut

sub _parse_obey_line {
  my $self = shift;
  my $line = shift;

  my ($monolith, $task, $args);
  # Do the regexp separately so that we can handle the situation
  # where the monolith path is not stored in a hash
  $line =~ /\{\s*[\'\"]*(\w+)[\'\"]*\s*\}->obeyw/ && ($monolith = $1);
  $line =~ /->obeyw\(\s*\"(\w+)\"/ && ($task = $1);
  $line =~ /->obeyw\(\s*\"\w+\"\s*,\s*\"(.+)\"/ && ($args = $1);
  $args = '(No arguments)' unless defined $args;
  $task = '(Unknown)' unless defined $task;

  return ($monolith, $task, $args);
}

=item B<_parse_prim_arguments>

Parses argument lists on primitive calls.
Converts a string of form 'arg1=value1 arg2=value2...'
to a hash constructor string of the form

   a => "b", c => $d, e => "f"

ie Arguments are parsed at compile time. The returned
string should be wrapped in either () or {}.

  @text = $parser->_parse_prim_arguments( $primargs );

=cut

sub _parse_prim_arguments {
  my $self = shift;
  my $class = ref($self);
  my $line = shift;
  return "" unless defined $line;

  my $wantarray = wantarray;

  $line =~ s/^\s+//;
  $line =~ s/\s+$//;

  # Split the string on space
  my @arguments = split(/\s+/,$line);

  # Loop over each string
  my @kv;
  foreach my $argument (@arguments) {
    # Split each argument on equals
    if( $argument =~ /=/ ) {
      my ($key,$value) = split("=",$argument,2);
      if (defined $value) {
        if( $value =~ /^\$/ ||
            $value =~ /^\\%/ ||
            $value =~ /^\\@/ ) {
          if( $wantarray ) {
            throw ORAC::Error::FatalError( "Cannot pass Perl variables into primitives when called in list context", ORAC__FATAL );
          } else {
            push(@kv, " $key => $value");
          }
        } else {
          if( $wantarray ) {
            push( @kv, $key, $value );
          } else {
            push( @kv, " $key => \"$value\"");
          }
        }
      } else {
        if( $wantarray ) {
          push( @kv, $key, undef );
        } else {
          push(@kv, " $key => undef");
        }
      }
    } else {
      if( $wantarray ) {
        throw ORAC::Error::FatalError( "Cannot pass solitary Perl variables into primitives when called in list context", ORAC__FATAL );
      } else {
        push( @kv, " $class->_parse_prim_arguments($argument)" );
      }
    }
  }

  if( $wantarray ) {
    return @kv;
  } else {
    return join( ", ", @kv);
  }
}


=back

=end __PRIVATE__

=head1 NOTES

Tracking of "Current" primitive relies on ORAC::Recipe->current_primitive().

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Recipe>, L<ORAC::Recipe::Primitive>

=head1 REVISION

$Id: BaseFile.pm 7256 2007-11-28 02:39:22Z timj $

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


