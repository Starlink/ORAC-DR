#------------------------------------------------------------------------
# ORAC module
#------------------------------------------------------------------------

package ORAC::Basic;

=head1 NAME

ORAC::Basic - generic ORAC subroutines

=head1 SYNOPSIS

  use ORAC::Basic;
  orac_parse_recipe

=head1 DESCRIPTION

Provides the routines for parsing and executing recipes.

=cut

use Carp;
use vars qw($VERSION @ISA @EXPORT $Display $Nbs);

# This module requires the Starlink::EMS module to translate
# the facility error status.

require Exporter;
use File::Path;
use File::Copy;
use ORAC::Print;
use ORAC::Msg::ADAM::Task;
use ORAC::Msg::ADAM::Control;
use ORAC::Display;

use Term::ANSIColor;  # Need this until the primitives can get rid of color
use ORAC::General; # General subroutines given to the recipes
use ORAC::Constants qw/:status/;	# 

use IO::File;  # Open and close files
use Cwd; # Current working directory

@ISA = qw(Exporter);

@EXPORT = qw/
  orac_setup_display
  orac_execute_recipe orac_read_recipe
  orac_parse_recipe orac_exit_normally orac_exit_abnormally
  orac_add_code_to_recipe
  /;

$VERSION = '0.10';

$Display = undef;   # Display object - only configured if we have a display

#------------------------------------------------------------------------

# RECIPES beware!! Don't stomp on these:

# This accesses the global variable for the monoliths
*Mon = *main::Mon;


=over 4

=cut

# Simply create a display object
sub orac_setup_display {

  # Set this global variable
  $Display = new ORAC::Display;

  # Set the location of the display definition file
  # (we do not currently use NBS for that)
#  my $dispdef = "/tmp/orac_disp$$";
  my $dispdef  = $ENV{ORAC_DIR} . "/disp.dat";  # Kludge
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

=item orac_executre_recipe(reciperef, Frame, Group, Cal)

Executes the recipes stored in $reciperef (an Array reference).
Also needs the current frame, group and calibration objects.

=cut


sub orac_execute_recipe {

  local($reciperef,$Frm,$Grp,$Cal) = @_;
  local(@recipe) = @$reciperef;		# dereference recipe

  my $block = join("",@recipe);
  my $status = eval $block;

  # Check for an error
  if ($@) {

    orac_err ("RECIPE ERROR: $@","blue") if ($@);

    # Create an array that matches the line numbers returned by
    # the error message.
    # Note that this line number relates to $block and
    # not @recipe. Need to split $block on new line
    my @new = split(/\n/, $block);

    # If this was a syntax error print out the recipe
    if ($@ =~ /syntax error|object method/) {
      # Extract info from the error message
      $@ =~ /line (\d+)/ && do {
	$num = $1;
	orac_err("Error in line $num\n", 'red');
	orac_err("Relevant recipe lines (with numbers):\n\n", 'red');

	# Calculate number of lines to print
	$inc = 10;
	$start = ($num > $inc ? $num - $inc : 0 );
	$end   = ($num < $#recipe - $inc ? $num + $inc : $#recipe);

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

    # Exit from the pipeline
    # Do this until we debug everything
    orac_exit_normally("Exiting due to error"); 
  }

};


#------------------------------------------------------------------------

=item orac_read_recipe(recipe)

Reads the specified recipe from the recipe directory.
An array containing the recipe is returned.

=cut

sub orac_read_recipe {

  my $recipe = shift;
  my  (@arguments) = @_;

  open(RECIPE,${main::recipe_dir}.$recipe) || croak "No such recipe $recipe\n";;

  my (@recipe) = <RECIPE>;

  close(RECIPE);

  return(@recipe);

};


#------------------------------------------------------------------------

=item orac_parse_arguments(line)

Parses argument lists on primitive calls.

=cut

sub orac_parse_arguments {

  local($line) = shift(@_);

  ($macro,my @arguments) = split(/\s+/,$line);

  %$macro = ();
  foreach $argument (@arguments) {
    ($key,$value) = split("=",$argument);
    $$macro{$key} = $value;
  };

};

#------------------------------------------------------------------------

=item orac_parse_recipe(array)

Parses a recipe, reading in the necessary primitives and
adding automatic error checking code.
An array containing the full recipe is returned.

=cut

sub orac_parse_recipe {
  
  local(@recipe) = @_;
  my(@parsed);
  
  my ($line);
  
  foreach $line (@recipe) {
    
    if ($line =~ /^\s*_/) {
      $line =~ s/^\s+//g;	# zap leading blanks
      ($macro,@rest) = split(/\s+/,$line);
      # read in primitive
      open(DICTIONARY,$ {main::dictionary_dir}.$macro) || 
	croak "No translation for $line\n";    
      @lines = <DICTIONARY>;
      close(DICTIONARY);
      $parse = join(" ",$macro,@rest);
      push(@parsed,"orac_parse_arguments(\"$parse\");\n");
    
    #       # store arguments
    #       %$macro = ();
    #       foreach $argument (@arguments) {
    #         ($key,$value)=split("=",$argument);
    #         $$macro{$key}=$value;
    #       };
    
      push(@parsed,@lines);
      

      } else {
	# Just push the line on as is
	push (@parsed, $line);

      }

  }

  return(@parsed);

}


sub orac_add_code_to_recipe {
  
  local(@recipe) = @_;
  my(@processed);
  
  my ($line);
  
  foreach $line (@recipe) {
    
    if ($line =~ /->obeyw(.*)/) {
      
      my $arguments = $1;
      
      $arguments =~ s/\"/ /g;
      push(@processed,"orac_debug(\"$arguments\n\");\n");

      #    } elsif ($line =~ /={0}.+->obeyw/) { # old line
      
      # Now check to see whether it starts with a comment character
      # Note that the xemacs syntac recognition does not understand #
      # in a pattern match
      # or if somebody has put an equals sign in and is checking it
      # themselves.
      if ($line !~ /(\#|=).+?->obeyw/x) {
	
	# Now add the OBEYW status checking lines
	# prepending the OBEYW_STATUS line
	push (@processed, '$OBEYW_STATUS = ' .$line);
	push (@processed, &orac_check_obey_status($line));
	
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

  return(@processed);
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

  my ($monolith, $task);

  # Get the name of the monlith from the obeyw
  my $line = shift;

  # Do the regexp separately so that we can handle the situation
  # where the monolith path is not stored in a hash
  $line =~ /\{(\w+)\}->obeyw/ && ($monolith = $1);
  $line =~ /->obeyw\(\"(\w+)\"/ && ($task = $1);
  $line =~ /->obeyw\(\"\w+\"\s*,\s*\"(.+)\"/ && ($args = $1);

  # Need to be careful of what gets expanded when the
  # lines are added to the recipe and what gets expanded 
  # when the recipe is executed.

  my @statuslines = (
		     'if ($OBEYW_STATUS != ORAC__OK) {',
		     "  orac_err (\"Error in obeyw to monolith $monolith (task=$task): \$OBEYW_STATUS\\n\");" ,
		     '  $obeyw_args = "'. $args . '";',
		     '  orac_print("Arguments were: ","blue");',
                     '  orac_print("$obeyw_args\n\n","red"); ',
		     '  return $OBEYW_STATUS;',
		     "}"
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

  $message = shift(@_);
  orac_print ("$message - Exiting...\n","red");

  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir

  orac_print ("\nOrac says: Goodbye\n","red");
  exit;
};

=item orac_exit_abnormally

Exit handler when a problem has been encountered.

=cut

sub orac_exit_abnormally {

  my $signal = shift;

  # Dont delete tree since this routine is called from INSIDE recipes
#  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir
  die "\nAborting from ORACDR - $signal received";
  # die "\n --Signal $signal received--\n";	

};





1;


=back

=head1 AUTHORS

Frossie Economou and Tim Jenness

=cut


#$Log$
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
