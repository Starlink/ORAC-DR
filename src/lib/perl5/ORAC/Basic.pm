package ORAC::Basic;

=head1 NAME

ORAC::Basic - some implementation subroutines

=head1 SYNOPSIS

  use ORAC::Basic;

  $Display = orac_setup_display;
  orac_exit_normally($message);
  orac_exit_abnormally($message);

=head1 DESCRIPTION

Routines that do not have a home elsewhere.

=cut

use Carp;
use vars qw($VERSION @EXPORT $Beep @ISA);
use strict;
use warnings;

require Exporter;
use File::Path;
use File::Copy;
use File::Spec;

use ORAC::Print;
use ORAC::Display;
use ORAC::Error qw/:try/;
use ORAC::Constants qw/:status/;
use ORAC::Inst::SetupEnv;

@ISA = qw(Exporter);

@EXPORT = qw/  orac_setup_display orac_exit_normally orac_exit_abnormally
               orac_force_abspath orac_chdir_output_dir
            /;

$VERSION = '1.0';

$Beep    = 0;                   # True if ORAC should make noises


#------------------------------------------------------------------------

=head1 FUNCTIONS

The following functions are provided:

=over 4

=item B<orac_force_abspath>

Force ORAC_DATA_IN and ORAC_DATA_OUT to use an absolute path
rather than a relative path. Must be called before pipeline
does the first chdir.

 orac_force_abspath();

Does not canonicalize.

=cut

sub orac_force_abspath {
  for my $env (qw/ ORAC_DATA_IN ORAC_DATA_OUT /) {
    $ENV{$env} = File::Spec->rel2abs( $ENV{$env} )
      if exists $ENV{$env};
  }
}


=item B<orac_setup_display>

Create a new Display object for use by the recipes. This includes
the association of this object with a specific display configuration
file (F<disp.dat>). If a configuration file is not in $ORAC_DATA_OUT
one will be copied there from $ORAC_DATA_CAL (or $ORAC_DIR
if no file exists in $ORAC_DATA_CAL).

If the $DISPLAY environment variable is not set, the display
subsystem will be started but only for use by monitor programs.

The display object is returned.

  $Display = orac_setup_display;

Hash arguments can control behaviour to indicate master vs monitor
behaviour. Options are:

  - monitor =>  configure as a monitor (default is to be master) (false)
  - nolocal =>  disable master display, monitor files only.
                Default is to display locally (false)

Monitor files are always written if a master.

=cut

# Simply create a display object
sub orac_setup_display {

  my %options = ( monitor => 0, nolocal => 0, @_ );

  # Check for DISPLAY being set - not needed if we are not displaying locally
  if (!$options{monitor}) {
    if (!$options{nolocal}) {
      unless (exists $ENV{DISPLAY}) {
        $options{nolocal} = 1;
        warn 'DISPLAY environment variable unset - configuring display for monitoring';
      }
    }
  } elsif ($options{monitor}) {
    # We are a monitor, so we must have a display
    unless (exists $ENV{DISPLAY}) {
      warn "DISPLAY environment variable unset - no display available";
      return;
    }
  }

  # Set this global variable
  my $Display = new ORAC::Display;

  # Configure it
  if ($options{monitor}) {
    $Display->is_master( 0 );
  } else {
    $Display->is_master( 1 );
    if ($options{nolocal}) {
      $Display->does_master_display( 0 );
    } else {
      $Display->does_master_display( 1 );
    }
  }

  # Set the location of the display definition file
  # (we do not currently use NBS for that)

  # It is preferable for this to be instrument specific. The working
  # copy is in ORAC_DATA_OUT. There is a system copy in ORAC_DIR
  # but preferably there is an instrument-specific in ORAC_DATA_CAL
  # designed by the support scientist

  my $systemdisp = File::Spec->catfile($ENV{'ORAC_DIR'}, "disp.dat");
  my $defaultdisp = File::Spec->catfile($ENV{'ORAC_DATA_CAL'}, "disp.dat");
  my $dispdef = File::Spec->catfile($ENV{'ORAC_DATA_OUT'}, "disp.dat");

  unless (-e $defaultdisp) {
    $defaultdisp = $systemdisp;
  }
  ;

  unless (-e $dispdef) {
    copy($defaultdisp,$dispdef);
  }
  ;

  # Set the display filename
  $Display->filename($dispdef);

  # GUI launching goes here....

  # orac_err('GUI not launched');
  return $Display;
}

=item B<orac_exit_normally>

Standard exit handler for oracdr. Should be called instead of C<exit()>
when the pipeline is complete.

Hash arguments control the behaviour. Allowed keys are:

  quiet - Do not print any informational messages to stdout (default is false)
  message - Any string to be printed
  err   - true if the supplied message is an error message
          or if the process should exit with bad status (default is false
          unless error stack is populated)

If called with a single argument, it is assumed to be an informational
message and is equivalent to using the "message" argument. "err" will
default to true if we are called when there are messages in the
ORAC::Error stack.

Message is printed using orac_err if we know it is an error message.
It will be printed even if "quiet" is true.

=cut

sub orac_exit_normally {
  my %args = (quiet => 0,
              message => '',
              err => 0);

  if (@_ == 1) {                # backwards compatible
    $args{message} = shift;
  } else {
    %args = (%args, @_ );
  }

  # We are dying, and don't care about any further outstanding errors
  # flush the queue so we have a clean exit.
  my $error = ORAC::Error->prior;
  if (defined $error) {
    ORAC::Error->flush;
    $args{err} = 1;             # force true
  }

  # redefine the ORAC::Print bindings
  my $msg_prt  = new ORAC::Print;   # For message system
  my $msgerr_prt = new ORAC::Print; # For errors from message system
  my $orac_prt = new ORAC::Print;   # For general orac_print

  # Debug info
  orac_print ("Exiting...\n","red") unless $args{quiet};

  rmtree $ENV{'ADAM_USER'}      # delete process-specific adam dir
    if defined $ENV{ADAM_USER};

  # Ring a bell when exiting if required
  if ($Beep) {
    for (1..5) {
      print STDOUT "\a"; select undef,undef,undef,0.2;
    }
  }

  # Cleanup Tk window(s) if they are still hanging around
  ORAC::Event->destroy("Tk");
  ORAC::Event->unregister("Tk");

  # Flush the error stack if all we have is an ORAC::Error::UserAbort

  if ($args{message}) {
    if ($args{err}) {
      orac_errp ($args{message});
    } elsif (!$args{quiet}) {
      orac_err ( "\n" );
      orac_printp ($args{message},"red");
    }
  }

  if (!$args{quiet}) {
    orac_print ( "\n" );
    orac_printp ("Goodbye\n","red");
  }

  if ($args{err}) {
    orac_print("Will be exiting with bad status\n",'red');
    exit 1;
  } else {
    exit 0;
  }
}

=item B<orac_exit_abnormally>

Exit handler when a problem has been encountered. Normally
used a signal handler for SIGINT.

=cut

sub orac_exit_abnormally {
  my $signal = '';
  $signal = shift if @_;

  # redefine the ORAC::Print bindings
  my $msg_prt  = new ORAC::Print;   # For message system
  my $msgerr_prt = new ORAC::Print; # For errors from message system
  my $orac_prt = new ORAC::Print;   # For general orac_print

  # Try and cleanup, untested, I can't get it to exit abnormally
  ORAC::Event->destroy("Tk");
  ORAC::Event->unregister("Tk");

  # Dont delete tree since this routine is called from INSIDE recipes

  # ring my bell, baby
  if ($Beep) {
    for (1..10) {
      print STDOUT "\a"; select undef,undef,undef,0.2;
    }
  }

  die "\n\nAborting from ".ORAC::Version->getApp." - $signal received\n";

}


=item B<orac_chdir_output_dir>

Change to the output directory. If that fails, exit the pipeline.

  orac_chdir_output_dir();

Default output directory is controlled by ORAC_DATA_OUT environment
variable.

Takes one argument, a boolean dictating whether or not a check that
the data is on an NFS disk should be done. By default this check is
done, and if ORAC_DATA_OUT is on an NFS-mounted disk, then the
pipeline will exit.

=cut

sub orac_chdir_output_dir {
  my $nfs_check = shift;

  # Force absolute path
  orac_force_abspath();

  if (exists $ENV{ORAC_DATA_OUT}) {

    if ( ! defined( $nfs_check ) || $nfs_check ) {
      my $nfs = ORAC::Inst::SetupEnv::is_nfs_disk( $ENV{ORAC_DATA_OUT});
      if ($nfs) {
        if (exists $ENV{ORAC_NFS_OK} && $ENV{ORAC_NFS_OK}) {
          orac_warn( "ORAC_DATA_OUT appears to be on a disk mounted from $nfs.\n" );
          orac_warn( "Continuing to run reduction based on environment variable override.\n");
        } else {
          orac_err( "ORAC_DATA_OUT appears to be on a disk mounted from $nfs.\n" );
          orac_err( "In many cases the performance degradation on a remote disk is too high.\n");
          orac_err( "Please use a local disk for data processing.\n" );
          orac_err( "If you know you have a high performance NFS system set the ORAC_NFS_OK environment variable to 1\n");
          orac_exit_normally();
        }
      }
    }

    # change to output  dir
    chdir($ENV{ORAC_DATA_OUT}) ||
      do {
        orac_err("Could not change directory to ORAC_DATA_OUT: $!");
        orac_exit_normally();
      };

  } else {
    orac_err("ORAC_DATA_OUT environment variable not set. Aborting\n");
    orac_exit_normally();
  }
  return;
}

=back

=head1 REVISION

$Id$

=head1 SEE ALSO

L<ORAC::Core>, L<ORAC::General>

=head1 AUTHORS

Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
