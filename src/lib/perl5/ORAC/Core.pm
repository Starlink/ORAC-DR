package ORAC::Core;

=head1 NAME

ORAC::Core - core routines for data pipelining

=head1 SYNOPSIS

  use ORAC::Core;

  orac_process_frame($CURRENT_RECIPE, $PRIMITIVE_LIST, $opt_showcurrent,
                     $Frm, $Grp, $Cal,\%Mon,$OverRecipe, $instrument);

  orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr, $ut);

  orac_print_configuration( $opt_debug, $opt_showcurrent, $log_options,
                            $win_str, \$STATUS_TEXT  );

  orac_message_launch( $opt_nomsgtmp, $opt_verbose );

  orac_start_algorithm_engines( $opt_noeng, $InstObj );

  orac_start_display( $nodisplay );

  orac_calib_override( $opt_calib, $calclass );

  orac_parse_files( $opt_files );

  orac_process_argument_list( $opt_from, $opt_to, $opt_skip, $opt_list,
                               $frameclass );

  orac_main_data_loop( $opt_batch, $opt_ut, $opt_resume, $opt_skip,
                       $opt_debug, $recsuffix, $grptrans,
                       $loop, $frameclass, $groupclass,
                       $instrument, $Mon, $Cal, \@obs, $Display, $orac_prt,
                       $ORAC_MESSAGE, \$STATUS_TEXT, $PRIMITIVE_LIST,
                       $Override_Recipe );

=head1 DESCRIPTION

This module contains the core routines that actually handle the
data processing. Routines are provided for constructing groups
and for processing those groups, along with routines to do the
inital pipeline configuration and algorithm engine startup.

=cut

use strict;
use warnings;
use Carp;

# ORAC modules
use ORAC::Basic;                # Helper routines
use ORAC::Print;
use ORAC::Version;
use ORAC::Recipe;
use ORAC::Loop;                 # Loop control
use ORAC::Event;                # Tk event
use ORAC::General;              # parse_* routines
use ORAC::Inst::Defn qw/ orac_determine_inst_classes orac_guess_instrument /;
use ORAC::Error qw/:try/;
use ORAC::Constants qw/:status/; # ORAC status varaibles
use ORAC::Recipe::Parameters;

# Need to use this class so that we can pre-configure the
# message systems on the basis of command line switches
use ORAC::Msg::MessysLaunch;

#general modules
use Config;
use Sys::Hostname;              # For logfile
use IO::File;
use File::Spec;
use File::Path;
use Cwd;
use Fcntl ":mode";

require Exporter;

use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_process_frame orac_store_frm_in_correct_grp
             orac_print_configuration orac_message_launch
             orac_start_algorithm_engines orac_start_display
             orac_calib_override orac_process_argument_list
             orac_main_data_loop orac_parse_files orac_parse_recparams
             orac_print_config_with_defaults orac_declare_location
             orac_print_recipe_summary /;

$VERSION = '1.0';

# File globals, yuck!
#
# These are here so that we can call a routine to untie these from lots of
# different places, they're set from orac_print_configuration. Maybe this
# should have a class all to itself?
my ( $orac_prt, $msg_prt, $msgerr_prt );

=head1 SUBROUTINES

The following subroutines are available:

=over 4

=item B<orac_store_frm_in_correct_grp>

Stores the supplied frame into a Grp (usually specified in the Frame),
creating a new Group object if necessary. The Group objects are stored
in a hash (reference supplied) and, optionally, an array (unless undef).
This is so that Groups can be retrieved in the order in which they
were created. The GrpType specifies the type of Group that should be
created (eg B<ORAC::Group::UFTI>, B<ORAC::Group::JCMT> etc). The UT
is supplied purely so that the Group can be named (using the
file_from_bits() method).

  orac_store_frm_in_correct_grp($Frm, $GrpType, \%Groups, \@Groups,
        $ut, $resume, $transient);
  orac_store_frm_in_correct_grp($Frm, $GrpType, \%Groups, undef,
        $ut, $resume, $transient);

The resume flag is used to determine the behaviour of the group when
it is first created. If resume is false, any existing Group file is
removed before proceeding; if it is true, the Group file is retained
and any coadd information is read using the coaddsread() Group
method.

The transient argument controls whether more than one group can be
created. If transient is 1 only a single group is stored in %Groups,
although multiple may be created during processing. If transient is -1
then only one group is ever created, and every Frame object goes into
that group.

The current Grp (ie the Group associated with the supplied Frm)
is returned.

=cut


sub orac_store_frm_in_correct_grp {

  croak 'Usage: orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr,$ut, $resume, $transient)'
    unless scalar(@_) == 7;

  # Variable declaration - Frossie loves this stuff :-)
  my ($use_arr, $Grp);

  # Read the argument list
  my ($Frm, $GrpObjectType, $GrpHash, $GrpArr, $ut, $resume, $transient) = @_;

  # Check that we have a hash reference
  croak 'orac_store_frm_in_correct_grp: 3rd arg must be hash reference'
    unless ref($GrpHash) eq 'HASH';


  # Check that we have an array reference - undef is okay
  if (defined $GrpArr) {
    $use_arr = 1;
    croak 'orac_store_frm_in_correct_grp: 4th arg must be array ref or undef'
      unless ref($GrpArr) eq 'ARRAY';
  } else {
    $use_arr = 0;
  }

  my $check_remove = 0;

  # If we've been asked to only do one group ever (i.e. $transient is
  # -1) then skip all of the stuff that sorts out which Group this
  # Frame is in and just put it in the Group.
  my $grpname;

  if ( defined( $transient ) && $transient == -1 ) {
    $grpname = 'ALL';
  } else {
    # query Frame for its group
    $grpname = $Frm->group;
  }

  # create a new group object and remove the previous file
  # unless such an object already exists
  # note that the "existence" of this group is only meaningful
  # over the lifetime of the pipeline
  # Unless the primitive is written to recognise -resume

  do {

    # Clear the group hash if we are transient
    if ( defined( $transient ) && $transient == 1 ) {
      %$GrpHash = ();
    }

    # Create the group
    $Grp = new $GrpObjectType($grpname);

    # Store the Group object.
    $GrpHash->{$grpname} = $Grp;

    # Store the Grp on the array as well
    push(@$GrpArr, $Grp) if $use_arr;

    # We'll need to check to see if the file exists later on and if it
    # needs to be removed, based on the $resume flag.
    $check_remove = 1;

  } unless (exists $GrpHash->{$grpname});

  # Retrieve the current group object
  $Grp = $GrpHash->{$grpname};

  # push current Frame onto Group
  $Grp->push($Frm);

  # Report whether this was a new group or an existing group
  # Do this after the Frame has been pushed on so that we can
  # call the name() method
  if ($Grp->num == 0) {
    orac_print ("A new group ".$Grp->name." has been created\n","blue");
    $Grp->file( $Grp->file_from_name );
  } else {
    orac_print ("This observation is part of group ".$Grp->name."\n","blue");
  }

  # If we were previously requested to check if the file exists, do so
  # now and erase it if the $resume flag is not set.
  if ( $check_remove ) {
    if ( $Grp->file_exists ) {
      if ( $resume ) {
        $Grp->coaddsread;
        $Grp->readhdr;
      } else {
        $Grp->erase;
      }
    }
  }

  # Return the current Group
  return $GrpHash->{$grpname};

}

=item B<orac_process_frame>

This is the core B<ORAC-DR> pipeline processing routine.
It processes the supplied frame object that belongs to the group object,
using the supplied calibration object. The instrument name and default
recipe are required for recipe/primitive reading since recipes and
primitives are stored in instrument specific directories.
The %Mon hash is supplied so that a recipe has full access to
all the monoliths launched for this instrument.

  orac_process_frame( CurrentRecipe => $STATUS_TEXT,
                      PrimitiveList => $PRIMITIVE_LIST,
                      Frame => $Frm,
                      Group => $Grp,
                      Calibration => $Cal,
                      Engines =>\%Mon,
                      Display => $Display,
                      Beep => $opt_beep,
                      Debug => $opt_debug,
                      CmdLineRecipe => $Override_Recipe,
                      Instrument => $instrument,
                      Batch => 0,
                      RecSuffix => "A,B,C",
                      RecPars => $parameterfile,
                     );

Additional parameters are provided to configure the recipe
environment. Defaults are provided for Debug and Batch.
(both false). Those options relate to the C<-debug> and C<-batch>
command line options.

Returns the recipe exit status or throws an exception.

=cut

sub orac_process_frame {

  my %args = @_;

  # Require Frame, Group, Calibration, Display and Engines
  for (qw/ CurrentRecipe CurrentPrimitive PrimitiveList Frame
           Group Calibration Display Engines Instrument/) {
    croak "orac_process_frame: Arg hash must include keyword $_\n"
      unless exists $args{$_};
  }

  # Check args
  croak "Engines must be supplied as hash reference\n"
    unless ref($args{Engines}) eq 'HASH';

  # Copy the objects
  my $CURRENT_RECIPE = $args{CurrentRecipe};
  my $CURRENT_PRIMITIVE = $args{CurrentPrimitive};
  my $PRIMITIVE_LIST = $args{PrimitiveList};
  my $Frm = $args{Frame};
  my $Grp = $args{Group};
  my $Cal = $args{Calibration};
  my $Mon = $args{Engines};
  my $Display = $args{Display};

  # Store the headers of the current frame in the calibration object
  $Cal->thingone($Frm->hdr);
  $Cal->thingtwo($Frm->uhdr);

  # KLUDGE: If recipe is not defined take the one specified on the command
  # Line. Else use the one instructed by the frame.
  # This needs to be changed such that we override all recipes except for
  # calibrators

  my $RecipeName;
  if (exists $args{CmdLineRecipe} && defined $args{CmdLineRecipe}) {
    $RecipeName = $args{CmdLineRecipe};
    orac_print "Using recipe $RecipeName specified on command-line\n";
  } else {
    # Retrieve recipe name from frame object
    my $frmrecipe = $Frm->recipe;

    # copy it
    $RecipeName = $frmrecipe;
    orac_print "Using recipe $RecipeName provided by the frame\n";
  }
  ;

  # clear the primitive list variables
  if ( defined $PRIMITIVE_LIST && ref($PRIMITIVE_LIST) ) {
    @$PRIMITIVE_LIST = ( );
  }
  if ( defined $CURRENT_PRIMITIVE && ref($$CURRENT_PRIMITIVE) ) {
    $$CURRENT_PRIMITIVE = [];
  }

  # Create new recipe object
  my $recipe;
  try {
    $recipe = new ORAC::Recipe( NAME => $RecipeName,
                                INSTRUMENT => $args{Instrument});
  } catch ORAC::Error::FatalError with {
    my $Error = shift;
    $Error->throw;
  }  otherwise {
    my $Error = shift;
    throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
  };

  # Configure debugging and batch flags
  $recipe->debug( $args{Debug} ) if exists $args{Debug};
  $recipe->batch( $args{Batch} ) if exists $args{Batch};

  # Configure recipe suffix and parameters
  $recipe->suffices( @{$args{RecSuffix}}) if exists $args{RecSuffix};
  $recipe->parameters( $args{RecPars} ) if exists $args{RecPars};

  # We will return the recipe status. Default to bad in case an exception
  # is thrown.
  my $status = ORAC__ERROR;

  # Execute the recipe
  try {
    orac_notify( ORAC::Print::NOT__STARTOBS, "Start reducing observation",
                 "Processing observation ".$Frm->number." with recipe $RecipeName");
    $status = $recipe->execute( $CURRENT_RECIPE, $CURRENT_PRIMITIVE, $PRIMITIVE_LIST, $Frm,
                                $Grp, $Cal, $Display, $Mon );
    orac_notify( ORAC::Print::NOT__ENDOBS, "Reduced observation",
                 "Observation ".$Frm->number. " has been reduced");



  }
    catch ORAC::Error::FatalError with
      {
        my $Error = shift;
        $Error->throw;
      }
        catch ORAC::Error::UserAbort with
          {
            my $Error = shift;
            $Error->throw;
          }
            otherwise
              {
                my $Error = shift;
                throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
              };

  # delete symlink to raw data file or actual data file if marked with
  # temporary status - we rely on the temporary flags even if
  # the ORAC_DATA_IN == ORAC_DATA_OUT and it's not a symlink
  my @istempraw = $Frm->tempraw;
  for my $raw ( $Frm->raw ) {
    my $istemp = shift(@istempraw);
    unlink $raw if $istemp;
  }

  # Now we try again but be a bit more careful about removing
  # files
  # Only want to do this if we created it initially as a soft link
  # and if ORAC_DATA_IN is not the same directory as ORAC_DATA_OUT
  if ( defined( $ENV{'ORAC_DATA_IN'} ) &&
       defined( $ENV{'ORAC_DATA_OUT'} ) &&
       File::Spec->canonpath($ENV{"ORAC_DATA_IN"})
       ne File::Spec->canonpath($ENV{"ORAC_DATA_OUT"}) ) {
    foreach my $raw ( $Frm->raw ) {
      unlink($raw) if (-l $raw);
    }
  }

  # Set the Xoracdr status bar to have the current recipe name
  $$CURRENT_RECIPE = "Currently doing: ";

  # clear the current primitive variables
  if ( defined $PRIMITIVE_LIST && ref($PRIMITIVE_LIST) ) {
    @$PRIMITIVE_LIST = ( );
  }
  if ( defined $CURRENT_PRIMITIVE && ref($CURRENT_PRIMITIVE) ) {
    $CURRENT_PRIMITIVE = [];
  }

  # Return the exit status so that we can track statistics
  return $status;

}

=item B<orac_print_config_with_defaults>

Wrapper for the C<orac_print_configuration> function, but including
code to configure default logging switches before configuring the
print system.

  my ($orac_prt, $msg_prt, $err_prt, $ORAC_MESSAGE,
      $PRIMITIVE_LIST, $CURRENT_PRIMITIVE) =
        orac_print_config_with_defaults( \$CURRENT_RECIPE,
                                         \@ARGV, %cloptions );

@ARGV contains the command line arguments for the log file. %cloptions
are the command line switches. C<-debug>, C<-showcurrent> and C<-log>
are used by this routine. C<-log> will be read and modified to provide
default behaviour.

=cut

sub orac_print_config_with_defaults {
  my $CURRENT_RECIPE = shift;
  my $ORAC_ARGS = shift;
  my %opt = @_;

  my $log_options;

  # check for log options, we need to start the Tk early if using X Windows
  # Note that -showcurrent also require Tk
  if (defined $opt{log}) {
    # User is overriding logging options, lower case the options
    $log_options = lc($opt{log});
  } else {
    # fx is default if we have a DISPLAY variable
    if (defined $ENV{DISPLAY}) {
      $log_options = 'fx';      # We use X Windows
    } else {
      $log_options = 'sf';      # We use the console (icky!)
    }
  }

  my $win_str;
  if ( $log_options =~ /x/  ||
       (exists $opt{showcurrent} && $opt{showcurrent})) {
    my $MW = orac_launch_tk("Tk");
    if (defined $MW) {
      $win_str = "Tk";
    } else {
      # disable X logging option and replace with screen
      $log_options =~ s/s//;    # remove any existing "s"
      $log_options =~ s/x/s/;   # replace x with s
      print STDERR "Error loading Tk modules - X logging not available\n";
      print STDERR "Using screen instead\n";
    }
  }

  # Now do the configuration
  return orac_print_configuration( $log_options,
                                   $win_str,
                                   \$CURRENT_RECIPE,
                                   $ORAC_ARGS,
                                   %opt
                                 );
}

=item B<orac_launch_tk>

Attempt to load Tk and create a main window indexed by the identifying
string.

  $w = orac_launch_tk($win_str);

This routine can safely be called multiple times.

Returns the top level MainWindow object.

=cut

sub orac_launch_tk {
  my $win_str = shift;

  # first ask if ORAC::Event has a main window registered
  my $MW = ORAC::Event->query($win_str);
  return $MW if defined $MW;

  # now try to load Tk
  eval { require Tk; require Tk::TextANSIColor; require ORAC::Xorac};
  unless( $@ ) {
    $MW = MainWindow->new();
    ORAC::Event->register($win_str=>$MW);
  }
  return $MW;
}

=item B<orac_declare_location>

Write a file indicating where the pipeline is going to be writing
any output data (ie ORAC_DATA_OUT). This file will be written into
a directory obtained from the ORAC_LOCATION_DIR or else fall back
to the default JAC location of "/jac_sw/oracdr-locations".

The file will be named for the ORAC_INSTRUMENT environment variable
and any recipe suffices that are in use. For example "scuba2_450-ql".
The file will contain one line with the value of $ORAC_DATA_OUT.

A file is only written if the UT date being used is the current
UT date.

  orac_declare_location( %options );

where %options is the command line options hash.

=cut

sub orac_declare_location {
  my %options = @_;

  # get the output dir
  my $locdir = "/jac_sw/oracdr-locations";
  $locdir = $ENV{ORAC_LOCATION_DIR} if (exists $ENV{ORAC_LOCATION_DIR} &&
                                        defined $ENV{ORAC_LOCATION_DIR});
  return unless -d $locdir;

  # Default to today if not given. Also check to see if we have
  # been told to use today
  my $istoday;
  if (!defined $options{ut}) {
    $istoday = 1;
  } else {
    my $today = ORAC::General::utdate();
    $istoday = ($options{ut} == $today ? 1 : 0);
  }

  return unless $istoday;

  my $type = lc($ENV{ORAC_INSTRUMENT});

  # get the mode information from recsuffix
  if (exists $options{recsuffix}) {
    for my $rs ( @{$options{recsuffix}} ) {
      my $sfx = lc($rs);
      $sfx =~ s/^_//;
      $type .= "-$sfx";
    }
  }

  my $locfile = File::Spec->catdir( $locdir, $type );
  if ( open(my $fh, ">", $locfile) ) {
    print $fh $ENV{ORAC_DATA_OUT} ."\n";
    close($fh);
    chmod  S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH, $locfile;
  } else {
    print STDERR "Unable to write file to locate DR ($locfile) : $!\n";
  }
}

=item B<orac_print_configuration>

This routine setups the orac print system, it takes the $opt_debug and
$log_options and the $MW variable and determines which file handles to return

  my($orac_prt, $msg_prt, $msgerr_prt, $ORAC_MESSAGE,
     $PRIMITIVE_LIST, $CURRENT_PRIMITIVE)
     = orac_print_configuration(
                                 $log_options, $win_str, \$CURRENT_RECIPE
                                 \@ORAC_ARGS, %options
                                );

The ORAC_ARGS are assumed to be the command line options. C<%options>
is the options hash. C<-debug> and C<-showcurrent> are used by this
routine.

The tied file handles $orac_prt, $msg_prt and $msgerr_prt are
returned, along with the Tk packed variable $ORAC_MESSAGE and
a reference to arrays containing the primitive information.

=cut

sub orac_print_configuration {

  # Read the argument list
  my $log_options = shift;
  my $win_str = shift;
  my $CURRENT_RECIPE = shift;
  my $ORAC_ARGS = shift;
  my %opt = @_;

  my $app = ORAC::Version->getApp;
  my $debug_prefix = "ORACDR";
  my $logfile_prefix = "oracdr";
  if ($app eq 'PICARD') {
    $debug_prefix = "PICARD";
    $logfile_prefix = "picard";
  }

  # First thing we need to do is create an ORAC::Print object
  # that we can fiddle with to adjust the output filehandles
  $msg_prt  = new ORAC::Print;   # For message system
  $msgerr_prt = new ORAC::Print; # For errors from message system
  $orac_prt = new ORAC::Print;   # For general orac_print

  # Debug info
  if ($opt{debug}) {
    $orac_prt->debugmsg(1);
    my $fh = new IO::File(">".$debug_prefix.".DEBUG") || do {
      orac_err "Error opening debug logfile in ORAC_DATA_OUT: $!";
      throw ORAC::Error::FatalError("Error opening debug logfile",
                                    ORAC__FATAL);
    };

    $orac_prt->debughdl($fh);

    # Turn on autoflush of debugging info to save as much information
    # as possible if the pipeline crashes without flushing the buffer
    $fh->autoflush(1);

  }
  ;

  # Logging messages to a file
  # If log is not defined, we are defaulting to STDOUT
  #  Log can be:
  #  s - xterm screen  (STDOUT)
  #  f - file          (ORACDR_$$.LOG)
  #  x - Xwindow       (experimental)
  # or combination (eg sf).
  # Can keep STDOUT default if not set at all
  # Always print error messages to STDERR  + optionally, the logfile
  # Default is to use 'sf'

  # Initialise file handle arrays
  my @out_hdl = ();
  my @err_hdl = (\*STDERR);
  my @war_hdl = ();

  # define Tk packed variables
  my ($ORAC_MESSAGE, $PRIMITIVE_LIST, $CURRENT_PRIMITIVE);

  # and defaults for these in case we are not using Tk
  # Current primitive is a reference to a reference to an array! (this is what
  # you get when you tie to a ListBox
  $PRIMITIVE_LIST = [];
  my $ARRAY = []; $CURRENT_PRIMITIVE = \$ARRAY;

  # defined references to the filehandles for the Tk widgets
  my ( $TEXT1, $TEXT2, $TEXT3);

  # Flag to indicate that we need a main window
  my $NeedMainWindow = 1;

  # If it only matches 's' then we dont bother with this block
  if ($log_options ne 's') {

    # Request for an X-window, put this first so that we can fall
    # back to using the screen if Tk is not found
    if ($log_options =~ /x/) {

      # Create the Tk log window
      # Routine returns references to packed Tk variable and
      # references to output, warning and error file handles
      ( $ORAC_MESSAGE, $TEXT1, $TEXT2, $TEXT3 ) =
        ORAC::Xorac::xorac_log_window( $win_str, \$orac_prt );
      $NeedMainWindow = 0;

      # Update and draw the screen
      try {
        ORAC::Event->update($win_str);
      } catch ORAC::Error::FatalError with {
        my $Error = shift;
        $Error->throw;
      } catch ORAC::Error::UserAbort with {
        my $Error = shift;
        $Error->throw;
      } otherwise {
        # this should sucessfully catch croaks, we want to re-throw
        # it as a ORAC::Error::FatalError, this should do it...
        my $Error = shift;
        throw ORAC::Error::FatalError("$Error", ORAC__FATAL );
      };

      # Store the filehandles
      push (@out_hdl, $TEXT1);
      push (@err_hdl, $TEXT3);
      push (@war_hdl, $TEXT2, $TEXT1); # Display warnings with messages

    }
    # Request for SCREEN
    if ($log_options =~ /s/) {
      push (@out_hdl, \*STDOUT);
      push (@war_hdl, \*STDOUT);
    }
    # Request for file - must have already chdir'ed to ORAC_DATA_OUT
    if ($log_options =~ /f/ || exists $ENV{ORAC_LOGDIR}) {

      my @logfiles;

      # this is the log file for $ORAC_DATA_OUT
      if ($log_options =~ /f/) {
        my $logfh = new IO::File(">.".$logfile_prefix."_$$.log") || do {
          orac_err "Error opening ORAC-DR logfile in ORAC_DATA_OUT: $!\n";
          throw ORAC::Error::FatalError("Error opening logfile",
                                        ORAC__FATAL);
        };
        push(@logfiles, $logfh);
      }

      # Also write a file to the ORAC_LOGDIR for convenience
      if (exists $ENV{ORAC_LOGDIR} && -d $ENV{ORAC_LOGDIR}) {
        my @time = gmtime();
        my $host = (split( /\./, hostname))[0]; # only want first part of host
        my $user = ($ENV{USER} ? "_$ENV{USER}" : "" );
        my $inst = lc($ENV{ORAC_INSTRUMENT});
        my $fname = sprintf($logfile_prefix.
                            "_%04d%02d%02d_%02d%02d%02d_%s_%s%s.log",
                            $time[5]+1900, $time[4]+1,$time[3],
                            $time[2],$time[1],$time[0],$inst, $host, $user);
        my $fh = new IO::File("> ". File::Spec->catfile($ENV{ORAC_LOGDIR},$fname)) || do {
          orac_err "Error opening $app logfile in log dir $ENV{ORAC_LOGDIR}/$fname: $!\n";
          throw ORAC::Error::FatalError("Error opening secondary log file", ORAC__FATAL);
        };
        push(@logfiles, $fh);
      }

      for my $logfh (@logfiles) {
        $logfh->autoflush(1);

        # Write a header
        print $logfh "$app logfile - created on " . scalar(gmtime) ." UT\n";
        print $logfh "\nORAC Environment:\n\n";
        print $logfh "\tPipeline Version: ". ORAC::Version->getVersion ."\n";
        print $logfh "\tInstrument : $ENV{ORAC_INSTRUMENT}\n";
        print $logfh "\tInput  Dir : ".(defined $ENV{ORAC_DATA_IN} ?
                                        $ENV{ORAC_DATA_IN} : "<undefined>")."\n";
        print $logfh "\tOutput Dir : $ENV{ORAC_DATA_OUT}\n";
        print $logfh "\tCalibration: ".(defined $ENV{ORAC_DATA_CAL} ?
                                        $ENV{ORAC_DATA_CAL} : "<undefined>")."\n";
        print $logfh "\tORAC   Dir : $ENV{ORAC_DIR}\n";
        print $logfh "\tORAC   Lib : $ENV{ORAC_PERL5LIB}\n";
        my $rdir = ($ENV{ORAC_RECIPE_DIR} || '<undefined>');
        my $pdir = ($ENV{ORAC_PRIMITIVE_DIR} || '<undefined>');
        print $logfh "\tAdditional Recipe Dir   : $rdir\n";
        print $logfh "\tAdditional Primitive Dir : $pdir\n";


        print $logfh "\nSystem environment:\n\n";
        print $logfh "\tHostname        : ". hostname . "\n";
        print $logfh "\tUser name       : $ENV{USER}\n";
        print $logfh "\tPerl version    : $]\n";
        print $logfh "\tOperating System: $^O\n";
        my $uname = "<unknown>";
        {
          no warnings;
          my $tmp = `uname -a`;
          $uname = $tmp if $tmp;
        }
        ;
        print $logfh "\tSystem description: $uname\n";

        print $logfh "\n$app Arguments: ".join(" ",@$ORAC_ARGS)."\n";

        print $logfh "\nSession:\n\n";
      }

      # Store the filehandles
      push (@out_hdl, @logfiles);
      push (@err_hdl, @logfiles);
      push (@war_hdl, @logfiles);
    }

    # Configure ORAC::Print
    $orac_prt->outhdl(@out_hdl);
    $orac_prt->warhdl(@war_hdl);
    $orac_prt->errhdl(@err_hdl);

  }

  # Register the arguments
  orac_loginfo( Arguments => join(" ", @$ORAC_ARGS ) );

  # Now create the recipe viewer if required.
  if ($opt{showcurrent}) {
    # Routine returns a reference to a tied array (listbox contents)
    ( $PRIMITIVE_LIST, $CURRENT_PRIMITIVE ) =
      ORAC::Xorac::xorac_recipe_window( $win_str, $CURRENT_RECIPE, $NeedMainWindow );
  }

  # Generate tied filehandle for subsequent use by systems
  # that require a filehandle rather than use of ORAC::Print
  # The message system is one example

  # First generate a filehandle tied to the orac_print system
  tie *MSG, 'ORAC::Print', $msg_prt;
  $msg_prt->outcol('clear');    # Cyan color for all messages

  # Tie a filehandle to the error messages from the alogrithm
  # engines and redirect to orac_err
  tie *MSGERR, 'ORAC::Print', $msgerr_prt, 'err';

  return ( $orac_prt, $msg_prt, $msgerr_prt, $ORAC_MESSAGE,
           $PRIMITIVE_LIST, $CURRENT_PRIMITIVE );

}

=item B<orac_message_launch>

This routine creates a message launch system object and configures it,
we pass $opt_nomsgtmp and $opt_verbose to the routine to configure the
object.

  orac_message_launch( $opt_nomsgtmp, $opt_verbose );

The message system itself will be initialised when it is required
rather than at the start. If we know there is one messsys and we know
that it will always be the same one then we can configure it here
explicitly. The main reason for doing that is to make sure that it
works before starting recipe processing.

=cut

sub orac_message_launch {

  croak 'Usage: orac_message_launch( $opt_nomsgtmp, $opt_verbose )'
    unless scalar(@_) == 2 ;

  # Read the argument list
  my ($opt_nomsgtmp, $opt_verbose) = @_;

  # launch new message system object
  my $MessysLaunch = new ORAC::Msg::MessysLaunch;

  # Need to make sure we respect the -nomsgtmp command line
  # option. This is only useful if no other place has started
  # a message system already.

  # Check that we are not too late
  if ($MessysLaunch->messys_active && $opt_nomsgtmp) {
    orac_err "Can not preserve message system state. Unable to use -nomsgtmp";
    orac_err "Can not continue. Sorry.\n";
    throw ORAC::Error::FatalError("A message system has already been started.",
                                  ORAC__FATAL);
  }

  $MessysLaunch->preserve( $opt_nomsgtmp );

  # Send the configuration options
  $MessysLaunch->config(
                        # This timeout is not used for monolith launching
                        timeout => 6000,
                        paramrep => sub {
                          orac_warn "Sending auto abort in response to parameter request\n";
                          return "!!"
                        },
                        messages => ( $opt_verbose ? 1 : 0 ),
                        stdout => \*MSG,
                        stderr => \*MSGERR,
                       );

  # Just in case we are too late, configure the exisiting message
  # systems.
  $MessysLaunch->configure_all;

}

=item B<orac_start_algorithm_engines>

This routine pre-launches the relevant algorithm engines which are always required by the instrument

   my ( $Mon )  = orac_start_algorithm_engines( $opt_noeng, $InstObj );

it returns a reference to the algorithm engine hash, $Mon.

=cut

sub orac_start_algorithm_engines {

  croak 'Usage: orac_start_algorithm_engines( $opt_noeng, $InstObj)'
    unless scalar(@_) == 2 ;

  # Read the argument list
  my ($opt_noeng, $InstObj) = @_;

  my $Mon = {};                 # Hash reference
  unless ($opt_noeng) {

    # start algorithm engines
    #
    orac_printp("Pre-starting mandatory monoliths...","blue");
    #

    # Pre-launch. This will fail if we can not contact the
    # engines so need to eval it
    $Mon = undef;
    my $err;
    try {
      $Mon = $InstObj->start_algorithm_engines;
    } catch ORAC::Error with {
      my $Error = shift;
      $err = "$Error";
    } otherwise {
      my $Error = shift;
      $err = "$Error";
    };
    if (!defined $Mon && defined $err) {
      ORAC::Error->flush;
      orac_err("Error contacting monoliths. Aborting.\n$err\n");
      throw ORAC::Error::FatalError("Error contacting monoliths",
                                    ORAC__FATAL);
    }

    orac_print ("Done\n","blue");

  } else {

    orac_printp("No algorithm engines will be started (-noeng option)\n","blue");

  }

  return $Mon;
}

=item B<orac_start_display>

This routine is a wrapper for the orac_setup_display() subroutine in
ORAC::Basic. It starts the ORAC display unless $nodisplay is
set.

   my $Display = orac_start_display( $nodisplay );

the routine returns the display object $Display.

Note that an object is returned in all cases, but if display
is disabled the display is created in monitor mode.

=cut

sub orac_start_display {

  croak 'Usage: orac_start_display( $opt_nodisplay )'
    unless scalar(@_) == 1 ;

  # Read the argument list
  my ($opt_nodisplay) = @_;

  # launch display
  # -nodisplay suppresses display,
  #
  my $Display;

  if ($opt_nodisplay) {
    orac_printp("No display will be used\n","blue");
    # Enable monitoring output
    $Display = orac_setup_display( nolocal => 1 );
  } else {

    # Local display and monitoring output
    orac_print ("Setting up display infrastructure (display tools will not be started until necessary)...", 'blue');
    $Display = orac_setup_display;
    orac_print ("Done\n","blue");

    # Could configure debug option in $Display at this point
  }

  return $Display;
}

=item B<orac_calib_override>

This routine creates a calibration object of the specified class and
overrides methods as specified in the C<--calib> option string.

   my $Cal = orac_calib_override( $calclass, @opt_calib, );

Multiple calibrations specifications can be supplied.
The calibrations are specified as comma separated keyword=value strings
or as hash references.

=cut

sub orac_calib_override {

  #  croak 'Usage: orac_calib_override( $opt_calib, $calclass )'
  #    unless scalar(@_) == 2 ;

  my ( $calclass, @calibs ) = @_;

  # Create calibration object
  my $Cal = new $calclass;

  # Some where to store the values
  my %calibs;

  # First we need to get a hash with all the calibration values
  # in it
  for my $opt_calib (@calibs) {

    next unless defined $opt_calib;

    if ( ref($opt_calib) ) {
      # $opt_calib will be a reference if passed from Xoracdr it may
      # have keywords with zero length strings as values, a quick
      # kludge to get round this follows
      foreach my $key (keys %$opt_calib ) {
        $calibs{$key} = $$opt_calib{$key} if length($$opt_calib{$key}) != 0;
      }

    } else {
      # or as a string from oracdr itself
      # need push(%hash...)
      %calibs = (%calibs, parse_keyvalues($opt_calib));
    }

  }

  # For each calibration configure the cal object
  foreach my $key (keys %calibs) {

    # Since we can manipulate the hash values via the GUI a key may
    # exist with an undef value, we have to check each key to see
    # that it has a value
    if ( defined $calibs{$key} ) {

      if ($Cal->can($key)) {    # set appropriate method

        $Cal->$key($calibs{$key});

        # if we have a noupdate method to enforce overrides, use it.
        my $noupdate = $key."noupdate";
        $Cal->$noupdate(1) if $Cal->can($noupdate);

        my $keyprint = $calibs{$key};
        if ( ref( $calibs{$key} ) eq 'ARRAY' ) {
          $keyprint = join ',', @{$calibs{$key}};
        }
        orac_printp("Calibration $key set to $keyprint\n",
                    "blue");

      } else {                  # complain but continue

        orac_err (" Calibration ($key) unknown by this instrument. Ignored\n");

      }
    }
  }

  return $Cal;
}

=item B<orac_parse_files>

This routine parses the text file which has a list of the files to be
processed, this should have one filename per line, filenames are
assumed to be relative to ORAC_DATA_IN.

   my @obs = orac_parse_files( $opt_files );

it returns an array of files to be read.

"#" is a comment character.

=cut

sub orac_parse_files {

  croak 'Usage: orac_parse_files( $opt_files )'
    unless scalar(@_) == 1 ;

  my ( $opt_files ) = @_;

  # Absolute path is okay, else will be relative to ORAC_DATA_IN
  my $filename = $opt_files;

  my $fh;
  unless ( open ( $fh, "<", $filename ) ) {
    orac_err( " Could not open ($filename): $!\n" );
    throw ORAC::Error::FatalError( "Could not open $filename", ORAC__FATAL);
  }
  my @obs;
  for my $f (<$fh>) {
    chomp($f);
    $f =~ s/\#.*//;             # comments
    $f =~ s/^\s+//;             # leading whitespace
    $f =~ s/\s+$//;             # trailin whitespace
    next unless $f =~ /\w/;
    push(@obs, $f);
  }
  close($fh);

  return ( @obs );
}

=item B<orac_parse_recparams>

Parse the command line argument specifying recipe parameters and return
either a ORAC::Recipe::Parameters object or undef.

 $params = orac_parse_recparams( $params );

=cut

sub orac_parse_recparams {
  my $file = shift;
  return ORAC::Recipe::Parameters->new( $file );
}

=item B<orac_process_argument_list>

This routine checks that your data exists and decides which data
loop approach to use.

 my $loop =
     orac_process_argument_list( $frameclass, \@obs, %opt );

it returns the looping scheme and a list of observations if one does not
already exist.

This routine is fairly complex since there are many combinations of
C<-from>, C<-to>, C<-skip>, C<-loop> and C<-list> that interact with
each other.

The options hash may contain the following keys: from, to, skip,
list and loop. All these are optional as the values may or may
not be defined or supplied by the user.

=cut

sub orac_process_argument_list {

  # Read the argument list
  my ($frameclass, $obs, %opt) = @_;

  my $loop;

  # This is triggered if we have -from and is the most complex option
  # since it can be used in conjunction with -skip and different
  # looping. The biggest complication comes from the optimization
  # with -skip

  if (defined $opt{from}) {

    if (defined $opt{to}) {

      # We have a known range so convert this to -list
      @$obs = $opt{from} .. $opt{to};

      $loop = 'list'

    } else {

      # If the skip flag is set to true we can turn the -from..end
      # loop into 'list' loop by determining the last observation
      # number.  For historical reasons, the inf loop should be used
      # if the -skip option is false.

      if ($opt{skip}) {

        # Special case if we are doing data detection since the
        # final obs number is changing
        if ( ! defined $opt{loop} or
             ( $opt{loop} ne 'wait' and $opt{loop} ne 'flag' ) or
             ( $opt{loop} eq 'flag' and defined( $opt{batch} ) ) ) {

          my $flag = ( defined( $opt{loop} ) and
                       $opt{loop} eq 'flag'  and
                       defined( $opt{batch} ) );

          my ($next, $high) = orac_check_data_dir($frameclass, $opt{from}, $flag);

          if (defined $high) {

            @$obs = ($opt{from}..$high);
            $loop = 'list';

          } else {

            # High not defined, simply look for the $opt{from} ignoring high
            # This essentially means that there is only one file to process
            @$obs = ( $opt{from} );
            $loop = 'list';

          }

        } else {

          # If we are using -loop wait and flag we can not optimize
          # to -list since the file count is changing
          @$obs = ( $opt{from} );
          $loop = $opt{loop};
        }
      } else {

        # We are not skipping so just start from the first number
        # and increment until we run out of observations
        @$obs = ($opt{from});

        # Set default loop scheme to 'inf'
        # if there is no 'to' and 'skip' is false.
        $loop = 'inf';

      }

      orac_print "Starting at observation $opt{from} and looping until no files available\n"
    }

  } elsif (defined $opt{list}) {

    @$obs = parse_obslist($opt{list});
    $loop = 'list';

  } elsif (defined $opt{to}) {

    # This catches the case where -to is defined but no -from or -list
    # Start counting at 1
    orac_print "Processing observations 1 to $opt{to}\n";
    @$obs = (1..$opt{to});
    $loop = 'list';

  } elsif (defined $$obs[0]) {

    # There is at least one element in the @obs array, we have a pre-
    # existing file list from the -files option and want to use
    # orac_loop_file
    $loop = 'file';

  } else {

    # Okay - none of -from, -list or -to were defined
    # We default to 1 in this case and set the loop to wait
    # Note that loop will be overriden if -loop is supplied
    orac_print "No observation numbers supplied - starting from obs 1\n";
    $loop = 'wait';
    @$obs = (1);

  }

  # -loop overrides the above determination if it has been specified
  # explicitly unless it has been set to list already by the above
  # logic
  $loop = $opt{loop} if defined $opt{loop} && $loop ne 'list';

  # -list always overrides -loop if it has been specified
  $loop = 'list' if $opt{list};

  # if we have defined it prepend orac_loop_
  $loop = "orac_loop_$loop" if defined $loop;

  # Return the answer
  return $loop;

}

=item B<orac_main_data_loop>

This routine handles the main data processing

  orac_main_data_loop( \%options, $loop, $instrument, \@obs,
                       $Display, $orac_prt,
                       $ORAC_MESSAGE, $CURRENT_RECIPE, \@PRIMITIVE_LIST,
                       $CURRENT_PRIMITIVE, $Override_Recipe );

There are two approaches to the data processing

=over 4

=item 1

The default processing method where data are read in and processed as
it arrives and Groups are extended as needed. This has the advantage
that the data is processed as it is taken, has very good feedback to
the user in real time. The down side is that Groups are processed as
soon as possible and in an off-line batch processing envrionment this
is very wasteful (why work out the flatfield every time a frame
arrives when you simply want to work out the flatfield from the entire
group).

=item 2

The "batch" method where the data are analysed in two passes.  First
the groups are setup, secondly the frames are processed in each group
in turn. This has the advantage that frames can be coadded into a
group only once and is the most efficient way of processing data
off-line. Note that this presupposes that the primitives are written
in such a way that they can spot the last member of the group (via the
lastmember method). Grp Primitives without this check will probably
fail since the some of the members will not have been processed even
though the group contains many members.

One other issue is calibration -- in principal all calibration groups
should be processed before observation groups and currently this is
not supported (only important when calibrations are taken after the
observation).

Batch mode can be summarised as

    - Read in all frames and allocate groups
    - Loop over all groups Loop over all frames in
      group process frames

Default mode is

    - Loop over all frames
    - Allocate groups
    - process frames

Batch mode can be turned on with the -batch switch.

=back

Returns a hash containing information on the error status
from all the frames that were processed. The hash can be
analyzed using orac_print_recipe_summary.

=cut

sub orac_main_data_loop {

  croak 'Usage: orac_main_data_loop( \%options, $loop, $instrument, \@obs, $Display, $orac_prt, $ORAC_MESSAGE, $CURRENT_RECIPE, \@PRIMITIVE_LIST, $CURRENT_PRIMITIVE, $Override_Recipe )'
    unless scalar(@_) == 11;

  # Read the argument list
  my ( $opts, $loop, $instrument, $obs,
       $Display, $orac_prt, $ORAC_MESSAGE, $CURRENT_RECIPE, $PRIMITIVE_LIST,
       $CURRENT_PRIMITIVE, $Override_Recipe ) = @_;

  # Read options
  my $opt_batch = $opts->{batch};
  my $opt_ut = $opts->{ut};
  my $opt_resume = $opts->{resume};
  my $opt_skip = $opts->{skip};
  my $opt_verbose = $opts->{verbose};
  my $opt_debug = $opts->{debug};
  my $opt_calib = $opts->{calib};
  my $opt_nomsgtmp = $opts->{nomsgtmp};
  my $opt_noeng = $opts->{noeng};
  my $recsuffix = $opts->{recsuffix};
  my $recpars = $opts->{recpars};
  my $grptrans = $opts->{grptrans};

  # If recsuffix has not been converted to a array ref yet do it here
  if (defined $recsuffix && ! ref($recsuffix) ) {
    $recsuffix = [ split /,/, $recsuffix];
  } else {
    $recsuffix = [];
  }

  # Given the instrument name derive all the classes

  # Initialise for this "instrument" and create a basic instrument object
  my ($frameclass, $groupclass, $calclass, $instclass) =
    orac_determine_inst_classes( $instrument );
  die "Could not determine core classes from instrument name $instrument"
    unless defined $frameclass;

  my $InstObj = $instclass->new();
  my $Cal = orac_calib_override( $calclass, @$opt_calib );

  # Message system
  orac_message_launch( $opt_nomsgtmp, $opt_verbose );
  my $Mon = orac_start_algorithm_engines( $opt_noeng, $InstObj );

  # Keep track of success and failure
  my %Stats;

  # Default is to process data in order of arrival
  unless ($opt_batch) {

    # Loop forever
    my %Groups = ();

    while (1) {

      if (exists $ENV{ORAC_NOGROUPS}) {
        orac_print "Group management disabled\n";
        %Groups = ();
      }

      # Return back the current frame
      # This will also configure the frame object
      # Turn off strict
      my @Frms;
      {
        no strict 'refs';
        @Frms = &{$loop}($frameclass, $opt_ut, $obs, $opt_skip);
      }

      # If frame is undefined then we assume that the data loop
      # should be stopped
      last unless defined $Frms[0];

      foreach my $Frm ( @Frms ) {

        orac_print ("REDUCING: ".$Frm->raw."\n","yellow");

        # Set the ORAC::Print prefix
        my $fnumber = $Frm->number;
        $$ORAC_MESSAGE = $instrument . ': ORAC-DR reducing observation number ' . $fnumber;
        $orac_prt->errpre("#$fnumber Err: ");
        $orac_prt->warpre("#$fnumber Warning: ");

        # Store the Frame in the Group
        my $Grp = orac_store_frm_in_correct_grp($Frm, $groupclass, \%Groups,
                                                undef, $opt_ut, $opt_resume, $grptrans);

        # Actually process the observation
        # Includes recipe configurations since the recipe
        # object is not instantiated until the recipe name is
        # read from the frame object in orac_process_frame
        # may want to revisit this.
        try {
          my $status = orac_process_frame(
                                          CurrentRecipe => $CURRENT_RECIPE,
                                          CurrentPrimitive => $CURRENT_PRIMITIVE,
                                          PrimitiveList => $PRIMITIVE_LIST,
                                          Frame => $Frm,
                                          Group => $Grp,
                                          Calibration => $Cal,
                                          Engines => $Mon,
                                          Display => $Display,
                                          Debug => $opt_debug,
                                          CmdLineRecipe => $Override_Recipe,
                                          Instrument => $instrument,
                                          Batch => 0,
                                          RecSuffix => $recsuffix,
                                          RecPars => $recpars,
                                         );
          orac_store_recipe_status( \%Stats, $status );
        }
          catch ORAC::Error::FatalError with {
            my $Error = shift;
            $Error->throw;
          }
            catch ORAC::Error::UserAbort with {
              my $Error = shift;
              $Error->throw;
            }
              otherwise {
                my $Error = shift;
                throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
              };

        # Reset the obs number labels
        $orac_prt->errpre('Error: ');
        $orac_prt->warpre('Warning: ');
        $$ORAC_MESSAGE = $instrument . ': ORAC-DR reducing observation --';

      }

    }

  } else {
    # Batch mode

    # First loop over frames
    my @Groups = ();
    my %Groups = ();

    orac_notify( ORAC::Print::NOT__GENERAL,"Analyzing files",
                 "Parsing files for batch mode processing");
    while (1) {
      # Return back the current frame
      # This will also configure the frame object
      my @Frms;
      {
        no strict 'refs';
        @Frms = &{$loop}($frameclass, $opt_ut, $obs, $opt_skip);
      }

      # If frame is undefined then we assume that the data loop
      # should be stopped
      last unless defined $Frms[0];

      foreach my $Frm ( @Frms ) {

        orac_print ("Storing: ".$Frm->raw."\n","yellow");

        # Store the Frame in the Group
        orac_store_frm_in_correct_grp($Frm, $groupclass, \%Groups, \@Groups,
                                      $opt_ut, $opt_resume, $grptrans);

      }

    }

    # if we are running PICARD mode we now need to go through each Frame
    # to see if they are associated with a single known instrument or just
    # generic
    if ( $instrument eq 'PICARD' ) {
      my %instrume_hdr;
      my $undef_inst = "__UNDEF__";
      for my $Grp ( @Groups ) { # Should be only one
        for my $Frm ($Grp->members) {
          my $inst = orac_guess_instrument( $Frm );
          orac_debug( "Guessed $inst instrument\n");
          $inst = $undef_inst unless defined $inst;
          $instrume_hdr{$inst}++;
        }
      }
      my @all_insts = keys %instrume_hdr;
      if (scalar @all_insts == 1 && $all_insts[0] ne $undef_inst ) {
        # this is the instrument we should recommend using
        # But we prefix with "PICARD_" to ensure that the search path
        # for primitives will include the picard search tree
        $instrument = "PICARD_". $all_insts[0];
        $ENV{ORAC_INSTRUMENT} = $instrument;

        # Override some  class definitions
        my ($nframeclass, $ngroupclass, $ncalclass, $ninstclass) =
          orac_determine_inst_classes( $instrument );

        # So redefine the calibration object
        $calclass = $ncalclass;
        $Cal = orac_calib_override( $calclass, @$opt_calib );

        orac_print( "Overriding PICARD instrument class to $ENV{ORAC_INSTRUMENT}\n", "yellow");
      }
    }


    # Now loop over groups and frames
    foreach my $Grp (@Groups) {
      foreach my $Frm ($Grp->members) {
        orac_print ("REDUCING: ".$Frm->raw."\n","yellow");
        # Set the ORAC::Print prefix
        my $fnumber = $Frm->number;
        $$ORAC_MESSAGE = $instrument . ': ORAC-DR reducing observation ' . $fnumber;
        $orac_prt->errpre("#$fnumber Err: ");
        $orac_prt->warpre("#$fnumber Warning: ");
        # Actually process the observation
        # Includes recipe configurations since the recipe
        # object is not instantiated until the recipe name is
        # read from the frame object in orac_process_frame
        # may want to revisit this.
        try {
          my $status = orac_process_frame(
                                          CurrentRecipe => $CURRENT_RECIPE,
                                          CurrentPrimitive => $CURRENT_PRIMITIVE,
                                          PrimitiveList => $PRIMITIVE_LIST,
                                          Frame => $Frm,
                                          Group => $Grp,
                                          Calibration => $Cal,
                                          Engines =>$Mon,
                                          Display => $Display,
                                          Debug => $opt_debug,
                                          CmdLineRecipe => $Override_Recipe,
                                          Instrument => $instrument,
                                          Batch => 1,
                                          RecSuffix => $recsuffix,
                                          RecPars => $recpars,
                                         );
          orac_store_recipe_status( \%Stats, $status );
        }
          catch ORAC::Error::FatalError with {
            my $Error = shift;
            $Error->throw;
          }
            catch ORAC::Error::UserAbort with {
              my $Error = shift;
              $Error->throw;
            }
              otherwise {
                my $Error = shift;
                throw ORAC::Error::FatalError("$Error", ORAC__FATAL);
              };

        # Reset the obs number labels
        $orac_prt->errpre('Error: ');
        $orac_prt->warpre('Warning: ');
        $$ORAC_MESSAGE = $instrument . ': ORAC-DR reducing observation --';
      }
    }
  }

  orac_notify( ORAC::Print::NOT__COMPLETE, "ORAC-DR completed",
               "All pipeline processing has completed");

  return %Stats;
}

=item B<orac_store_recipe_status>

Translates a return status from "orac_process_frame" into a
hash entry for tracking statistics.

  orac_store_recipe_status( \%ongoing, $status );

=cut

sub orac_store_recipe_status {
  my $href = shift;
  my $status = shift;

  # Do not use => in hash contructor since we do not want
  # ORAC__OK to become "ORAC__OK" we want it to become the value
  my %lut = (ORAC__OK, "OK",
             ORAC__TERM, "TERM",
             ORAC__BADENG, "BADENG");

  # initialise good and bad to make things easier later on
  for my $k (qw/ GOOD BAD /) {
    $href->{$k} = 0 unless exists $href->{$k};
  }

  my $key = "BAD";
  if (exists $lut{$status}) {
    $key = $lut{$status};
  }
  $href->{$key}++;

  # summarize
  $href->{TOTAL}++;

  if ($status == ORAC__OK || $status == ORAC__TERM) {
    $href->{GOOD}++;
  } elsif ($key ne "BAD") {
    $href->{BAD}++;
  }
}

=item B<orac_print_recipe_summary>

Print out the recipe summary using the hash generated by
orac_store_recipe_status.

  $exstat = orac_print_recipe_summary( $color, \%Stats );

Returns 0 if all recipes processed successfully and non-zero
if some failed. This value can be passed directly to exit().

=cut

sub orac_print_recipe_summary {
  my $color = shift;
  my $stats = shift;
  return unless defined $stats;
  return unless exists $stats->{TOTAL};

  if ($stats->{TOTAL} == 1) {
    my $text = "which completed successfully";
    if ( exists $stats->{TERM} && $stats->{TERM} ) {
      $text = "which was terminated early";
    } elsif (exists $stats->{BADENG} && $stats->{BADENG}) {
      $text = "which had a bad algorithm engine";
    } elsif ( $stats->{GOOD} == 0 ) {
      $text = "which completed with an error";
    }
    orac_print( "Processed one recipe $text\n", $color );
  } else {
    my $text = "successfully";
    if ($stats->{BAD} > 0) {
      $text = "of which ".$stats->{BAD}. " completed with an error";
    } elsif (exists $stats->{TERM} && $stats->{TERM} > 0) {
      my $waswere = ($stats->{TERM} == 1) ? "was" : "were";
      $text = "of which ". $stats->{TERM}. " $waswere terminated early";
    }

    orac_print( "Processed ".$stats->{TOTAL}." recipes $text\n", $color);
  }
  return ( $stats->{BAD} == 0 ? 0 : 1 );
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2008-2010 Science and Technology Facilities Council.
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
