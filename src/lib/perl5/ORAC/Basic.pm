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

use Starlink::NBS;
require Exporter;
use File::Path;
use Term::ANSIColor;
use File::Copy;
use ORAC::Msg::ADAM::Task;
use ORAC::Msg::ADAM::Control;

use ORAC::General; # General subroutines given to the recipes
use ORAC::Constants qw/:status/;	# 

use IO::File;  # Open and close files
use Cwd; # Current working directory

@ISA = qw(Exporter);

@EXPORT = qw/orac_launch_display orac_connect_display
orac_kill_display orac_execute_recipe orac_read_recipe
orac_parse_recipe orac_exit_normally orac_exit_abnormally
/;

$VERSION = '0.10';

#------------------------------------------------------------------------

# RECIPES beware!! Don't stomp on these:

*Mon = *main::Mon;


=over 4

=cut

# Display specific code

sub orac_launch_display {

  my $dir = $main::orac_dir;
  my $Out = $main::Out;
  
  # Set some P4 environment variables
  $ENV{P4_ROOT} = $ENV{CGS4DR_ROOT};
  $ENV{P4_CONFIG} = $ENV{HOME} . "/cgs4dr_configs";
  $ENV{P4_HOME} = $ENV{P4_ROOT};
  $ENV{P4_EXE}  = $ENV{P4_ROOT};
  $ENV{P4_ICL}  = $ENV{P4_ROOT};
  $ENV{P4_DATA} = $ENV{ORAC_DATA_OUT};
  $ENV{P4_CT}   = $ENV{P4_ROOT} . "/ndf";
  $ENV{P4_HC}   = cwd;
  $ENV{P4_DATE} = $main::ut;
  $ENV{RGDIR}   = $ENV{P4_DATA};
  $ENV{RODIR}   = $ENV{P4_DATA};
  $ENV{RIDIR}   = $ENV{P4_DATA};
  $ENV{ODIR}   = $ENV{P4_DATA};
  $ENV{IDIR}   = $ENV{P4_DATA};


  # Make the CGS4DR scratch directories
  unless (-d $ENV{P4_CONFIG}) {
    unlink $ENV{P4_CONFIG};
    mkdir($ENV{P4_CONFIG}, 0770);
  }

  # Do P4 startup - copy in a default file
  # unless one is there already.
  unless (-e $ENV{P4_CONFIG} . "/default.p4") {
    print colored("Creating a default P4 startup file\n",'red');
    copy ($ENV{P4_ROOT} . "/default.p4", $ENV{P4_CONFIG} . "/default.p4");
  }

  # Now need to edit the standard.p4 so that it uses
  # the reverse of the current PID ($$)
  $ENV{PID} = scalar reverse($$);

  # Copy the default file to a backup
  copy($ENV{P4_CONFIG} . "/default.p4", $ENV{P4_CONFIG} . "/default.p4_bak");

  # Open the template and change the xwindows identifier
  my $default = new IO::File("< $ENV{P4_CONFIG}/default.p4_bak")
    or die "Couldn't open default.p4_bak: $!";

  # Open the output file
  my $output = new IO::File("> $ENV{P4_CONFIG}/default.p4")
    or die "Can't open output file default.p4: $!";

  # Loop over each input line, modify and send to ouput
  foreach my $line (<$default>) {
    $line =~ s/xwindows(\;\d+xwin)?/xwindows\;$ENV{PID}xwin/i;
    print $output $line;
  }

  # Close files
  $default->close;
  $output->close;

  # Now launch P4 using ORAC::Msg module
  $Display = new ORAC::Msg::ADAM::Task("$ENV{PID}_p4", "$ENV{CGS4DR_ROOT}/p4");

  # Open the associated Xwindow (could leave it to P4)
  # Note that the $gwm object disappears as soon as we leave this
  # subroutine
  print colored("Launching GWM display $ENV{PID}xwin...",'blue');
  my $gwm = new Proc::Simple;
  $gwm->start("gwm -colours 128 -gwmname $ENV{PID}xwin -name \'ORACDR:P4 ($ENV{PID}xwin)\'");

  # Pause so that GWM window can be contacted immediately
  sleep 2;
  print colored("Done\n",'blue');

};
#------------------------------------------------------------------------

# Talk to P4 and configure 

sub orac_connect_display {

  my $status;

  # Assume that NBS is named after the toolpid
  my $toolpid = $Display->pid;
  
  $toolpid = scalar reverse ($toolpid);
  my $toolnbname = "p".$toolpid."_plotnb";

  $contact =$Display->contactw;		# ensure contact is made
  unless ($contact) {
    print colored("Unable to contact Display before timeout",'red');
    return;
  }



  # Now configure the noticeboard
  print colored("Configuring P4 NBS ($toolnbname)...",'blue');

  $status = $Display->set(" ","noticeboard","$toolnbname");
  if ($status != ORAC__OK) {
    print colored("Error setting noticeboard name\n",'red');
    return;
  }

  $status = $Display->obeyw("open_nb");
  if ($status != ORAC__OK) {
    print colored ("Error opening noticeboard\n",'red');
    return;
  }

  $status = $Display->obeyw("restore","file=$ENV{P4_CONFIG}/default.p4 port=-1");
  if ($status != ORAC__OK) {
    print colored("Error configuring noticeboard\n",'red');
    return;
  }

  # Print completion message
  print colored("Done\n",'blue');

  # Open local version of noticeboard
  $Nbs = new Starlink::NBS ($toolnbname);

  # Check notice board status
  unless ($Nbs->isokay) {
    print colored("Error opening noticeboard\n",'red');
    return;
  }

  # Set some local values

  $startup = '$ORAC_DIR/images/orac_start';
  nbspoke(".port_0.display_type", "IMAGE");
  nbspoke(".port_0.display_data", "$startup"); 
  nbspoke(".port_1.display_data", '$P4_CT/cgs4');
  nbspoke(".port_2.display_data", '$P4_CT/cgs4');
  nbspoke(".port_3.display_data", '$P4_CT/cgs4');
  nbspoke(".port_4.display_data", '$P4_CT/cgs4');
  nbspoke(".port_5.display_data", '$P4_CT/cgs4');
  nbspoke(".port_6.display_data", '$P4_CT/cgs4');
  nbspoke(".port_7.display_data", '$P4_CT/cgs4');
  nbspoke(".port_8.display_data", '$P4_CT/cgs4');
  nbspoke(".port_0.title", "");
  nbspoke(".port_0.plot_axes","0");

  # Load the colour table and plot the ramp
  $status = $Display->obeyw("lut","port=0");
  if ($status != ORAC__OK) {
    print colored("Error configuring default LUT\n",'red');
    return;
  }


  my $data = nbspeek(".port_0.display_data");  # We know what this is!

  # Check for possible corruption of noticeboard
  if ($data =~ /xwin/) {
    print colored("Error reading startup image from noticeboard\n",'red');
    print colored("P4 noticeboard could be corrupt. Continuing\n",'red');
    $data = $startup;
  }

  # Replace $ with \$ for eval during obeyw()
  $data =~ s/\$/\\\$/g;  

  # Ask P4 to display
  $status = $Display->obeyw("display", "data=$data");
  if ($status != ORAC__OK) {
    print colored("Error displaying startup image\n",'red');
    print colored("Trying to execute: display data=$data\n",'red');
    return;
  }

  $status = $Display->obeyw("status");
  if ($status != ORAC__OK) {
    print colored("Error determining P4 status\n",'red');
    return;
  }

  nbspoke(".port_0.plot_axes", "1");

};

#------------------------------------------------------------------------

sub orac_kill_display {
#    kill(9,$toolpid+1);
#    system("$orac_dir/bin/cgs4dr_nuke");
};
#------------------------------------------------------------------------

sub nbspeek {
    my ($item) = shift(@_);
    my $what = $Nbs->find($item);
    my ($ok,$value) = $what->get;
    return $value;
};

#------------------------------------------------------------------------

sub nbspoke {
    my ($item,$value) = @_;
    my $what = $Nbs->find($item);
    my $ok = $what->put($value);
    return $ok;
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

    print colored ("Orac says: RECIPE ERROR: $@","blue") if ($@);

    # Create an array that matches the line numbers returned by
    # the error message.
    # Note that this line number relates to $block and
    # not @recipe. Need to split $block on new line
    my @new = split(/\n/, $block);

    # If this was a syntax error print out the recipe
    if ($@ =~ /syntax error/) {
      # Extract info from the error message
      $@ =~ /line (\d+),/ && do {
	$num = $1;
	print colored("Error in line $num\n", 'red');
	print colored("Relevant recipe lines (with numbers):\n\n", 'red');

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

    } elsif ($@ =~ /^Died/) {
      # Else check if the recipe died. Usually a die is caused 
      # by a control C from the user.

      print colored("Recipe died during execution\n",'blue');

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

  ($macro,my @arguments)=split(/\s+/,$line);

  %$macro = ();
  foreach $argument (@arguments) {
    ($key,$value)=split("=",$argument);
    $$macro{$key}=$value;
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
    
    
    } elsif ($line =~ /={0}.+->obeyw/) {
    
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


=item orac_check_status

Provides the code for automatic status checking of recipes.

=cut
 
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
# THE END(s)
#------------------------------------------------------------------------


=item orac_exit_normally

Exit handler for oracdr.

=cut

sub orac_exit_normally {

  $message = shift(@_);
  orac_kill_display;
  print colored ("Orac says: $message - Exiting...\n","red");

  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir
  &orac_kill_display;		# Destroy display

  print colored ("\nOrac says: Goodbye\n","red");
  exit;
};

=item orac_exit_abnormally

Exit handler when a problem has been encountered.

=cut

sub orac_exit_abnormally {

  my $signal = shift;

  rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir
  &orac_kill_display;		# Destroy display
  die;
  # die "\n --Signal $signal received--\n";	

};





1;


=back

=head1 AUTHORS

Frossie Economou and Tim Jenness

=cut


#$Log$
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
