package ORAC::Recipe;

=head1 NAME

ORAC::Recipe - Recipe parsing and execution

=head1 SYNOPSIS

  use ORAC::Recipe;

  $r = new ORAC::Recipe( $recipe, $instrument );

  $r->instrument( $instrument );
  $r->read_recipe(RECIPE => $recipe,
                  INSTRUMENT => $instrument);
  $r->execute( \$CURRENT_PRIMITIVE, \$PRIMITIVE_LIST,
               $Frm, $Grp, $Cal, $Display, \%Mon);

=head1 DESCRIPTION

Class for reading and executing ORAC-DR recipes.
In general the methods should be called in the order
shown in the SYNOPSIS.

=cut

use strict;
use 5.006;
use vars qw/ $VERSION /;
use warnings;
use Carp;
use File::Spec;                 # For pedants everywhere
use IO::File;                   # until perl5.6 is guaranteed
use Text::Balanced qw/ extract_bracketed /;
use Time::HiRes qw( gettimeofday tv_interval );

# use Data::Dumper; # for debugging

use ORAC::Recipe::PrimitiveParser;
use ORAC::Constants qw/ :status /;
use ORAC::Print;
use ORAC::Basic;
use ORAC::Error qw/ :try /;
use ORAC::Inst::Defn qw/ orac_determine_recipe_search_path /;

$VERSION = '1.0';

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

The constructor instantiates a new object and, if the recipe name and
instrument are given, reads the recipe from disk.

  $r = new ORAC::Recipe;
  $r = new ORAC::Recipe( NAME => $name,
                         INSTRUMENT => $instrument );

The instrument name is required in order to configure the recipe
search path.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Init the data structure
  my $rec = bless {
                   BATCH => 0,
                   PrimitiveParser => undef,
                   RecipeName => undef,
                   Recipe => undef,
                   RecSuffices => [],
                   RecParams => {},
                  }, $class;

  # Check for arguments
  my %args = @_;
  for my $key (keys %args) {
    my $method = lc( $key );
    $rec->$method( $args{$key} ) if $rec->can($method);
  }

  # if we have a name, frame and instrument we can proceed
  if (defined $rec->name && defined $rec->instrument && defined $rec->frame) {
    try {
      $rec->_read_recipe;
    } catch ORAC::Error::FatalError with {
      my $Error = shift;
      $Error->throw;
    } otherwise {
      my $Error = shift;
      throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
    };
  }

  return $rec;
}

=back

=head2 Accessor Methods

=over 4

=item B<parser>

Recipe and primitive parser object used to do the real low level parsing.
Automatically instantiated on demand.

  $parser = $rec->parser();

Will be a C<ORAC::Recipe::PrimitiveParser>.

=cut

sub parser {
  my $self = shift;
  $self->{PrimitiveParser} = ORAC::Recipe::PrimitiveParser->new()
    unless defined $self->{PrimitiveParser};
  return $self->{PrimitiveParser};
}

=item B<recipe>

The actual recipe. Actually will be an C<ORAC::Recipe::Primitive>
object (since at the code level there is no difference).

 $data = $rec->recipe;

=cut

sub recipe {
  my $self = shift;
  if (@_) {
    my $recipe = shift;
    if (defined $recipe) {
      throw ORAC::Error::FatalError("Must be an ORAC::Recipe::Primitive object")
        unless $recipe->isa("ORAC::Recipe::Primitive");
    }
    $self->{Recipe} = $recipe;
  }
  return $self->{Recipe};
}

=item B<name>

Recipe name. Will trigger a read of the recipe if an instrument is
available. If a compiled recipe is available the method will be delegated
to that object.

  $name = $rec->name;
  $rec->name( $name );

=cut

sub name {
  my $self = shift;
  if (@_) {
    # we are setting a name
    $self->{RecipeName} = shift;

    # if we have a parsed recipe which indicates a different name
    # clear it
    my $compiled = $self->recipe;
    if (defined $compiled && $compiled->name ne $self->{RecipeName}) {
      $compiled = undef;
      $self->recipe(undef);
    }

    # reread if we do not have one stored and we know we have all the information
    # we can get (be pessimistic otherwise)
    if (!defined $compiled && defined $self->instrument && defined $self->frame) {
      $self->_read_recipe();
    }
  }

  # if we have a compiled recipe ask that
  if (defined $self->recipe) {
    return $self->recipe->name;
  } else {
    return $self->{RecipeName};
  }
}

=item B<suffices>

Suffices that can be appended to recipe name when scanning for recipes. The recipe containing
a suffix is used in preference to a recipe without the suffix. The suffices are stored in
priority order.

  @suffices = $rec->suffices;
  $rec->suffices( @suffices );

Note that suffices do not need to start with an underscore and one will be added if required.
All recipes will be STUB_SUFFIX form.

=cut

sub suffices {
  my $self = shift;
  if (@_) {
    # prepend underscore if needed so that we only do it once rather than each time we look
    # for a recipe
    @{$self->{RecSuffices}} = map { $_ = "_$_" unless /^_/; $_} @_;
  }
  return @{$self->{RecSuffices}};
}

=item B<parameters>

General ORAC::Recipe::Parameters object, not parameters necesarily
associated with this recipe.

  $par = $rec->parameters

=cut

# Store the full object here in case we would wish to add
# primitive parameters that could be injected by the parser

sub parameters {
  my $self = shift;
  if (@_) {
    $self->{RecParams} = shift;
  }
  return $self->{RecParams};
}

=item B<batch>

Set or return the batch processing status. If batch is set to true
the recipe will process groups that have been pre-populated with
unprocessed frames..

  $batch = $rec->batch;

=cut

sub batch {
  my $self = shift;
  if (@_) {
    $self->{BATCH} = shift;
  }
  ;
  return $self->{BATCH};
}

=item B<debug>

Set or return the debug status. If debug is set to true
the processed recipe will include additional debug statements.

  $rec->debug(1);

=cut

# Delegate debugging to the Parser

sub debug {
  my $self = shift;
  my $parser = $self->parser();
  return $parser->debug(@_);
}

=item B<frame>

Set or return the C<ORAC::Frame> associated with the recipe execution.
This controls

  $rec->frame($Frm);

=cut

# Delegate to the Parser

sub frame {
  my $self = shift;
  my $parser = $self->parser();
  return $parser->frame(@_);
}

=item B<instrument>

Set or return the instrument name. This is required to configure
search paths to determine recipe and primitive location.

  $inst = $rec->instrument;

If set, the parser object is updated automatically.

=cut

# Delegate to the Parser object since it does not really do us any
# good to have a scheme where they can differ

sub instrument {
  my $self = shift;
  my $parser = $self->parser();
  return $parser->instrument( @_ );
}

=item B<primitives>

Returns all the primitives that are referenced by this recipe.

 @prim = $rec->primitives;

=cut

sub primitives {
  my $self = shift;
  return $self->_read_all_prims( 1 );
}

=back

=head2 General Methods

=over 4

=item B<as_string>

Returns the full recipe as a single string.

 $string = $rec->as_string();

=cut

sub as_string {
  my $self = shift;

  # Force the recipe to be read
  $self->_read_recipe;

  # The recipe is easy
  my $str .= join("\n", $self->recipe->content )."\n";

  # Get the primitive names
  my @primitives = $self->primitives;

  # now we need to get the text for each one without compiling
  my $parser = $self->parser;
  my $nocomp = $parser->nocompile( 1 );
  for my $p (@primitives) {
    my $prim = $parser->find( $p );
    croak "Could not read primitive '$p'" unless defined $prim;
    $str .= join("\n",$prim->content ). "\n";
  }
  $parser->nocompile( $nocomp );
  return $str;
}

=item B<check_syntax>

Loads and compiles each primitive in the recipe.

A Frame object may be required for some instruments.

  $rec->check_syntax;

Returns an array of all the primitives used by the recipe (in the order in which they
were loaded).

  @primitives = $rec->check_syntax;

=cut

sub check_syntax {
  my $self = shift;
  return $self->_read_all_prims( 0 );
}

# Helper routine for check_syntax and primitives() methods.
sub _read_all_prims {
  my $self = shift;
  my $nocompile = shift;

  # force compilation if it has been disabled
  my $parser = $self->parser;
  my $curval = $parser->nocompile;
  $parser->nocompile($nocompile);

  # Read the recipe
  $self->_read_recipe;

  # and loop over each primitive
  my $recipe = $self->recipe;
  my @primitives = $self->_find_children( $recipe );
  $parser->nocompile($curval);

  # now clean up the primitives list
  my @outprim;
  my %cache;
  for my $p (@primitives) {
    next if exists $cache{$p};
    push(@outprim, $p);
    $cache{$p}++;
  }
  return @outprim;
}

# recursive routine to check that each primitive is available
# The depth optional parameter enables the hierarchy to be retained in string form by indenting
sub _find_children {
  my $self = shift;
  my $parent = shift;
  my $depth = shift;
  my $prefix = '';
  if (defined $depth) {
    $depth++;
    $prefix = '  ' x $depth;
  }
  my $parser = $self->parser;
  my @primitives;
  for my $prim ($parent->children) {
    my $child = $parser->find($prim);
    push(@primitives, $prefix . $prim );
    push(@primitives, $self->_find_children( $child, $depth ));
  }
  return @primitives;
}


=item B<execute>

Executes the recipes stored in the object.
Also needs the current frame, group and calibration objects
as well as the hash containing all the messaging objects.

  $rec->execute( \$CURRENT_RECIPE, \$CURRENT_PRIMITIVE, \$PRIMITIVE_LIST,
                 $Frm, $Grp, $Cal, $Display, \%Mon);

The following classes are avaiable to primitive writers:

  ORAC::Print, ORAC::LogFile, ORAC::General, ORAC::Constants,
  ORAC::TempFile, Starlink::Versions, LWP::Simple and IO::File.

Other classes can be loaded from within the recipe as needed.

Returns the recipe exit status or throws an exception.

The objects accessible to the recipe are:

=over 4

=item B<$CURRENT_RECIPE>

Reference to string describing the current recipe. Passed in here
because the executed recipe can be different to the requested
recipe. Will be set with the value:

  Currently doing: $RecipeName

=item B<$CURRENT_PRIMITIVE>

Reference to an array containing a list of currently running
primitives.

=item B<$Frm>

The current frame object to be processed. This is of
class C<ORAC::Frame> (or subclass thereof).

=item B<$Grp>

The group object associated with the current frame to be
processed. This is of class C<ORAC::Group> (or subclass thereof).
The C<<$ORAC_Recipe_Info->{Batch}>> variable controls how many frames are visible
to the group object.

=item B<$Cal>

The calibration object to use for this frame. This is of
class C<ORAC::Calib> (or subclass thereof).

=item B<$Display>

The object associated with the ORAC Display system. This
is of class C<ORAC::Display>. The display system has not been
initialised if this variable has a value of undef. Primitives
should check to see that the variable is defined before
attempting to use it.

=back

The following global variables are also available to the recipe:

=over 4

=item B<%Mon>

Hash containing all the algorithm engine objects.

=item B<$ORAC_Recipe_Info>

Reference to a hash containing information that may be of use
to the primitive. Keys are

  Batch - flag to indicate that batch mode is enabled
  Name  - name of the recipe that was loaded.

=back

The namespace in which the recipe is executed is not specified
and may change at any time.

=cut

sub execute {

  my $self = shift;

  # Read all args so that the only thing left will be the hidden arg,
  # note that $CURRENT_PRIMITIVE is passed since its used by the recipe
  # viewer window and added to the recipe code itself.
  my $CURRENT_RECIPE = shift;
  my $CURRENT_PRIMITIVE = shift;
  my $PRIMITIVE_LIST =shift;
  my $Frm = shift;
  my $Grp = shift;
  my $Cal = shift;
  my $Display = shift;
  my $Mon = shift;

  # store the frame in the object to control choices
  $self->frame( $Frm );

  # Force the recipe to be read
  $self->_read_recipe();
  $$CURRENT_RECIPE = "Currently doing: ".$self->name;

  # Store the top level primitive names in the global array
  if (defined $PRIMITIVE_LIST && ref($PRIMITIVE_LIST) ) {
    my $recobj = $self->recipe;
    @$PRIMITIVE_LIST = $self->_find_children( $recobj, -1);
  }

  # Info message for debugging
  my $recipe_name = $self->name;
  if ($self->debug) {
    orac_debug "***** Starting recipe '$recipe_name' *****\n";
  }

  # Clear logged messages and register the RECIPE name just in case
  # some messages turn up
  orac_clearlog();
  orac_logging( 1 );  # will be set earlier as a command line argument
  orac_logkey( $self->name );
  orac_loginfo( Recipe => $self->name,
                Software => $0,
                Version => ORAC::Version->getVersion(),
              );

  # Execute the recipe
  use Time::HiRes qw/ gettimeofday /;
  my $execute_start = [gettimeofday];
  my $status = eval { ORAC::Recipe::Execution::orac_execute_recipe( $PRIMITIVE_LIST, $CURRENT_PRIMITIVE,
                                                                    $self,$Frm,
                                                                    $Grp, $Cal,
                                                                    $Display, $Mon,
                                                                  ); };

  # We must grab $@ immediately because the debug code will reset
  # its value, causing us to lose errors. As do ref() and isa()
  my $error;
  if (!defined $status && $@) {
    $error = $@;
    ORAC::Error->flush; # Need to clear the error stack else the higher reaches of the pipeline will re-throw
    # if this is a termination request then we do not really care
    # about the exception at this point
    if (defined $error && ref($error) && $error->isa( "ORAC::Error::TermProcessing" )) {
      if ( $error->isa( "ORAC::Error::TermProcessingErr" ) ) {
        $status = ORAC__TERMERR;
      } else {
        $status = ORAC__TERM;
      }
      $error = undef;
    }
  }

  if (!$Frm->isgood) {
    if (!defined $status || ($status != ORAC__TERMERR && $status != ORAC__BADENG)) {
      $status = ORAC__BADFRAME;
    }
  }

  my $etext = '';
  if (defined $status) {
    if ($status == ORAC__TERM) {
      $etext = ' (recipe terminated early)';
    } elsif ($status == ORAC__TERMERR) {
      $etext = ' (recipe terminated early with handled error)';
    } elsif ($status == ORAC__BADFRAME) {
      $etext = ' (recipe completed but frame was marked bad)';
    }
  }

  my $execute_elapsed = tv_interval( $execute_start );
  my $p_execute_elapsed = sprintf( "%.3f", $execute_elapsed );
  orac_print "Recipe took $p_execute_elapsed seconds to evaluate and execute.$etext\n\n";

  $status = ORAC__OK unless defined $status;
  $status = ORAC__OK if $status eq '';

  # Store the real status here
  my $recstatus = $status;

  # _TERM is really a good status
  $status = ORAC__OK if $status == ORAC__TERM;

  # Some extra info
  if ($self->debug) {
    orac_debug "***** Recipe '$recipe_name' completed with status $status *****\n";
  }

  # Check for an error from perl (eg a croak), but evaluate in string
  # context so that thrown errors are caught, they should all have values
  # attached (e.g. ORAC__ABORT or ORAC__FATAL) but don't take chances
  if (defined $error && "$error") {

    # Check for previously thrown UserAbort errors
    if ( ref($error) && $error->isa("ORAC::Error::UserAbort") ) {
      # We have a UserAbort, no hassle, throw it and return to
      # the Tk Mainloop without printing any junk about the
      # error
      $error->throw;
    }

    # Since we have an error we can not trust the current
    # frame to be fully reduced. We therefore set its state
    # to bad so that it will be removed from Groups
    # Turn this feature off for now - more discussion required
    # $Frm->isgood(0);

    # Report error
    orac_err ("RECIPE ERROR: $error","blue");

    if ("$error" =~ /^Died/) {
      # Else check if the recipe died. Usually a die is caused
      # by a control C from the user.

      orac_err("Recipe died during execution\n");

    }

    # If debugging is turned on, dump the recipe on error
    if ($self->debug) {
      open my $fh, ">", "ORACDR_RECIPE.dump";
      if (defined $fh) {
        print $fh $self->as_string(). "\n";
        orac_err("Recipe contents dumped to ORACDR_RECIPE.dump\n")
      }
    }

    # Check for previously thrown non-UserAbort errors
    if ( ref($error) && $error->isa("Error") ) {
      # Exit from the pipeline with already existing error
      $error->throw;
    } else {
      # Exit from the pipeline by throwing a new error
      throw ORAC::Error::FatalError( "Exiting due to error executing recipe",
                                     ORAC__FATAL );
    }
  }

  # Check group membership following this execution
  $Grp->check_membership();

  # Check for bad status from the recipe (this is a bad status
  # without a croak - we continue)
  if ($status) {
    orac_err "Recipe completed with error status = $status\n";
    if ($status == ORAC__TERMERR || $status == ORAC__BADFRAME) {
      orac_err "The error indicates that the pipeline has attempted to handle the issue\n";
    } else {
      orac_err "Continuing but this may cause problems during group processing\n";
    }
  }

  return $recstatus;
}

=item B<_read_recipe>

Read the recipe from disk and pass to the parser.

  $rec->_read_recipe();

The instrument, frame object and recipe name must be set in the object for optimal
parsing. The frame object can be left out in some cases (eg if a parse test
is being performed). An error will occur during execution if the frame object is required.

The search path is set from the instrument name and from the
C<ORAC_RECIPE_DIR> environment variable. The C<ORAC_RECIPE_DIR>
environment variable is similar to a normal C<PATH> variable in that
multiple directories can be supplied if separated by colons.

Croaks if the recipe could not be found or opened. Returns ORAC__OK
on success.

=cut

sub _read_recipe {
  my $self = shift;

  my $name = $self->name;
  throw ORAC::Error::FatalError( "read_recipe: No recipe NAME available. Aborting", ORAC__FATAL)
    unless defined $name;

  my $inst = $self->instrument;
  throw ORAC::Error::FatalError( "read_recipe: No recipe INSTRUMENT available. Aborting", ORAC__FATAL)
    unless defined $inst;

  # Get the parser
  my $parser = $self->parser;

  # Arguments are okay. Now need to determine search path.
  my @path;

  # if it is in ORAC_RECIPE_DIR we do not need an instrument but since it is highly likely
  # that we do in fact need an instrument subsequently, we do not try to be overly clever.

  # ORAC_RECIPE_DIR should be at start of path
  push( @path, $parser->_split_path_env_var($ENV{ORAC_RECIPE_DIR}))
    if exists $ENV{ORAC_RECIPE_DIR};

  # Instrument specific search path
  push(@path, orac_determine_recipe_search_path( $inst ));

  # If the path array is empty add cwd (should not happen in oracdr)
  @path = ( File::Spec->curdir ) unless @path;

  # Now look for a recipe in that path, taking care to try the supplied suffices first
  my $recipe;
  my $found;
  my $RecErr;
  for my $suffix ( $self->suffices, '') {
    my $recname = $name . $suffix;
    # ask the parser to locate the recipe. We catch errors so that we can try a new name.
    # The error is reported for the last attempt that has failed
    $RecErr = undef;
    try {
      $recipe = $parser->find( $recname, \@path );
      $found = $recipe->name if defined $recipe;
      # print out a message if we found a recipe with a different
      # name to the one we were looking for
      if (defined $found && $name ne $found) {
        orac_print "Actual recipe loaded is $found due to recipe suffix modifier\n";
      }
    } catch ORAC::Error::FatalError with {
      my $E = shift;
      $RecErr = "$E";
      $E->flush; # Need to clear the error stack else the higher reaches of the pipeline will re-throw
    };
    last if defined $recipe;
  }
  # Rethrow the exception for the last attempt at finding the recipe
  if (!defined $recipe && defined $RecErr) {
    throw ORAC::Error::FatalError("$RecErr");
  }
  throw ORAC::Error::FatalError("Trouble reading recipe") unless defined $recipe;
  $self->recipe( $recipe );
  $self->name( $found );
  return ORAC__OK;
}




=back


=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>t.jenness@jach.hawaii.eduE<gt>

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

=begin __HIDDEN__

=cut

package ORAC::Recipe::Execution;

=head1 NAME

ORAC::Recipe::Execution - Namespace used for ORAC-DR recipe execution

=head1 DESCRIPTION

This namespace exists purely for executing ORAC-DR recipes. It provides
run time recipe processing routines and any additional classes that
are provided for recipe execution. It exists to separate recipe
execution from recipe naming.

=cut

use strict;
use warnings;
use ORAC::Print;
use ORAC::LogFile;
use ORAC::General;
use ORAC::Constants qw/ :status /;
use ORAC::TempFile;

use IO::File;
use Cwd;

eval 'use LWP::Simple qw/$ua get is_success status_message/';
if ($@) {
  orac_warn("The LWP::Simple module is not installed in your perl distribution\n");
  orac_warn("Features of the pipeline requiring HTTP access will not be available\n");
}
;


use Starlink::Versions qw/ :Funcs /;

=head1 FUNCTIONS

These recipe runtime functions are provided:

=over 4

=item B<get_prim_arg>

Retrieve a primitive argument safely using exists and defined
and if necessary returning the supplied default.

  my $val = get_prim_arg( $_PRIM_ARGS_, $key, $default, $error_if_undef );

The fourth argument is optional. If it is defined and true, then an
error will be thrown (via orac_term) if the primitive argument is
undefined.

=cut

sub get_prim_arg {
  my $argref = shift;
  my $key = shift;
  my $default = shift;
  my $error_if_undef = shift;

  if( defined( $error_if_undef ) && $error_if_undef &&
      ( ! exists( $argref->{$key} ) || ! defined( $argref->{$key} ) ) ) {
    my ( $package, $filename, $line ) = caller;
    orac_term( "$key argument to $filename must be defined! Programming error!" );
  }

  return (exists $argref->{$key} && defined $argref->{$key})
    ? $argref->{$key} : $default;
}

=item B<orac_execute_recipe>

Simple wrapper to eval in this namespace in order to execute recipes
without fear of possible contamination of the base recipe namespace.

  $status = orac_execute_recipe( $CURRENT_PRIMITIVE, $Recipe, $Frm, $Grp,
                                 $Cal, $Display, $Mon);

The recipe is a C<ORAC::Recipe> object. The basic objects have to
be supplied since they can not be set inside the recipe prior to
execution (the stringified objects have no meaning). The debug and
batch variables are passed in as recipe globals.

Note that $DEBUG in recipes and primitives is set during compile time and
not during execution.

The ORAC_DR_RECIPE user header of the Frame and Group objects are updated
to reflect the name of the actual recipe being used.

=cut

# These allow reflected state in GUIs
my $CURRENT_PRIMITIVE;
my $PRIMITIVE_LIST;
my @primitive_list_local;

sub orac_execute_recipe {
  my ( $primitive_list, $current_primitive,
       $Recipe, $Frm, $Grp, $Cal, $Display, $Mon) = @_;

  # initial recursion depth
  my $DEPTH = 0;

  # File the Current primitive with the internal method
  $CURRENT_PRIMITIVE = $current_primitive;

  # and file the list of contents itself with a copy
  $PRIMITIVE_LIST = $primitive_list;
  @primitive_list_local = @$PRIMITIVE_LIST if defined $PRIMITIVE_LIST;

  # Clear stored primitive parameters
  ORAC::Recipe::PrimitiveParser->_clear_prim_params();

  # Tell the Frame and Group what recipe this is
  $Frm->uhdr( "ORAC_DR_RECIPE", $Recipe->name );
  $Grp->uhdr( "ORAC_DR_RECIPE", $Recipe->name );

  # Get the recipe parameters
  my $allpars = $Recipe->parameters;
  my %recpars;
  if ($allpars) {
    # Need the object name in some cases
    %recpars = $allpars->for_recipe( $Recipe->name,
                                     $Frm->uhdr("ORAC_OBJECT"));
  }

  # run the recipe
  my $recobj = $Recipe->recipe;
  my $coderef = $recobj->code;
  if ( defined( $coderef ) ) {
    return $coderef->( 0, [], $Frm, $Grp, $Cal, $Display, $Mon,
                       { Batch => $Recipe->batch,
                         Name => $Recipe->name,
                         Parameters => \%recpars,
                       });
  } else {
    return ORAC__ERROR;
  }
}

=item B<current_primitive>

Class method to set the current primitive during execution.

  ORAC::Recipe::Execution->current_primitive( $primitive_name, \@callers );

The caller array allows nested trees to be processed correctly if required and contains
the full call stack. Each element is a reference to an array containing the calling primitive
name and line number and the number of times this primitive was called from the caller.

=cut

sub current_primitive {
  my $class = shift;
  my $primname = shift;
  my $callers = shift;

  return if (defined $callers && @$callers < 2 ); # Recipe level itself is not useful

  # if we do not have a primitive list we simplify the logic
  if (!defined $PRIMITIVE_LIST) {
    $$CURRENT_PRIMITIVE = [ $primname ] if scalar(@$callers) == 2;
    return;
  }

  # Get local copy of information
  my @callers = map { [ @$_] } @$callers;

  # and add the current primitive to the list
  push(@callers, [$primname, 0, 0]);

  # the repeat counts need to be shifted along by one slot because the caller information is telling
  # the callee how many times it has been called and we will be walking through the callee information
  for my $i (reverse 1..$#callers) {
    $callers[$i]->[2] = $callers[$i-1]->[2];
  }

  # shift off the recipe level
  shift(@callers);

  # Reset the displayed list
  @$PRIMITIVE_LIST = @primitive_list_local;

  # if we have callers we can work out where to place the highlighter
  #  print ">>>>>>>>>>>> START LOOP for $primname\n";
  my $pos = -1;
  my $calldepth = 0;
 CALLER: for my $caller (@callers) {
    $calldepth++;
    my ($prim, $line, $repeat) = @$caller;
    #    print "Looking for instance $repeat of '$prim' in list\n";

    # go through looking for the correct starting point
    while (1) {
      $pos++;
      if ($pos > $#primitive_list_local) {
        # could not find anything
        last CALLER;
      }
      # Note that call depth is adjusted to account for recipe name in list
      # we are looking for a primitive of this name
      my $lookfor = ('  'x ($calldepth-1)). $prim;

      # and we have an error if we get to a new primitive with less indent
      my $endprim;
      $endprim = (' ' x ($calldepth - 2)). "_" if $calldepth > 1;

      #      print "Comparing '$lookfor' with '$primitive_list_local[$pos]'\n";
      if ( $primitive_list_local[$pos] eq $lookfor) {
        $repeat--;
        if ($repeat == 0) {
          # found it so set a little << on the primitive in the displayed list
          $PRIMITIVE_LIST->[$pos] = $primitive_list_local[$pos] . " <<";
          next CALLER;
        }
        #        print "Got a match but need more\n";
      } elsif ( defined $endprim && $primitive_list_local[$pos] =~ /^$endprim/) {
        return;
      }
    }
  }

  if ($pos > $#primitive_list_local) {
    # fell off the end of the list so nothing to highlight
    return;
  }

  # make sure actual match is unique by adding an extra flourish
  $PRIMITIVE_LIST->[$pos] .= "<";

  # configure the primitive name to match
  $primname = $PRIMITIVE_LIST->[$pos];

  $$CURRENT_PRIMITIVE = [ $primname ];
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>,

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


=end __HIDDEN__

=cut

1;
