#------------------------------------------------------------------------
# ORAC recipe parsing module
#------------------------------------------------------------------------

package ORAC::Basic;

=head1 NAME

ORAC::Basic - recipe parsing and execution subroutines

=head1 SYNOPSIS

  use ORAC::Basic;
  orac_setup_display;
  $rec_arr = orac_read_recipe($recipe, $instrument);
  orac_parse_recipe(\@recipe, $instrument);
  orac_add_code_to_recipe(\@recipe);
  orac_execute_recipe(\@recipe, $Frm, $Grp, $Cal, \%Mon);

=head1 DESCRIPTION

Provides the routines for parsing and executing recipes.

=cut

use Carp;
use vars qw($VERSION @ISA @EXPORT $Display $Batch $DEBUG $Display $Beep
	    $KAPVERSION $KAPVERSION_MAJOR $KAPVERSION_MINOR
	    $KAPVERSION_PATCHLEVEL
	   );

use strict;

# This module requires the Starlink::EMS module to translate
# the facility error status.

require Exporter;
use File::Path;
use File::Copy;

use ORAC::Print;
use ORAC::Display;
use ORAC::LogFile;  # For log file generation
use ORAC::General; # General subroutines given to the recipes
use ORAC::Constants qw/:status/;	# 
use ORAC::TempFile;

use IO::File;  # Open and close files
use Cwd; # Current working directory

eval 'use LWP::Simple qw/$ua get is_success status_message/';
if ($@) {
  orac_warn("The LWP::Simple module is not installed in your perl distribution\n");
  orac_warn("Features of the pipeline requiring HTTP access will not be available\n");
};


@ISA = qw(Exporter);

@EXPORT = qw/
  orac_setup_display
  orac_execute_recipe orac_read_recipe
  orac_parse_recipe orac_exit_normally orac_exit_abnormally
  orac_add_code_to_recipe
  /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$Display = undef;# Display object - only configured if we have a display
                    # may want to turn this into an argument from a highre
                    # level (eg like %Mon)

$Batch   = 0;       # True if we are running in batch mode
$DEBUG   = 0;       # True for extra debugging
$Beep    = 0;       # True if ORAC should make noises


#  ------------- KLUGE ----------------
# Set the Kappa version numbers
# This is required for recipes so that they can know
# which version of kappa they are using for backwards compatibility
# Currently, only sets MINOR release number since this is the
# most important
# Eventually, will use separate Starlink::VERSION module to import
# these variables
# Do not ever make this module dependent on Starlink KAPPA being
# available.

$KAPVERSION = 'V0.0-0';
$KAPVERSION_MAJOR = 0;
$KAPVERSION_PATCHLEVEL = 0;

if (-e "$ENV{KAPPA_DIR}/style.def") {
  $KAPVERSION_MINOR = 13;
} elsif (-e "$ENV{KAPPA_DIR}/kappa_style.def") {
  $KAPVERSION_MINOR = 14;
} else {
  $KAPVERSION_MINOR = 12;
}

#------------------------------------------------------------------------

=head1 FUNCTIONS

The following functions are provided:

=over 4

=item B<orac_setup_display>

Create a new Display object for use by the recipes. This includes
the association of this object with a specific display configuration
file (F<disp.dat>). If a configuration file is not in $ORAC_DATA_OUT
one will be copied there from $ORAC_DATA_CAL (or $ORAC_DIR
if no file exists in $ORAC_DATA_CAL).

If the $DISPLAY environment variable is not set, the display
subsystem will not be started.

There are no return arguments.

=cut

# Simply create a display object
sub orac_setup_display {

  # Check for DISPLAY being set
  unless (exists $ENV{DISPLAY}) {
    warn 'DISPLAY environment variable unset - not starting Display subsystem';
    return;
  }

  # Set this global variable
  $Display = new ORAC::Display;

  # Set the location of the display definition file
  # (we do not currently use NBS for that)

  # It is preferable for this to be instrument specific. The working
  # copy is in ORAC_DATA_OUT. There is a system copy in ORAC_DIR
  # but preferably there is an instrument-specific in ORAC_DATA_CAL
  # designed by the support scientist

  my $systemdisp = $ENV{ORAC_DIR}."/disp.dat";
  my $defaultdisp = $ENV{ORAC_DATA_CAL}."/disp.dat";
  my $dispdef = $ENV{ORAC_DATA_OUT}."/disp.dat";


  unless (-e $defaultdisp) {$defaultdisp = $systemdisp};

  unless (-e $dispdef) {copy($defaultdisp,$dispdef)};

  # Set the display filename 
  $Display->filename($dispdef);

  # GUI launching goes here....

  # orac_err('GUI not launched');
}



sub nbspeek {
  orac_err "NBSPEEK - THIS COMMAND IS NOT SUPPORTED";
};

#------------------------------------------------------------------------

sub nbspoke {
    orac_err "NBSPEEK - THIS COMMAND IS NOT SUPPORTED";
};

#------------------------------------------------------------------------

=item B<orac_execute_recipe>(reciperef, Frame, Group, Cal, Mon)

Executes the recipes stored in $reciperef (an Array reference).
Also needs the current frame, group and calibration objects
as well as the hash containing all the messaging objects.

The following classes are avaiable to primitive writers:

  ORAC::Print, ORAC::LogFile, ORAC::General, ORAC::Constants,
  ORAC::TempFile and IO::File.

Other classes can be loaded from within the recipe as needed.

The variables accessible to the recipe are:

  $Grp - the current group.
  $Frm - the current frame
  $Cal - the calibration object
  $Display - the display system (undefined if display not required)

=cut


sub orac_execute_recipe {

  my ($reciperef,$Frm,$Grp,$Cal,$Mon) = @_;

  my @recipe = @$reciperef;		# dereference recipe
  my %Mon    = %{$Mon};                 # Dereference monolith hash

  my $block = join("",@recipe);

  # Want to make sure that perl warnings are turned off
  # when evaluating recipes - control via the -warn parameter
  # local $^W = 0;

  # Execute the recipe
  my $status = eval $block;

  # Check for an error
  if ($@) {

    # Since we have an error we can not trust the current
    # frame to be fully reduced. We therefore set its state
    # to bad so that it will be removed from Groups
    # Turn this feature off for now - more discussion required
    # $Frm->isgood(0);

    # Report error
    orac_err ("RECIPE ERROR: $@","blue");

    # Create an array that matches the line numbers returned by
    # the error message.
    # Note that this line number relates to $block and
    # not @recipe. Need to split $block on new line
    my @new = split(/\n/, $block);

    # If this was a syntax error print out the recipe
    if ($@ =~ /syntax error|object method/) {
      # Extract info from the error message
      $@ =~ /line (\d+)/ && do {
	my $num = $1;
	orac_err("Error in line $num\n", 'red');
	orac_err("Relevant recipe lines (with numbers):\n\n", 'red');

	# Calculate number of lines to print
	my $inc = 15;
	my $start = ($num > $inc ? $num - $inc : 0 );
	my $end   = ($num < $#recipe - $inc ? $num + $inc : $#recipe);

	# Print out the relevant chunk with line numbers
	for (my $i=$start; $i < $end; $i++) {
	  orac_print("$i: ", 'blue');
          orac_print("$new[$i]\n", 'red');
	}
	orac_err("End recipe dump\n\n",'blue');
      };

    } elsif ($@ =~ /^Died/) {
      # Else check if the recipe died. Usually a die is caused 
      # by a control C from the user.

      orac_err("Recipe died during execution\n");

    }

    # If debugging is turned on, dump the recipe on error
    if ($DEBUG) {
      my $fh = new IO::File("> ORACDR_RECIPE.dump");
      print $fh join('',@recipe). "\n";
      orac_err("Recipe contents dumped to ORACDR_RECIPE.dump\n")
    }


    # Exit from the pipeline
    # Do this until we debug everything
    orac_exit_normally("Exiting due to error"); 
  }

};


#------------------------------------------------------------------------

=item orac_read_recipe(recipe, instrument)

Reads the specified recipe from the recipe directory.
An array reference containing the recipe is returned.

The second argument specifies the name of the instrument specific
directory that should be searched.

The location of the recipe is determined first by looking in the
directory specified with $ENV{ORAC_RECIPE_DIR} and if none exists
the ORAC repository is searched ($ENV{ORAC_DIR}/recipes/instrument).
If the recipe can be found in neither location the program aborts.

=cut

sub orac_read_recipe {

  use strict; # For Frossie :-)

  croak 'Usage: orac_read_recipe(recipe_name, instrument_name)'
    unless scalar(@_) == 2;

  my $recipe = shift;
  my $instrument = shift;
  
  # Since this is the only routine that needs to know the recipe
  # directory we can implement search paths

  my $recipe_dir = undef; # Keep track of what we have found

  # First see if the environment variable $ORAC_RECIPE_DIR has been
  # set - we should look here first.
  if (exists $ENV{ORAC_RECIPE_DIR}) {
    $recipe_dir = $ENV{ORAC_RECIPE_DIR} if -e "$ENV{ORAC_RECIPE_DIR}/$recipe";
  } 

  # Now look in ORAC_DIR for recipes
  if (exists $ENV{ORAC_DIR} && ! defined $recipe_dir) {

    my $tmp = "$ENV{ORAC_DIR}/recipes/$instrument";
    $recipe_dir = $tmp if -e "$tmp/$recipe";

  } 

  # No environment variables found - check in current directory
  # This shouldnt happen in oracdr
  $recipe_dir = '.' if (-e $recipe  && ! defined $recipe_dir);

  # If recipe dir is still set to NONE then we could not find the file
  croak "Error - could not find recipe $recipe in any of the recipe search paths"
    unless defined $recipe_dir;

#  open(RECIPE,${main::recipe_dir}.$recipe) || croak "No such recipe $recipe\n";;
  my $fh = new IO::File("< $recipe_dir/$recipe") || 
    croak "Error opening $recipe_dir/$recipe : $!";

  my @recipe = <$fh>;

  return(\@recipe);

};

#------------------------------------------------------------------------


=item orac_read_primitive(primitive, instrument)

Reads the specified primitive from the recipe directory.
An array reference containing the primitive is returned.

The second argument specifies the name of the instrument specific
directory that should be searched.

The location of the recipe is determined first by looking in the
directory specified with $ENV{ORAC_PRIMITIVE_DIR} and if none exists
the ORAC repository is searched ($ENV{ORAC_DIR}/primitives/instrument).
If the recipe can be found in neither location the program aborts.

=cut

sub orac_read_primitive {

  croak 'Usage: orac_read_primitive(primitive_name, instrument_name)'
    unless scalar(@_) == 2;

  my $primitive = shift;
  my $instrument = shift;
  
  # Since this is the only routine that needs to know the recipe
  # directory we can implement search paths

  my $prim_dir = undef; # Keep track of what we have found

  # First see if the environment variable $ORAC_PRIMITIVE_DIR has been
  # set - we should look here first.
  if (exists $ENV{ORAC_PRIMITIVE_DIR}) {
    $prim_dir = $ENV{ORAC_PRIMITIVE_DIR} if -e "$ENV{ORAC_PRIMITIVE_DIR}/$primitive";
  } 

  # Now look in ORAC_DIR for primitives
  if (exists $ENV{ORAC_DIR} && ! defined $prim_dir) {

    my $tmp = "$ENV{ORAC_DIR}/primitives/$instrument";
    $prim_dir = $tmp if -e "$tmp/$primitive";

  } 

  # No environment variables found - check in current directory
  # This shouldnt happen in oracdr
  $prim_dir = '.' if (-e $primitive  && ! defined $prim_dir);

  # If recipe dir is still set to NONE then we could not find the file
  croak "Error - could not find primitive $primitive in any of the primitive search paths"
    unless defined $prim_dir;

  my $fh = new IO::File("< $prim_dir/$primitive") || 
    croak "Error opening $prim_dir/$primitive : $!";

  my @primitive = <$fh>;

  return(\@primitive);

};

#------------------------------------------------------------------------

=item orac_parse_arguments(line)

Parses argument lists on primitive calls.
Converts a string of form 'arg1=value1 arg2=value2...'
to a hash.

  my %hash = orac_parse_arguments($string);

=cut

sub orac_parse_arguments {

  my $line = shift;
  my %hash = ();

  return %hash unless defined $line;
  
  # Split the string on space
  my @arguments = split(/\s+/,$line);

  # Loop over each string
  foreach my $argument (@arguments) {
    # Split each argument on equals
    my ($key,$value) = split("=",$argument);
    $hash{$key} = $value if defined $value;
  }

  return %hash;
}

#------------------------------------------------------------------------

=item orac_parse_recipe(array_reference, instrument)

Parses a recipe, reading in the necessary primitives.

The recipe is parsed in place (ie using the array reference).
The instrument name is supplied so that the directory name
containing the primitives can be constructed.

An array reference to the parsed array is returned.

=cut

sub orac_parse_recipe {

  croak 'Usage: orac_parse_recipe(\@recipe, instrument_name)'
    unless scalar(@_) == 2;

  croak 'orac_parse_recipe: First argument must be an array reference!'
    unless ref($_[0]) eq 'ARRAY';


  my $recipe = shift;
  my $instrument = shift;

  my @parsed = (); # Create output array
  
  my ($line);
  
  foreach $line (@$recipe) {
    
    if ($line =~ /^\s*_/) {
      $line =~ s/^\s+//;	# zap leading blanks
      $line =~ s/\s*$//;        # Zap trailing blanks
      my ($macro,$rest) = split(/\s+/,$line,2);
      $rest = '' unless defined $rest; # -w protection for next line

      # Parse any arguments. Add a line that runs orac_parse_arguments
      # on $rest and sets a hash called %macro
      # $rest is a string of form "arg1=value arg2=value" that is 
      # converted to a hash at runtime by orac_parse_arguments
      push(@parsed,
	   'my %'."$macro = orac_parse_arguments(\"$rest\");\n");
    
      # read in primitive
      my $lines_ref = orac_read_primitive($macro, $instrument);

      # Store lines - making sure we create a separate scope
      push(@parsed,"\n{\nmy \$ORAC_PRIMITIVE=\"$macro\";\n\n",@$lines_ref,"\n}\n");
      

      } else {
	# Just push the line on as is
	push (@parsed, $line);

      }

  }

  return(\@parsed);

}

=item orac_add_code_to_recipe(\@recipe)

Post processes the recipe adding status checking code.

Argument is a reference to an array containing the recipe
and the return argument is a reference to an array containing
the processed recipe.

=cut


sub orac_add_code_to_recipe {
  
  croak 'Usage: orac_add_code_to_recipe(\@recipe)'
    if scalar(@_) != 1;

  croak 'orac_add_code_to_recipe: First argument must be an array reference!'
    unless ref($_[0]) eq 'ARRAY';

  my $recipe = shift;
  my @processed = ();
  
  my ($line);
  
  foreach $line (@$recipe) {
    
    if ($line =~ /->obeyw(.*)/) {
      
      my $arguments = $1;
      
      $arguments =~ s/\"/ /g;


      # Add the following debug line if the obeyw is not commented out
      # Debug line if DEBUG is true
      if ($DEBUG && $line !~ /\#.+->obeyw/) {
	push(@processed,'orac_debug( $Frm->number . ":".$ORAC_PRIMITIVE .'."\":\t$arguments\n\");\n")
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
	      'my $OBEYW_STATUS = ' .$line,
	      &orac_check_obey_status($line),
	      "\n}\n",
	     );
	
      } else {
	# Just push the line on as is
	push (@processed, $line);
      }
      
    } elsif ($line =~ /\$ORAC_STATUS/) {
      # Put on the current line
      push (@processed, $line);      
      # Add the status checking code
      push (@processed, &orac_check_status);
      
    } else {      
      push(@processed,$line);
    }
  
  };

  return(\@processed);
}




# This is the status checking code

# Subroutine to add error checking 
# Relies on $ORAC_STATUS being available


=item orac_check_status

Provides the code for automatic status checking of recipes.

=cut
 
sub orac_check_status {
 
  my @newlines =  (' if ($ORAC_STATUS != ORAC__OK) {' ,
		   '   orac_err ("Error in pipeline\n"); ' ,
		   '   return $ORAC_STATUS; ' ,
		   ' } ');

  # Add newlines to each line of the text so that it appears 
  # correctly when recipe is listed
  map { $_ .= "\n" } @newlines;
  
  # Return the extra lines.
  return @newlines;
  
}

=item orac_check_obey_status

Provides the code for automatic status checking of obeyw()
in recipes.

=cut


# Subroutine to check status of OBEYW

sub orac_check_obey_status {

  my ($monolith, $task, $args);

  # Get the name of the monlith from the obeyw
  my $line = shift;

  # Do the regexp separately so that we can handle the situation
  # where the monolith path is not stored in a hash
  $line =~ /\{[\'\"]*(\w+)[\'\"]*\}->obeyw/ && ($monolith = $1);
  $line =~ /->obeyw\(\"(\w+)\"/ && ($task = $1);
  $line =~ /->obeyw\(\"\w+\"\s*,\s*\"(.+)\"/ && ($args = $1);
  $args = '(No arguments)' unless defined $args;
  $monolith = '(None!!)' unless defined $monolith;
  $task = '(Unknown)' unless defined $task;

  # Need to be careful of what gets expanded when the
  # lines are added to the recipe and what gets expanded 
  # when the recipe is executed.

  my @statuslines = (
		     'if ($OBEYW_STATUS != ORAC__OK) {',
		     "  orac_err (\"Error in obeyw to monolith $monolith (task=$task): \$OBEYW_STATUS\\n\");" ,
		     '  my $obeyw_args = "'. $args . '";',
		     '  orac_print("Arguments were: ","blue");',
                     '  orac_print("$obeyw_args\n\n","red"); ',
		     '  return $OBEYW_STATUS;',
		     '}'
		    );

  # Add newlines to each line of the text so that it appears 
  # correctly when recipe is listed
  map { $_ .= "\n" } @statuslines;
  
  # Return the extra lines.
  return @statuslines;

}


#------------------------------------------------------------------------
# THE END(s)
#------------------------------------------------------------------------


=item orac_exit_normally

Exit handler for oracdr.

=cut

sub orac_exit_normally {
  my $message = '';
  $message = shift if @_;

  orac_print ("$message - Exiting...\n","red");

  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir

  # Ring a bell when exiting if required
  if ($Beep) {
    for (1..5) {print STDOUT chr(7); select undef,undef,undef,0.2}
  }

  orac_print ("\nOrac says: Goodbye\n","red");
  exit;
};

=item orac_exit_abnormally

Exit handler when a problem has been encountered.

=cut

sub orac_exit_abnormally {
  my $signal = '';
  $signal = shift if @_;

  # Dont delete tree since this routine is called from INSIDE recipes
#  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir

  # ring my bell, baby
  if ($Beep) {
  for (1..10) {print STDOUT chr(7); select undef,undef,undef,0.2}
  }

  die "\nAborting from ORACDR - $signal received";
  # die "\n --Signal $signal received--\n";	

};





1;


=back

=head1 GLOBAL VARIABLES

This module has the following package variables that can be modified
externally:

=over 4

=item * $Display

The object associated with the ORAC Display system. This
is of class ORAC::Display. The display system has not been
initialised if this variable has a value of undef. Primitives
should check to see that the variable is defined before
attempting to use it. This variable is set via the 
orac_setup_display() subroutine. Do not modify this variable.

=item * $DEBUG

This flag can be used to turn on some debugging features.

=item * $Batch

Flag to indicate whether the groups have been populated before
the recipe is executed (ie whether the pipeline is running in
batch mode or not).

=item * $KAPVERSION

A set of version variables are available for support of different
Starlink KAPPA versions as a convenience to recipe writers. These
variables are only defined if KAPPA is present on the
system. Variables are present for the version string ($KAPVERSION),
the major version ($KAPVERSION_MAJOR), minor version
($KAPVERSION_MINOR) and patchlevel ($KAPVERSION_PATCHLEVEL). Currently
only the KAPPA major version is set to something useful. This
behaviour may change in a future release but not in such a way that
KAPPA will be required for running recipes.

For example, if $KAPVERSION is 'V0.14-3', the major version
is 0, minor version is 14 and patchlevel is 3.

=back

These variables are visible to recipes but should not be modified
by them.

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou and Tim Jenness

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut


#$Log$
#Revision 1.45  2000/02/01 02:49:26  timj
#Add $KAPVERSION
#
#Revision 1.44  2000/01/29 02:29:11  timj
#Brings pods up to release standard.
#
#Revision 1.43  2000/01/26 00:59:19  timj
#Fix -w warnings.
#
#Revision 1.42  1999/09/15 20:42:47  timj
#Add support for beeping on exit and error messages
#
#Revision 1.41  1999/09/15 02:55:15  frossie
#add beeps to exit normally and abnormally
#
#Revision 1.40  1999/07/27 00:12:40  timj
#Add LWP::Simple
#
#Revision 1.39  1999/06/25 02:26:45  timj
#Improve debugging output in add_code_to_recipe.
#Add $ORAC_PRIMITIVE to recipe code.
#
#Revision 1.38  1999/05/13 00:43:24  timj
#Check for $DISPLAY env var before allowing Display system to be started.
#
#Revision 1.37  1999/05/12 04:25:17  timj
#Add ORAC::TempFile.
#Expand docs for orac_execute_recipe
#
#Revision 1.36  1999/05/10 23:32:29  timj
#Make $Display a package global
#
#Revision 1.35  1999/05/10 19:35:30  timj
#Small documentation update
#
#Revision 1.34  1999/04/28 18:54:32  timj
#Fix so that ORAC_DEBUG is not used for commented obeyw's
#
#Revision 1.33  1999/04/22 22:48:44  timj
#Fix some -w warnings.
#Allow -w in recipes
#
#Revision 1.32  1999/04/22 01:40:54  timj
#Place all primitives in their own block
#
#Revision 1.31  1999/04/21 21:36:04  timj
#Fix -w
#Add recipe dump on error for -debug
#
#Revision 1.30  1999/04/21 00:48:13  timj
#Turn on use strict
#
#Revision 1.29  1999/03/15 19:37:52  timj
#Use ORAC::Logifle
#
#Revision 1.28  1999/02/18 03:11:29  timj
#Add $Batch.
#Change 'local' to 'my'
#
#Revision 1.27  1998/09/23 23:41:05  frossie
#Add "search path" for disp.data
#
#Revision 1.26  1998/09/17 03:28:46  timj
#- Use array references throughout recipe parsing and execution
#- Support ORAC_RECIPE_DIR and ORAC_PRIMITIVE_DIR
#
#Revision 1.25  1998/09/15 12:28:47  frossie
#Remove debug line
#
#Revision 1.24  1998/08/07 02:25:52  frossie
#Add orac_add_code_to_recipe subroutine. Put in it the automatic error
#checking code, and remove it from orac_parse_recipe so that it is
#executed only after recursive parsing has ceased.
#
#Add orac_debug code to orac_add_code_to_recipe
#
#Revision 1.23  1998/08/06 21:08:54  frossie
#Add orac_debug in auto status checking
#
#Revision 1.22  1998/07/09 03:54:13  timj
#Add orac_print.
#Improve obeyw string handling.
#Remove P4 display commands.
#Add object initialisation for new display system.
#
#Revision 1.21  1998/06/29 05:20:31  timj
#Cause orac_exit_abnormally to tell us that it is being called.
#Make sure that noticeboard is reset even if display fails to
#start properly.
#
#Revision 1.20  1998/06/29 04:17:27  timj
#Startup P4 directly.
#Remove orac_parse_obslist
#
#Revision 1.19  1998/05/22 03:24:01  timj
#Stop pipeline if 'Die' detected in eval.
#
#Revision 1.18  1998/05/21 06:26:54  timj
#Add support for ranges in -list by adding orac_parse_obslist
#
#Revision 1.17  1998/05/21 04:05:01  timj
#Remove debug print statements from connect_display
#
#Revision 1.16  1998/05/21 03:50:12  timj
#Change Display startup to use Proc::Simple
#
#Revision 1.15  1998/04/23 01:48:02  timj
#Improve the OBEYW error checking.
#
#Revision 1.14  1998/04/21 23:44:00  timj
#Dump incorrect lines to screen when a syntax error is encountered
#in a recipe.
#
#Also shut down pipeline when syntax error encountered.
#
#Revision 1.13  1998/04/17 19:28:42  timj
#Make fix to the orac_parse_arguments push (ie add a \n
#to the line pushed onto the recipe).
#
#Remove final reference to adamtask_exit.
#
#Print full recipe when a syntax error is reported in a recipe.
#
#Revision 1.12  1998/04/15 02:41:36  frossie
#Move ams_init to appropriate place
#
#Revision 1.11  1998/04/14 21:39:43  frossie
#Change launch display to use new Msg hierarchy
#
#Revision 1.10  1998/04/14 21:08:28  frossie
#Change ORAC_ACT_COMPLETE to ORAC_OK for consistency (ADAM module now
#returns 0 for good status under all circumstances)
#
#Remove dependancy on specific messaging system
#
#Revision 1.9  1998/04/10 00:27:09  timj
#Include ORAC::General
#
#Revision 1.8  1998/04/04 06:46:22  frossie
#Introduce Frm Grp and Cal objects
#
#Revision 1.7  1998/03/17 18:54:31  frossie
#*** empty log message ***
#
