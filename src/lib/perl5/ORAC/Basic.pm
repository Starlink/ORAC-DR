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
use Starlink::ADAMTASK;



@ISA = qw(Exporter);

@EXPORT = qw/orac_launch_display orac_connect_display
orac_kill_display orac_execute_recipe orac_read_recipe
orac_parse_recipe orac_exit_normally orac_exit_abnormally/;

#------------------------------------------------------------------------

use vars qw($ORAC_ACT_COMPLETE $ORAC__OK);

# Set these from the ADAMTASK modules correctly at some point
$ORAC_ACT_COMPLETE = 142115659;
$ORAC__OK = 0;


# RECIPES beware!! Don't stomp on these:

*Hdr = *main::Header;
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
    $Display = new Starlink::ADAMTASK($toolname);
    $Display->contactw;		# ensure contact is made
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

local($reciperef,$argsref) = @_;
local(@recipe) = @$reciperef;		# dereference recipe
local(%args) = %$argsref;		# dereference arguments

$block = join("",@recipe);
eval $block;
print "Orac says: RECIPE ERROR: $@" if ($@);
return \%args;

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

sub orac_parse_recipe {
  
  local(@recipe) = @_;
  my(@parsed);

  my ($line);
  
  foreach $line (@recipe) {

    if ($line =~ /^_/) {
      ($macro,@arguments)=split(/\s+/,$line);
      # read in primitive
      open(DICTIONARY,${main::dictionary_dir}.$macro) || 
	croak "No translation for $line\n";    
      @lines = <DICTIONARY>;
      close(DICTIONARY);

      # store arguments
      %$macro = ();
      foreach $argument (@arguments) {
        ($key,$value)=split("=",$argument);
        $$macro{$key}=$value;
      };

    push(@parsed,@lines);
    

  } elsif ($line =~ /={0}->obeyw/) {

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
};


# This is the status checking code

# Subroutine to add error checking 
# Relies on $ORAC_STATUS being available
 
sub orac_check_status {
 
  my @newlines =  (' if ($ORAC_STATUS != $ORAC__OK) {' ,
		   '   print "Error in pipeline\n"; ' ,
		   '   return $ORAC_STATUS; ' ,
		   ' } ');
  
}

# Subroutine to check status of OBEYW

sub orac_check_obey_status {

  my ($monolith);

  # Get the name of the monlith from the obeyw
  my $line = shift;

  $line =~ /obeyw\{(\w)\}/ && ($monolith = $1);


  my @statuslines = ('  if ($OBEYW_STATUS != $ORAC_ACT_COMPLETE) {' ,
                  '   print "Error in obeyw to monolith $monolith: $OBEYW_STATUS\n"; ' ,
		  '   return $OBEYW_STATUS; ' ,
		  ' } ');
}


#------------------------------------------------------------------------



#------------------------------------------------------------------------
# THE END(s)
#------------------------------------------------------------------------


sub orac_exit_normally {

    $message = shift(@_);
    orac_kill_display;
    print "Orac says: $message - Exiting...\n";

    adamtask_exit;		# Shut down the messaging system
    &orac_kill_display;		# Destroy display

    print "\nOrac says: Goodbye\n";
    exit;
};

sub orac_exit_abnormally {

my $signal = shift;
$Starlink::ADAMTASK::message_hide = 1; # turn off messages

adamtask_exit;                        # Shut down the messaging system
rmtree $ENV{'ADAM_USER'};             # delete process-specific adam dir
&orac_kill_display;		# Destroy display
die;
# die "\n --Signal $signal received--\n";	

};


1;
