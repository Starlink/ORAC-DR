#------------------------------------------------------------------------
# ORAC recipe parsing module
#------------------------------------------------------------------------

package ORAC::Basic;

=head1 NAME

ORAC::Basic - some implementation subroutines

=head1 SYNOPSIS

  use ORAC::Basic;

  $Display = orac_setup_display;
  orac_exit_normally;
  orac_exit_abnormally;

=head1 DESCRIPTION

Provides the routines for parsing and executing recipes.

=cut

use Carp;
use vars qw($VERSION @EXPORT $Beep @ISA);
use strict;

require Exporter;
use File::Path;
use File::Copy;

use ORAC::Print;
use ORAC::Display;

@ISA = qw(Exporter);

@EXPORT = qw/
  orac_setup_display
  orac_exit_normally orac_exit_abnormally
  /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$Beep    = 0;       # True if ORAC should make noises


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

The display object is returned.

  $Display = orac_setup_display;

=cut

# Simply create a display object
sub orac_setup_display {

  # Check for DISPLAY being set
  unless (exists $ENV{DISPLAY}) {
    warn 'DISPLAY environment variable unset - not starting Display subsystem';
    return;
  }

  # Set this global variable
  my $Display = new ORAC::Display;

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
  return $Display;
}

=item B<orac_exit_normally>

Exit handler for oracdr.

=cut

sub orac_exit_normally {
  my $message = '';
  $message = shift if @_;

  orac_print ("$message - Exiting...\n","red");

  rmtree $ENV{'ADAM_USER'}             # delete process-specific adam dir
    if defined $ENV{ADAM_USER};

  # Ring a bell when exiting if required
  if ($Beep) {
    for (1..5) {print STDOUT chr(7); select undef,undef,undef,0.2}
  }

  orac_print ("\nOrac says: Goodbye\n","red");
  exit;
};

=item B<orac_exit_abnormally>

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

=back

=head1 REVISION

$Id$

=head1 SEE ALSO

L<ORAC::Core>, L<ORAC::General>

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;

#$Log$
#Revision 1.57  2001/01/19 03:02:36  timj
#removed File::Copy by mistake
#
#Revision 1.56  2001/01/10 02:57:07  timj
#Move guts to ORAC::Recipe
#
#Revision 1.55  2001/01/09 09:13:25  timj
#minor doc typo
#
#Revision 1.54  2001/01/09 03:35:30  timj
#Only rmtree ADAM_USER dir if the env var is defined
#
#Revision 1.53  2000/10/10 02:59:08  timj
#Remove documentation for $KAPPA_* since Starlink::VERSIONS does that now.
#
#Revision 1.52  2000/08/15 19:10:38  timj
#Check that ORAC_STATUS is on a line including an =
#
#Revision 1.51  2000/06/15 03:01:52  timj
#Use Starlink::Versions
#
#Revision 1.50  2000/04/04 21:06:45  timj
#Pods were not being included into recipes. Fixed.
#
#Revision 1.49  2000/04/04 03:07:35  timj
#recipe parsing is now recursive (with recursion depth limits).
#PODs are now ignored.
#
#Revision 1.48  2000/03/01 21:56:17  timj
#Fix pods so that they pass all check with podchecker
#
#Revision 1.47  2000/02/02 03:59:14  timj
#Fix typo in pod
#
#Revision 1.46  2000/02/01 03:14:47  timj
#Add CCDPACK_VERSION
#Rename KAPVERSION to KAPPA_VERSION
#
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
