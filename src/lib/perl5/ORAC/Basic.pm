#------------------------------------------------------------------------
# ORAC module
#------------------------------------------------------------------------

package ORAC::Basic;

use Carp;
use vars qw($VERSION @ISA @EXPORT);

# This module requires the Starlink::EMS module to translate
# the facility error status.

use Starlink::NBS;
require Exporter;
use File::Path;
use Term::ANSIColor;
use File::Copy;
use ORAC::Msg::ADAM::Task;

use ORAC::General; # General subroutines given to the recipes
use ORAC::Constants qw/:status/;	# 

@ISA = qw(Exporter);

@EXPORT = qw/orac_launch_display orac_connect_display
orac_kill_display orac_execute_recipe orac_read_recipe
orac_parse_recipe orac_exit_normally orac_exit_abnormally/;



#------------------------------------------------------------------------

# RECIPES beware!! Don't stomp on these:

*Mon = *main::Mon;

sub orac_launch_display {


# launch display, classic fork trick
    unless ($toolpid = fork) {
	unless (fork) {
    $ENV{PID} = "$$";
	    exec "${main::orac_dir}/p4/p4_tcl $main::Out 970815 ndf";
	    die "no exec: $!";
	    exit 0;
	}
	exit 0;
    }
    waitpid($toolpid,0);
};
#------------------------------------------------------------------------

sub orac_connect_display {

#    chomp($toolpid = <>);
    $toolpid = scalar reverse ($toolpid+1);
    $toolname = $toolpid."_p4";
    $toolnbname = "p".$toolpid."_plotnb";
    print "noticeboard is $toolnbname\n";
    $Display = new ORAC::Msg::ADAM::Task($toolname);
    $Display->contactw;		# ensure contact is made
#    $Display->obeyw("verbose") unless ($main::opt_quiet);
    $Nbs = new Starlink::NBS ($toolnbname);
};

#------------------------------------------------------------------------

sub orac_kill_display {
#    kill(9,$toolpid+1);
#    system("$orac_dir/bin/cgs4dr_nuke");
};
#------------------------------------------------------------------------

sub nbspeek {
    local($item) = shift(@_);
    $what = $Nbs->find($item);
    ($ok,$value) = $where->get;
    return $value;
};

#------------------------------------------------------------------------

sub nbspoke {
    local($item,$value) = @_;
    $what = $Nbs->find($item);
    $ok = $what->put($value);
};

#------------------------------------------------------------------------
sub orac_execute_recipe {

  local($reciperef,$Frm,$Grp,$Cal) = @_;
  local(@recipe) = @$reciperef;		# dereference recipe

  $block = join("",@recipe);
  eval $block;

  # Check for an error
  print colored ("Orac says: RECIPE ERROR: $@","blue") if ($@);

  # If this was a syntax error print out the recipe
  if ($@ =~ /syntax error/) {
    # Extract info from the error message
    $@ =~ /line (\d+),/ && do {
      $num = $1;
      print colored("Error in line $num\n", 'red');
      print colored("Relevant recipe lines (with numbers):\n\n", 'red');

      # Note that this line number relates to $block and
      # not @recipe. Need to split $block on new line
      my @new = split(/\n/, $block);

      # Calculate number of lines to print
      $inc = 10;
      $start = ($num > $inc ? $num - $inc : 0 );
      $end   = ($num < $#recipe - $inc ? $num + $inc : $#recipe);

      # Print out the relevant chunk with line numbers
      for (my $i=$start; $i < $end; $i++) {
	print colored("$i: ", 'blue') . colored("$new[$i]\n", 'red');
      }
      print colored("End recipe dump\n\n",'blue');
    };

    orac_exit_normally; # Do this until we debug everything
  }

};


#------------------------------------------------------------------------
sub orac_read_recipe {

local $recipe = shift(@_);
local (@arguments) = @_;

open(RECIPE,${main::recipe_dir}.$recipe) || croak "No such recipe $recipe\n";;

my (@recipe) = <RECIPE>;

close(RECIPE);

return(@recipe);

};


#------------------------------------------------------------------------

sub orac_parse_arguments {

local($line) = shift(@_);

($macro,my @arguments)=split(/\s+/,$line);

%$macro = ();
foreach $argument (@arguments) {
  ($key,$value)=split("=",$argument);
  $$macro{$key}=$value;
};

};

#------------------------------------------------------------------------

sub orac_parse_recipe {
  
  local(@recipe) = @_;
  my(@parsed);
  
  my ($line);
  
  foreach $line (@recipe) {
    
    if ($line =~ /^\s*_/) {
      $line =~ s/^\s+//g;	# zap leading blanks
      ($macro,@rest)=split(/\s+/,$line);
      # read in primitive
      open(DICTIONARY,${main::dictionary_dir}.$macro) || 
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
    
    
    } elsif ($line =~ /={-1}.+->obeyw/) {
    
      # This is an OBEYW status
      # and assumes that all OBEYW commands are dealt with
      # by this routine implicitly (ie the RECIPE writer
      # should never check for status from an OBEYW
      push (@parsed, '$OBEYW_STATUS = ' .$line);
      push (@parsed, &orac_check_obey_status($line));
      
      # Now check for a different kind of status
      # If the recipe writer uses $ORAC_STATUS
      # Then we can add some lines immediately after to check
      # this status (0 is good as for Starlink)
    } elsif ($line =~ /\$ORAC_STATUS/) {
    
      # Put on the current line
      push (@parsed, $line);
      
      # Add the status checking code
      push (@parsed, &orac_check_status);
      
    } else {
      
      push(@parsed,$line);
    
    }
  
  };

  return(@parsed);
}


# This is the status checking code

# Subroutine to add error checking 
# Relies on $ORAC_STATUS being available
 
sub orac_check_status {
 
  my @newlines =  (' if ($ORAC_STATUS != ORAC__OK) {' ,
		   '   print colored ("Error in pipeline\n","red"); ' ,
		   '   return $ORAC_STATUS; ' ,
		   ' } ');

  # Add newlines to each line of the text so that it appears 
  # correctly when recipe is listed
  map { $_ .= "\n" } @newlines;
  
  # Return the extra lines.
  return @newlines;
  
}

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
		     "  print colored (\"Error in obeyw to monolith $monolith (task=$task): \$OBEYW_STATUS\\n\",\"red\");" ,
		     '  $obeyw_args = "'. $args . '";',
		     '  print colored("Arguments were: ","blue") . colored("$obeyw_args\n\n","red"); ',
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



#------------------------------------------------------------------------
# THE END(s)
#------------------------------------------------------------------------


sub orac_exit_normally {

    $message = shift(@_);
    orac_kill_display;
    print colored ("Orac says: $message - Exiting...\n","red");

    &orac_kill_display;		# Destroy display

    print colored ("\nOrac says: Goodbye\n","red");
    exit;
};

sub orac_exit_abnormally {

my $signal = shift;

rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir
&orac_kill_display;		# Destroy display
die;
# die "\n --Signal $signal received--\n";	

};


1;

#$Log$
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
