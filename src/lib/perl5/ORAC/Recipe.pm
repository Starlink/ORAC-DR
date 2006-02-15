package ORAC::Recipe;

=head1 NAME

ORAC::Recipe - Recipe parsing and execution

=head1 SYNOPSIS

  use ORAC::Recipe;

  $r = new ORAC::Recipe( $recipe, $instrument );

  $r->instrument( $instrument );
  $r->read_recipe(RECIPE => $recipe,
                  INSTRUMENT => $instrument);
  $r->parse( $PRIMITIVE_LIST );
  $r->execute( \$CURRENT_PRIMITIVE, \$PRIMITIVE_LIST,
               $Frm, $Grp, $Cal, $Display, \%Mon);

=head1 DESCRIPTION

Class for reading, parsing and executing ORAC-DR recipes.
In general the methods should be called in the order 
shown in the SYNOPSIS.

=cut

use strict;
use 5.006;
use warnings;
use Carp;
use File::Spec;  # For pedants everywhere
use IO::File;    # until perl5.6 is guaranteed
use Text::Balanced qw/ extract_bracketed /;

# use Data::Dumper; # for debugging

use ORAC::Constants qw/ :status /;
use ORAC::Print;
use ORAC::Basic;
use ORAC::Error qw/ :try /; 
use ORAC::Inst::Defn qw/ orac_determine_recipe_search_path
  orac_determine_primitive_search_path orac_list_generic_observing_modes/;

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
  my $rec = {
	     DEBUG => 0,
	     BATCH => 0,
	     Instrument => undef,
	     RecipeName => undef,
	     ParsedRecipe => [],
	     HaveParsed => 0, # indicate it is ready for execution
	    };

  # bless into the correct class
  bless( $rec, $class);

  # Check for arguments
  if ( @_ ) {
    my %args = @_;
    if (exists $args{NAME} && exists $args{INSTRUMENT}) {

      try {
         $rec->read_recipe(%args);
      }
      catch ORAC::Error::FatalError with
      {
         my $Error = shift;
         $Error->throw;
      }
      otherwise
      {
         my $Error = shift;
         throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
      };

    } elsif (exists $args{NAME}) {
      $rec->recipe_name( $args{NAME} );
    } elsif (exists $args{INSTRUMENT}) {
      $rec->instrument( $args{INSTRUMENT});
    }
  }

  return $rec;
}

=back

=head2 Accessor Methods

=over 4

=item B<batch>

Set or return the batch processing status. If batch is set to true 
the recipe will process groups that have been pre-populated with
unprocessed frames..

  $batch = $rec->batch;

=cut

sub batch {
  my $self = shift;
  if (@_) { $self->{BATCH} = shift };
  return $self->{BATCH};
}


=item B<debug>

Set or return the debug status. If debug is set to true 
the processed recipe will include additional debug statements.

  $rec->debug(1);

=cut

sub debug {
  my $self = shift;
  if (@_) { $self->{DEBUG} = shift };
  return $self->{DEBUG};
}


=item B<instrument>

Set or return the instrument name. This is required to configure
search paths to determine recipe and primitive location.

  $inst = $rec->instrument;

=cut

sub instrument {
  my $self = shift;
  if (@_) { $self->{Instrument} = shift };
  return $self->{Instrument};
}

=item B<recipe_name>

Return (or set) the name of the recipe to be processed.

  $name = $rec->recipe_name;
  $rec->recipe_name("REDUCE_DARK");

=cut

sub recipe_name {
  my $self = shift;
  if (@_) { $self->{RecipeName} = shift };
  return $self->{RecipeName};
}


# Internal access to parsed recipe
# Returns the array reference.
# With arguments:
#   - If the argument is an array reference the reference
#     is copied in
#   - if the first argument is not a reference the entire @_
#     is copied into the array overwriting any previous contents.

sub _recipe {
  my $self = shift;
  if (@_) {
    if (ref($_[0])) {
      $self->{ParsedRecipe} = $_[0];
    } else {
      @{ $self->{ParsedRecipe} } = @_;
    }
  }
  return $self->{ParsedRecipe};
}

# Flag to indicate the recipe has been parsed and the
# primitives expanded.

sub have_parsed {
  my $self = shift;
  if (@_) { $self->{HaveParsed} = shift };
  return $self->{HaveParsed};
}


=back

=head2 General Methods

=over 4

=item B<check_syntax>

Executes the recipe to check syntax. The method modifies the
recipe by setting dummy input variables and causing the recipe
to exit immediately after perl parses the recipe.

The return status is identical to that from C<execute> method
in that the process may die after syntax checking. If this
is not required an eval block should be used.

  $rec->check_syntax;

The recipe stored in the object is not modified so that
in principal the recipe could be executed after the recipe
check.

=cut

sub check_syntax {
  my $self = shift;

  # Dummy variables
  my ($Frm,$Grp,$Cal,$Display,%Mon);
  my $CURRENT_PRIMITIVE;
  my $PRIMITIVE_LIST = [];

  try {
    $self->execute( \$CURRENT_PRIMITIVE, \$PRIMITIVE_LIST, 
                    $Frm, $Grp, $Cal, $Display, \%Mon, {SYNTAX => 1});
  }
  catch ORAC::Error::FatalError with
  {
     my $Error = shift;
     $Error->throw;
  }
  otherwise
  {
     my $Error = shift;
     throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
  };
}


=item B<execute>

Executes the recipes stored in the object.
Also needs the current frame, group and calibration objects
as well as the hash containing all the messaging objects.

  $rec->execute( \$CURRENT_PRIMITIVE, \$PRIMITIVE_LIST, 
                 $Frm, $Grp, $Cal, $Display, \%Mon);

The following classes are avaiable to primitive writers:

  ORAC::Print, ORAC::LogFile, ORAC::General, ORAC::Constants,
  ORAC::TempFile, Starlink::Versions, LWP::Simple and IO::File.

Other classes can be loaded from within the recipe as needed.

The objects accessible to the recipe are:

=over 4

=item B<$CURRENT_PRIMITIVE>

Reference to an array containing a list of currently running
primitives.

=item B<$Frm>

The current frame object to be processed. This is of
class C<ORAC::Frame> (or subclass thereof).

=item B<$Grp>

The group object associated with the current frame to be
processed. This is of class C<ORAC::Group> (or subclass thereof).
The C<$BATCH> variable controls how many frames are visible
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

=item B<$DEBUG>

This flag can be used to turn on some debugging features.

=item B<$BATCH>

Flag to indicate whether the groups have been populated before
the recipe is executed (ie whether the pipeline is running in
batch mode or not).

=back

The namespace in which the recipe is executed is not specified
and may change at any time.

=cut

sub execute {

  my $self = shift;

  # Read all args so that the only thing left will be the hidden arg,
  # note that $CURRENT_PRIMITIVE is passed since its used by the recipe
  # viewer window and added to the recipe code itself.
  my $CURRENT_PRIMITIVE = shift;
  my $PRIMITIVE_LIST =shift;
  my $Frm = shift;
  my $Grp = shift;
  my $Cal = shift;
  my $Display = shift;
  my $Mon = shift;

  croak "Recipe has not been parsed!" unless $self->have_parsed;

  # Hidden options are passed in using a hash ref at the end
  # of the argument list
  my $hidden = {};
  if (ref($_[-1]) eq 'HASH') {
    $hidden = $_[-1];
  }

  # Generate a single recipe string
  my @recipe = @{ $self->_recipe };
  my $block = join("",@recipe);

  # If the recipe is to be syntax checked prepend "return;"
  $block = "orac_print \"Recipe executing - syntax OK\\n\";\nreturn;\n\n".$block
    if $hidden->{SYNTAX};


  # Want to make sure that perl warnings are turned off
  # when evaluating recipes - control via the -warn parameter
  # local $^W = 0;

  # Info message for debugging

  my $recipe_name = $self->recipe_name;
  if ($self->debug) {
     orac_debug "***** Starting recipe '$recipe_name' *****\n";
  }

  # Execute the recipe

  my $status = ORAC::Recipe::Execution::orac_execute_recipe( $CURRENT_PRIMITIVE,
                                                             $block,$Frm,
	  						     $Grp, $Cal,
							     $Display, $Mon,
							     $self->debug,
							     $self->batch);

  $status = ORAC__OK unless defined $status;
  $status = ORAC__OK if $status eq '';

  # We must grab $@ immediately because the debug code will reset
  # its value, causing us to lose errors. As do ref() and isa()
  my $error = $@;

  # Some extra info
  if ($self->debug) {
    orac_debug "***** Recipe '$recipe_name' completed with status $status *****\n";
  }

  # Check for an error from perl (eg a croak), but evaluate in string 
  # context so that thrown errors are caught, they should all have values
  # attached (e.g. ORAC__ABORT or ORAC__FATAL) but don't take chances
  if ("$error") {

    # Check for previously thrown UserAbort errors	
    if ( ref($error) && $error->isa("Error") )
    {
        if ( $error == ORAC__ABORT )
	{
	   # We have a UserAbort, no hassle, throw it and return to
	   # the Tk Mainloop without printing any junk about the error
           $error->throw;
	}
    }	

    # Since we have an error we can not trust the current
    # frame to be fully reduced. We therefore set its state
    # to bad so that it will be removed from Groups
    # Turn this feature off for now - more discussion required
    # $Frm->isgood(0);

    # Report error
    orac_err ("RECIPE ERROR: $error","blue");

    # Create an array that matches the line numbers returned by
    # the error message.
    # Note that this line number relates to $block and
    # not @recipe. Need to split $block on new line
    my @new = split(/\n/, $block);

    # If this was a syntax error print out the recipe, string context!
    if ("$error" =~ /syntax error|object method/) {

      # This is broken if the real primitive line numbers are provided
      # rather than the line numbering of the entire recipe.

      # Extract info from the error message, string context!
      "$error" =~ /line (\d+)/ && do {
	my $num = $1;
	orac_err("Error in line $num\n", 'red');
	orac_err("Relevant recipe lines (with numbers):\n\n", 'red');

	# Calculate number of lines to print
	my $inc = 15;
	my $start = ($num > $inc ? $num - $inc : 0 );
	my $end   = ($num < $#recipe - $inc ? $num + $inc : $#recipe);

	# Print out the relevant chunk with line numbers
	for (my $i=$start; $i < $end; $i++) {
	  orac_err("$i: ", 'blue');
          orac_err("$new[$i]\n", 'red');
	}
	orac_err("End recipe dump\n\n",'blue');
      };

    } elsif ("$error" =~ /^Died/) {
      # Else check if the recipe died. Usually a die is caused 
      # by a control C from the user.

      orac_err("Recipe died during execution\n");

    }

    # If debugging is turned on, dump the recipe on error
    if ($self->debug) {
      my $fh = new IO::File("> ORACDR_RECIPE.dump");
      if (defined $fh) {
	print $fh join('',@recipe). "\n";
	orac_err("Recipe contents dumped to ORACDR_RECIPE.dump\n")
      }
    }

    # Check for previously thrown non-UserAbort errors	
    if ( ref($error) && $error->isa("Error") )
    {
        # Exit from the pipeline with already existing error
        $error->throw;
    }	
    else
    {	
       # Exit from the pipeline by throwing a new error
       throw ORAC::Error::FatalError( "Exiting due to error executing recipe",
                                      ORAC__FATAL );
    }
  }

  # Check for bad status from the recipe (this is a bad status
  # without a croak - we continue)
  if ($status) {
    orac_err "Recipe completed with error status = $status\n";
    orac_err "Continuing but this may cause problems during group processing\n";
  }


}


=item B<parse>

Parses the recipe read via C<read_recipe>, reading in the
necessary primitives and adding additional error checking code.

Takes a reference to the tied array which defines the recipe
window listbox contents as an optional argument.

  $rec->parse( $PRIMITIVE_LIST );

Once parsed the recipe is ready for execution.

Returns ORAC__OK on completion.

=cut

sub parse {
  my $self = shift;
  my $PRIMITIVE_LIST = shift;

  # The recipe has to be parsed recursively.
  # To do that we need to make use of a helper routine that 
  # can process the current recipe chunk and check for recursion depth

  # The master chunk is the base recipe reference.
  # The initial recursion depth is 1
  my $parsed = $self->_parse_recursively( $self->_recipe, 
					  $self->recipe_name,
					  $PRIMITIVE_LIST );

  # Now need to store that array in the object overwriting the
  # unprocessed copy.
  $self->_recipe( $parsed );

  # Now that the recipe has been expanded and read from disk
  # we need to add error checking code
  $self->_add_code_to_recipe;

  # Update the parsed flag
  $self->have_parsed(1);

  return ORAC__OK;

}

=item B<read_recipe>

Read the recipe from disk. The recipe must then be parsed
to insert the primitive code.

  $rec->read_recipe( NAME => "REDUCE_DARK",
                     INSTRUMENT => "IRCAM" );

The arguments are optional if the C<instrument> or C<recipe_name>
methods have been set previously and override previous values.

The search path is set from the instrument name and from the
C<ORAC_RECIPE_DIR> environment variable. The C<ORAC_RECIPE_DIR>
environment variable is similar to a normal C<PATH> variable in that
multiple directories can be supplied if separated by colons.

Croaks if the recipe could not be found or opened. Returns ORAC__OK
on success.

=cut

sub read_recipe {
  my $self = shift;
  my %args;
  %args = @_ if @_;

  # Read instrument and recipe name from args or object
  my ($name, $inst);
  if ( exists $args{NAME} ) {
    $name = $args{NAME};
    $self->recipe_name($name); # update object
  } elsif (defined $self->recipe_name) {
    $name = $self->recipe_name;
  } else {
    throw ORAC::Error::FatalError( "read_recipe: No recipe NAME supplied. Aborting", ORAC__FATAL);
  }
  if ( exists $args{INSTRUMENT} ) {
    $inst = $args{INSTRUMENT};
    $self->instrument($inst); # update object
  } elsif (defined $self->instrument) {
    $inst = $self->instrument;
  } else {
    throw ORAC::Error::FatalError( "read_recipe: No recipe INSTRUMENT supplied. Aborting", ORAC__FATAL);
  }

  # Arguments are okay. Now need to determine search path.
  my @path;

  # ORAC_RECIPE_DIR should be at start of path
  push( @path, $self->_split_path_env_var($ENV{ORAC_RECIPE_DIR}))
    if exists $ENV{ORAC_RECIPE_DIR};

  # Instrument specific search path
  push(@path, orac_determine_recipe_search_path( $inst ));

  # If the path array is empty add cwd (should not happen in oracdr
  @path = ( File::Spec->curdir ) unless @path;

  # print Dumper(\@path),"\n";

  # Now search the directory structure for NAME
  my @found = $self->_search_path( \@path, $name);

  unless (@found) {
    my $str = join("\n", @path);
    throw ORAC::Error::FatalError( "Could not find and/or open recipe $name in any of:\n$str\n", ORAC__FATAL);
  }

  $self->_recipe( $self->_concat_all_relevant_files( @found ) );

  return ORAC__OK;
}




=back

=begin __PRIVATE_METHODS__

=head2 Private methods

These methods are for internal use only.

=over 4

=item B<_add_code_to_recipe>

Post processes the recipe adding status checking code
and debug statements.

If debugging is turned on obey information is written to a debug
file just before and after each obeyw. This can be used to determine
whether an obey completed.

=cut

sub _add_code_to_recipe {
  my $self = shift;

  # Get the reference to the recipe array
  my $recipe = $self->_recipe;

  my @processed = ();

  my ($line);

  foreach $line (@$recipe) {

    if ($line =~ /->obeyw(.*)/) {

      my $arguments = $1;

      $arguments =~ s/\"/ /g;


      # Add the following debug line if the obeyw is not commented out
      # Debug line if DEBUG is true
      my $debug_obey = 0;
      if ($self->debug && $line !~ /\#.+->obeyw/) {
	push(@processed,
	     'orac_debug( $Frm->number . ":".$ORAC_PRIMITIVE .'."\":\t$arguments\n\");\n");
	$debug_obey = 1;
      }

      # Now check to see whether it starts with a comment character
      # (Note that the xemacs syntax recognition does not understand #
      # in a pattern match)
      # or if somebody has put an equals sign in and is checking it
      # themselves.
      if ($line !~ /(\#|=).+?->obeyw/x) {

	# Now add the OBEYW status checking lines
	# prepending the OBEYW_STATUS line
	# Put it in a block of its own to prevent warnings
	# relating to the masking of $OBEYW_STATUS in a earlier
	# declaration in same scope
	push (@processed, 
	      "{  # Create block to prevent warnings from my OBEYW_STATUS\n",
	      'my $OBEYW_STATUS = ' .$line);

	# If debugging add a statement before the status is checked
	# so that we can store the status value in the file
	push(@processed,
	     'orac_debug( "Returned with status = ". $OBEYW_STATUS . "\n");'."\n"
	    ) if $debug_obey;

	# Now complete the obey error checking
	push(@processed,
	     $self->_check_obey_status_string($line),
	     "\n}\n"
	    );
	
      } else {
	# Just push the line on as is
	push (@processed, $line);

	# Add simple return notification
	push(@processed,
	     'orac_debug( "Returned from obey. Status intercepted\n");'."\n"
	    ) if $debug_obey;

      }


    } elsif ($line =~ /\$ORAC_STATUS/ && $line =~ /=/) {
      # Check that it has ORAC_STATUS and that the line has an
      # assignment (should check that the ORAC_STATUS is to the left of the
      # = and that ORAC_STATUS is to the left of a #)
      # Put on the current line
      push (@processed, $line);

      # Add the status checking code
      # unless there is a comment before the ORAC_STATUS
      push (@processed, $self->_check_status_string)
	unless $line =~ /\#.+?\$ORAC_STATUS/;

    } else {
      push(@processed,$line);
    }

  };

  # We must return good status at the end of the recipe
  push(@processed, "\nORAC__OK;\n");

  # Now we have a post-processed recipe  store it
  $self->_recipe( \@processed );

}

=item B<_check_status_string>

Provides the code for automatic status checking of recipes.

  $string = $rec->_check_status_string;

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

  $string = $rec->_check_obey_status_string( $obey_line );

Checks also for the special case of ORAC__BADENG as the 
return value. In that case, the monolith is removed from
the message system so that next time it is required
a new one is launched.

=cut

sub _check_obey_status_string {
  my $self = shift;

  my ($monolith, $task, $args);

  # Get the name of the monlith from the obeyw
  my $line = shift;

  # Do the regexp separately so that we can handle the situation
  # where the monolith path is not stored in a hash
  $line =~ /\{\s*[\'\"]*(\w+)[\'\"]*\s*\}->obeyw/ && ($monolith = $1);
  $line =~ /->obeyw\(\s*\"(\w+)\"/ && ($task = $1);
  $line =~ /->obeyw\(\s*\"\w+\"\s*,\s*\"(.+)\"/ && ($args = $1);
  $args = '(No arguments)' unless defined $args;
  my $none = "(None!!)";
  $monolith = $none unless defined $monolith;
  $task = '(Unknown)' unless defined $task;

  # Need to be careful of what gets expanded when the
  # lines are added to the recipe and what gets expanded
  # when the recipe is executed.

  my @statuslines = (
		     'if ($OBEYW_STATUS != ORAC__OK) {',
		     "  orac_err (\"Error in obeyw to monolith $monolith (task=$task): \$OBEYW_STATUS\\n\");" ,
		     '  my $obeyw_args = "'. $args . '";',
		     '  orac_print("Arguments were: ","blue");',
                     '  orac_print("$obeyw_args\n\n","red"); '
		    );

  # If we have been unable to determine the monolith name we can not
  # add the following - could use splice rather than to pushes
  if ($monolith ne $none) {
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



=item B<_parse_recursively>

Parses and reads a recipe from disk translating primitive
directives to native code.

This routine uses recursion to parse the recipe until no more
primitive include directives are present. A recursion depth
of 10 is imposed to deal with out-of-control recipe recursion
(usually where a primitive calls itself). This should not be a
problem for working primitives.

The depth parameter is an integer specifying the current recursion
depth. When called externally, the depth should be set to 0 or C<undef>.
It is inremented internally during recursion.

   $processed_chunk = $rec->_parse_recursively( \@chunk, $name,
                                                \@PRIMTIIVE_LIST,
					        [ $depth ]);

When called externally the array to be processed is usually the
raw recipe. The return value is a reference to an array containing
the processed recipe chunk.

The second argument is the name of the current primitive/recipe that
is being parsed. This is used for providing line counts.  The third
argument is a reference to an array which is used to contain the
current primitive status as the recipe executes.

Line numbering is added automatically so that warnings and errors should
refer to the correct place in the actual primitive or recipe rather than
line numbers in a translated recipe. In order to provide some idea of the
position of the primitive within the recipe line numbers are incremented
by 1000 for each level of recursion. ie if the error is stated to be
at line 1164 this means that it is in line 164 of the primitive but that
the primitive was called by another primitive.

=cut

sub _parse_recursively {
  my $self = shift;
  my $chunk = shift;
  my $current_name = shift;
  my $PRIMITIVE_LIST = shift;

  croak '_parse_recursively: First argument must be an array reference!'
    unless ref($chunk) eq 'ARRAY';

  # Try to read a depth. Does not matter if it is undef
  my $depth = shift; # can be undef

  # Increment recursion depth
  $depth++;

  # Check depth
  my $MAX_DEPTH = 10;
  if ($depth > $MAX_DEPTH) {
    orac_err "Maximum recursion depth ($MAX_DEPTH) reached for this recipe.\n";
    croak "Aborting recipe parse\n";
  }

  # depth cant be negative
  $depth = 1 if $depth <= 0;

  # Create output array
  my @parsed = ();

  # indicates we are in a pod section so should not insert primitives
  my $inpod = 0;

  # Store the current line number so we can reset it when returning
  # from a primitive
  my $lineno = 0;

  # If depth is 1 it means that we should specify line number for
  # the recipe itself
  push(@parsed,"#line 0 $current_name\n") if $depth == 1;

  # Loop over recipe lines
  foreach my $line (@$chunk) {
    $lineno++;

    # check to see if this is a pod directive
    # special case =cut
    if ($line =~ /^=cut\n/) {
      $inpod = 0;
    } elsif ($line =~ /^=/) {
      $inpod = 1;
    }

    # Check for primitive insert directives
    # only check if we are not in a pod section (=cut will not match anyway)
    if (! $inpod && $line =~ /^\s*_/ ) {
      $line =~ s/^\s+//;	# zap leading blanks
      $line =~ s/\s*$//;        # Zap trailing blanks
      my ($primitive_name, $rest) = split(/\s+/,$line,2);
      $rest = '' unless defined $rest; # -w protection for next line

      # Set the initial counter for this primitive
      push(@parsed, "#line 0 $primitive_name"."_header\n");

      # Parse any arguments. Add a line that runs orac_parse_arguments
      # on $rest and sets a hash called %primitive_name
      # $rest is a string of form 'arg1="value" arg2=$value' that is 
      # converted to a hash at runtime by orac_parse_arguments
      # This hash is in the upper scope so will suffer from masking
      # problems the second time it gets used at this level.
      # This has to be the case but we would like to turn off warnings
      # associated with this when we are below the first level of recursion
      push(@parsed, "no warnings 'misc'; # Added during translation to prevent mask warnings\n") 
	if $depth > 1;

      # Now create the arg hash
      push(@parsed,
	   'my %'."$primitive_name = (".orac_parse_arguments($rest).");\n",
	   "ORAC::Event->update('Tk');\n");

      # read in primitive
      my $lines_ref = $self->_read_primitive( $primitive_name );

      # Now recurse to read parse the primitive for more primitives
      $lines_ref = $self->_parse_recursively($lines_ref, $primitive_name,
					     $PRIMITIVE_LIST,
					     $depth);

      # Store lines - making sure we DO NOT create a separate scope
      # for the $$CURRENT_PRIMITIVE variable
      push(@parsed,
         "\n{\nmy \$ORAC_PRIMITIVE=\"$primitive_name\";\n",
	 "\$\$CURRENT_PRIMITIVE=[ \$ORAC_PRIMITIVE ];\n",
	 "ORAC::Event->update(\"Tk\");\n\n",
	 "#line ",(($depth-1)*1000)  ," $primitive_name\n",
         @$lines_ref,
	 "\n#line 0 $primitive_name"."_footer\n",
	 "\n# Exit $primitive_name\n",
         "}\n",
	  );	

      # Turn warnings back on again if we disabled them earlier
      push(@parsed, "use warnings; # Turn back on\n") if $depth > 1;

      # Reset the line count to the next line
      # Problem is that we want both top level recipe count
      # and first level primitive count to start counting
      # from zero but all lower levels to increment from 1000
      # 2000 etc. Also note that this depth is not the depth
      # really implied by the above. We could deal with this
      # simply by putting the above primitive code into 
      # every parse rather than explicitly the first primitive
      # This is because recipes are not the same as primitives
      # in the current scheme.
      my $thisdepth = ( $depth <= 2 ? 0 : $depth - 2);
      my $thisline = ($thisdepth*1000) + $lineno+1;
      push(@parsed, "#line $thisline $current_name\n");
	
      # push top level primitivies into the primitive list
      if ( defined $PRIMITIVE_LIST && ref($PRIMITIVE_LIST) ) {
         push( @$PRIMITIVE_LIST, $primitive_name ); }

    } elsif (! $inpod && $line =~ /ORAC_STATUS|obeyw/ ) {
      # If we have something that looks like an obey or an ORAC_STATUS
      # doesnt need to be a very good test since we are using it just
      # to add some extra reinforcement of line counting

      # Same kluge as above to figure out the line number when
      # compensating for depth. Not sure this is worth the 
      # effort
      my $thisdepth = ( $depth <= 2 ? 0 : $depth - 2);
      my $thisline = ($thisdepth*1000) + $lineno+1;

      # Reset the line number after the obey or whatever
      push(@parsed,
	   $line,
	   "#line $thisline $current_name\n",
	  );

    } else {
      # Just push the line on as is
      push (@parsed, $line);

    }

  }

  return(\@parsed);


}

=item B<_read_primitive>

Reads the specified primitive from the recipe directory.
An array reference containing the primitive is returned.

  $primitive_contents = $rec->_read_primitive( $primitive_name );

The location of the recipe is determined first by looking in the
directory specified with C<ORAC_PRIMITIVE_DIR> and then the ORAC
repository directories specified from C<ORAC::Inst::Defn>.  The
C<ORAC_PRIMITIVE_DIR> environment variable is similar to a normal
C<PATH> variable in that multiple directories can be supplied if
separated by colons.

If the primitive can not  be found the program aborts.

=cut

sub _read_primitive {
  my $self = shift;
  my $name = shift;

  # print Dumper($self);

  # Retrieve the instrument name
  my $instrument = $self->instrument;

  # Check that it is defined
  throw ORAC::Error::FatalError( "_read_primitive: Instrument not defined.",
                                 ORAC__FATAL) unless defined $instrument;

  # Create the search path [very similar to read_recipe method]
  my @path;

  # ORAC_PRIMITIVE_DIR should be at start of path
  push( @path, $self->_split_path_env_var($ENV{ORAC_PRIMITIVE_DIR}))
    if exists $ENV{ORAC_PRIMITIVE_DIR};

  # Instrument specific search path
  push(@path, orac_determine_primitive_search_path( $instrument ));

  # If the path array is empty add cwd (should not happen in oracdr
  @path = ( File::Spec->curdir ) unless @path;

  # Now search the directory structure for primitive name
  my @found = $self->_search_path( \@path, $name);

  unless (@found) {
    my $str = join("\n", @path);
    throw ORAC::Error::FatalError( "Could not find primitive named $name in any of:\n\n$str\n", ORAC__FATAL);
  }

  return $self->_concat_all_relevant_files( @found );
}

=item B<_concat_all_relevant_files>

Given a set of files (with full path), return the
contents of the file or files that are relevant. Ambiguities are
resolved by adding conditional statements to the returned code.

  $array_ref = $recipe->_concat_all_relevant_files( @files );

=cut

sub _concat_all_relevant_files {
  my $self = shift;
  my @found = @_;

  # We now have an array of all possible primitives/recipes that match
  # this name. If we only have one match we can read it without
  # further ado or confusion. If we don't have any we can raise an exception

  my $contents = [];
  if (@found) {

    if ($#found == 0) {

      $contents = $self->_slurp_file($found[0]);

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
	$contents = $self->_slurp_file($best{INST});
      } elsif ($#keys == 0) {
	# We only have one choice remaining so should not be
	# switching
	$contents = $self->_slurp_file($best{$keys[0]});
      } else {
	# Else we have a choice of observing modes
	# So we have to add code to help the recipe along
	for my $mode (keys %best) {

	  # If statement
	  # This is really going to confuse the line counting
	  push(@$contents, 
	       'die("There were ambiguities in file selection and ORAC_OBSERVATION_MODE header was not set") unless defined $Frm->uhdr("ORAC_OBSERVATION_MODE");',
	       "if (defined \$Frm->uhdr(\"ORAC_OBSERVATION_MODE\") && \$Frm->uhdr(\"ORAC_OBSERVATION_MODE\") eq \"$mode\") {\n");
	  push(@$contents, "#line 0 $best{$mode}\n");
	  # The primitive/recipe
	  push(@$contents, @{ $self->_slurp_file($best{$mode}) });
	  # Closing
	  push(@$contents, "}\n");

	}

      }

    }

  }

  return $contents;
}

=item B<_search_path>

Search for file in search path. Return an array of all the files
which match the name in the order in which they are located. In 
scalar context return the first name.

  $first = $rec->_search_path( \@path, $name );
  @found = $rec->_search_path( \@path, $name );

Returns an empty list or undef on error depending on context.

The search path is specified as a reference to an array of directories.

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

  $linesref = $Cal->_slurp_file($path);

Returns an array reference.

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

  @path = $rec->_split_path_env_var( $ENV{PATH} );

No attempt is made (yet) to check that the directories in the path
are valid.

=cut

sub _split_path_env_var {
  my $self = shift;
  return split(/:/, $_[0]);
}

=item B<orac_parse_arguments>

Parses argument lists on primitive calls.
Converts a string of form 'arg1=value1 arg2=value2...'
to a hash constructor string of the form

   a => "b", c => $d, e => "f"

ie Arguments are parsed at compile time. The returned
string should be wrapped in either () or {}.

=cut

sub orac_parse_arguments {

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
        push( @kv, " &ORAC::Recipe::orac_parse_arguments($argument)" );
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

=end __PRIVATE_METHODS__

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>


=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

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
};


use Starlink::Versions qw/ :Funcs /;

=head1 FUNCTIONS

These recipe runtime functions are provided:

=over 4

=item B<orac_execute_recipe>

Simple wrapper to eval in this namespace in order to execute recipes
without fear of possible contamination of the base recipe namespace.

  $status = orac_execute_recipe( $CURRENT_PRIMITIVE, $recipe, $Frm, $Grp, 
                                 $Cal, $Display, $Mon, $DEBUG, $BATCH);

The recipe is a string to be evaluated. The basic objects have to
be supplied since they can not be set inside the recipe prior to
execution (the stringified objects have no meaning). The debug and
batch variables are passed in as recipe globals.

=cut

# Make these package globals so that we dont have to worry about
# "Variable "$DEBUG" will not stay shared at ..."
# warnings caused by them being used in closures when lexical
our ($BATCH, $DEBUG);

sub orac_execute_recipe {
  my ($CURRENT_PRIMITIVE, $recipe, $Frm, $Grp, $Cal, $Display, $Mon);
  ( $CURRENT_PRIMITIVE, 
    $recipe, $Frm, $Grp, $Cal, $Display, $Mon, $DEBUG, $BATCH) = @_;

  # We need to take into account that %Mon might be a tied object
  # since we can not copy a hash and retain the tie
  # The recipes expect %Mon and not \%Mon (which is what we have)
  # If it is not tied we can proceed as before.
  my %Mon;
  if (tied %$Mon) {
    my $obj = tied %$Mon;
    tie %Mon, ref($obj), $obj; # re-tie
  } else {
    %Mon = %$Mon;
  }

  return eval $recipe;
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>


=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=end __HIDDEN__

=cut

1;
