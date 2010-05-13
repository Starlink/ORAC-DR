package ORAC::Inst::SetupEnv;

=head1 NAME

ORAC::Inst::SetupEnv - Setup instrument environment

=head1 SYNOPSIS

  use ORAC::Inst::SetupEnv

  %env = orac_calc_instrument_settings( $inst );

=head1 DESCRIPTION

This module provides all the code necessary to initialise the
environment variables for orac-dr in a consistent manner. It is
intended to be used by Xoracdr (via ORAC::Inst::Defn) and the
initialisation shell scripts whilst including a minimal set of perl
modules (and no additional ORAC-DR dependencies).

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use File::Spec;
use Net::Domain;
use Sys::Hostname;
use Fcntl ":mode";

use ORAC::General;  # utdate()

our $DEBUG = 0;

=head1 FUNCTIONS

=over 4

=item B<orac_calc_instrument_settings>

Calculate the default environment variable settings for the supplied
instrument. Can be called from both Xoracdr and the shell initialisation
scripts.

  %env = orac_calc_instrument_settings( $instrument, %options );

Returns a hash with keys corresponding to the environment variables
and values being the suggested settings. A special key in the hash
named "args" contains suggested command-line arguments for oracdr,
as a reference to a hash.

Argument is the ORAC-DR instrument name and the UT date. Additional
switches can be supplied as a hash. Allowed keys are:

 cwd => Use the current working directory for ORAC_DATA_OUT
 honour => If ORAC_DATA_OUT is set, do not override it
 ut => Specify UT date. Defaults to current.
 eng => Boolean indicating whether engineering directories
        are to be selected.
 mode => QL or SUMMIT pipeline. Undef defaults to standard.

If both cwd and honour are supplied, honour will take precedence
if a valid directory is present in ORAC_DATA_OUT.

=cut

sub orac_calc_instrument_settings {
  my $oracinst = shift;
  my %options = @_;

  croak "No instrument supplied!"
    unless defined $oracinst;
  $oracinst = uc($oracinst);

  # Sanity check since this code may be called outside of oracdr
  croak "ORAC_DIR environment variable not set!"
    unless (exists $ENV{ORAC_DIR} && defined $ENV{ORAC_DIR});
  croak "ORAC_DIR environment variable does not point to a directory"
    unless -d $ENV{ORAC_DIR};

  # Default to today if not given. Also check to see if we have
  # been told to use today
  my $today = ORAC::General::utdate();
  if (!defined $options{ut}) {
    $options{ut} = $today;
  }
  my $istoday = ($options{ut} == $today ? 1 : 0);

  # Place to put the results
  my %env;

  # Set ORAC_DATA_OUT here if required
  my $fixout;
  if ($options{honour} && exists $ENV{ORAC_DATA_OUT} &&
      defined $ENV{ORAC_DATA_OUT} && -d $ENV{ORAC_DATA_OUT}) {
    $env{ORAC_DATA_OUT} = $ENV{ORAC_DATA_OUT};
    $fixout = 1;
  } elsif ($options{cwd}) {
    $env{ORAC_DATA_OUT} = File::Spec->rel2abs( File::Spec->curdir );
    $fixout = 1;
  }

  # Some instrumentation changes internal ORAC instrument based on UT
  # date.
  if ($oracinst eq 'GMOS' && $options{ut} < 20020301) {
    $oracinst = "GMOS2";
    # then override
    $env{ORAC_INSTRUMENT} = $oracinst;
  }
  if ($oracinst eq 'NIRI' && $options{ut} < 20020301) {
    $oracinst = "NIRI2";
    # then override
    $env{ORAC_INSTRUMENT} = $oracinst;
  }

  # where are we running
  my $site = orac_determine_location();

  # What's our computer name?
  my $hostname = hostname();

  # Work out our default calibration root directory
  if ( exists $ENV{ORAC_CAL_ROOT} && defined $ENV{ORAC_CAL_ROOT} ) {
    $env{ORAC_CAL_ROOT} = $ENV{ORAC_CAL_ROOT};
  } else {
    $env{ORAC_CAL_ROOT} = File::Spec->catfile( $ENV{ORAC_DIR}, File::Spec->updir, "cal" );
  }

  # Handle logging
  if ( !exists $ENV{ORAC_LOGDIR} || !defined $ENV{ORAC_LOGDIR}) {
    if (-d "/jac_logs/oracdr") {
      $env{ORAC_LOGDIR} = "/jac_logs/oracdr";
    }
  }

  # Command line arguments
  my %args;

  # Special case for WFCAM and SCUBA2 (and GMOS).
  my $inst = $oracinst;
  if( $inst =~ /^WFCAM/ ) {
    $inst = "WFCAM";
  } elsif ( $inst =~ /^SCUBA2/ ) {
    $inst = "SCUBA2";
  } elsif ( $inst =~ /^GMOS/) {
    $inst = "GMOS";
  }

  # CURVE is odd in that it's not a real ORAC instrument at all
  if ($inst eq 'CURVE') {
    $oracinst = "UFTI";
    $env{ORAC_INSTRUMENT} = $oracinst;
  }

  # ACSIS does not support -eng mode
  if ($inst eq 'ACSIS' && $options{eng}) {
    print STDERR " ** ACSIS does not support an engineering mode **\n";
    $options{eng} = 0;
  }

  # Root of tree
  # Default ORAC_DATA_ROOT directories.
  my %dataroot_default = ( 'ACSIS'  => "jcmtdata",
                           'CGS4'   => "ukirtdata",
                           'CURVE'  => "ukirtdata",
                           'IRCAM'  => "ukirtdata",
                           'IRCAM2' => "ukirtdata",
                           'IRIS2'  => "irisdata",
                           'MICHELLE' => "ukirtdata",
                           'OCGS4'    => "ukirtdata",
                           "SCUBA"    => "jcmtdata",
                           'SCUBA2'   => "jcmtdata",
                           "UFTI"     => "ukirtdata",
                           'UFTI2'    => "ukirtdata",
                           "UFTI_CASU" => "ukirtdata",
                           'UIST'     => "ukirtdata",
                           'WFCAM'  => "ukirtdata",
                         );

  # Default drN directories for ACSIS and SCUBA-2.
  my %dr_default = ( 'acsis'        => 'dr1',
                     'scuba2_850'  => 'dr1',
                     'scuba2_450' => 'dr1',
                   );

  # We check to make sure that ORAC_DATA_ROOT exists if set
  if (exists $ENV{ORAC_DATA_ROOT} && defined $ENV{ORAC_DATA_ROOT}) {
    croak "ORAC_DATA_ROOT set to '$ENV{ORAC_DATA_ROOT}' but this directory does not exist"
      unless -d $ENV{ORAC_DATA_ROOT};
    $env{ORAC_DATA_ROOT} = $ENV{ORAC_DATA_ROOT};
  } else {
    # Make sure the default exists, else use current working directory
    my $dataroot;
    if (exists $dataroot_default{$inst}) {
      # try some different locations: aka "/", "/Volumes" (for Mac), "." (just in case)
      for my $parent (File::Spec->rootdir,
                      File::Spec->catdir( File::Spec->rootdir, "Volumes"),
                      File::Spec->rel2abs( File::Spec->curdir ) ) {
        my $dr = File::Spec->catdir( $parent, $dataroot_default{$inst} );
        if (-d $dr) {
          $dataroot = $dr;
          last;
        }
      }
    }
    # if we still have nothing just take a guess
    if (!defined $dataroot) {
      $dataroot = File::Spec->rel2abs( File::Spec->curdir );
      print STDERR "Can not find data directory in default locations so using current directory\n";
    }
    $env{ORAC_DATA_ROOT} = $dataroot;
  }
  my $dataroot = $env{ORAC_DATA_ROOT};

  # Get default looping. Will be domain dependent
  $env{ORAC_LOOP} = orac_determine_loop_behaviour( $oracinst );

  # Constructor for simple ukirt-style instruments that follow a root/raw/inst/ut directory layout
  my $ukirt_con = sub {
    my $root = shift;
    my $auth = shift;
    my $sun  = shift;
    my $localut = shift || $options{ut};
    my @eng = ($options{eng} ? ("eng") : ());
    return ( ORAC_DATA_CAL => File::Spec->catdir( $env{'ORAC_CAL_ROOT'}, $root ),
             ORAC_DATA_IN => File::Spec->catdir( $dataroot, "raw", @eng, $root, $localut ),
             ( $fixout ? () : (ORAC_DATA_OUT => File::Spec->catdir( $dataroot, "reduced", @eng, $root, $localut ))),
             ORAC_SUN => $sun,
             ORAC_PERSON => $auth,
           );
  };

  # Constructor for JCMT-style instruments.
  my $jcmt_con = sub {
    my $root = shift;
    my $auth = shift;
    my $sun  = shift;
    my $localut = shift || $options{'ut'};
    my @eng = ( $options{'eng'} ? ( "eng" ) : () );

    # Set up the reduced data directory. This depends on the hostname,
    # and site, but strip off the sc2.
    my @drn;
    if ($site eq 'jcmt') {
      my $drN = $hostname;
      $drN =~ s/sc2//;
      if( $drN !~ /^dr\d$/ ) {
	$drN = $dr_default{$root};
	print STDERR "Not running pipeline on sc2drN machine. Using default $drN as part of output directory structure.\n";
      }
      push(@drn, $drN);
    }

    return ( ORAC_DATA_CAL => File::Spec->catdir( $env{'ORAC_CAL_ROOT'}, $root ),
             ORAC_DATA_IN  => File::Spec->catdir( $dataroot, "raw", $root, @eng, $localut ),
             ( $fixout ? () : ( ORAC_DATA_OUT => File::Spec->catdir( $dataroot, "reduced", @drn, $root, @eng, $localut ) ) ),
             ORAC_SUN => $sun,
             ORAC_PERSON => $auth,
           );
  };

  # IRIS-2 has truncated ut data directories
  my $iris2_con = sub {
    # AAT uses truncated directory names
    my $auth = "oracdr_iris2\@jach.hawaii.edu";
    my $sun = "230,232,236";
    my $ut = substr($options{ut},2);
    my %defaults = $ukirt_con->( "iris2", $auth, $sun, $ut );
    # if we are at the AAT we use different trees
    if ($site eq 'aat') {
      $defaults{ORAC_DATA_IN} = File::Spec->catdir( File::Spec->rootdir, "data_vme10",
                                                    "aatobs", "iris2_data", $ut );
      $defaults{ORAC_DATA_OUT} = File::Spec->catdir( File::Spec->rootdir, "iris2_reduce",
                                                     "iris2red", $ut ) unless $fixout;
      _mkdir( $defaults{ORAC_DATA_OUT} );
    }
    return %defaults;
  };

  # SCUBA data directories are non-standard but on the plus side we only have to worry
  # about historical processing and do not have to try to sort out summit reduced
  # directories.
  my $scuba_con = sub {
    # If we are using /scuba we need to know the semester
    my $sem = "m" . &_determine_semester( $options{ut} );

    return ( ORAC_DATA_CAL => File::Spec->catdir( $env{'ORAC_CAL_ROOT'}, "scuba" ),
            "ORAC_DATA_IN" => File::Spec->catdir( $dataroot, "scuba",
                                                  $sem, $options{ut} ),
            ( $fixout ? () : (ORAC_DATA_OUT => File::Spec->catdir( $dataroot, "reduced", "scuba", $options{ut}))),
           );
  };

  # summit standards conventions involve the creation of the data directory
  # at the summit for some instruments

  my $wfcam_con = sub {
    my @eng = ($options{eng} ? ("eng") : ());
    my %defaults = $ukirt_con->( "wfcam", @_ );
    $defaults{ORAC_DATA_IN} = File::Spec->catdir( $dataroot, "raw", @eng,
                                                   lc($oracinst), $options{ut} );
    my $outdir;
    if ($fixout) {
      $outdir = $env{ORAC_DATA_OUT};
    } else {
      $outdir =  File::Spec->catdir( $dataroot, "reduced", @eng,
                                     lc($oracinst), $options{ut} );
      _mkdir_wfcam($outdir);
      $defaults{ORAC_DATA_OUT} = $outdir;
    }

    # Make sure that we use a shared RTD_REMOTE_DIR for each night
    # but only if we are at the summit
    if ($site eq 'ukirt') {
      my $rtddir;
      if (!$options{eng}) {
        $rtddir = _parentdir( $outdir );
      } else {
        # in -eng mode we make sure we use the non-eng directory tree
        $rtddir = File::Spec->catdir( $dataroot, "reduced", lc($oracinst) );
      }
      if (-d $rtddir) {
        $defaults{ORAC_RESPECT_RTD_REMOTE} = 1;
        $defaults{RTD_REMOTE_DIR} = $rtddir;
      }
    }

    return %defaults;
  };

  my $acsis_con = sub {
    my %defaults = $jcmt_con->( "acsis", @_ );
    $defaults{ORAC_DATA_OUT} = _mkdir_jcmt( $defaults{ORAC_DATA_OUT} )
      unless $fixout;
    return %defaults;
  };

  # SCUBA-2 reads from a ok directory
  my $scuba2_con = sub {
    # The summit reduced directory depends on the orac_instrument variable.
    my %path = ( SCUBA2_850 => "scuba2_850",
                 SCUBA2_450 => "scuba2_450",);

    if (!exists $path{$oracinst}) {
      print STDERR "Unrecognized SCUBA-2 instrument type: $oracinst. Using SCUBA2_850\n";
      $oracinst = "SCUBA2_850";
    }

    my %defaults = $jcmt_con->( $path{$oracinst} );

    my @eng = ($options{eng} ? ("eng") : ());

    my %remote;
    if (exists $options{mode} && defined $options{mode}) {
      if ($options{mode} eq 'QL') {
        # Decide which remote tasks to talk to
        if ($oracinst eq 'SCUBA2_850') {
          $remote{ORAC_REMOTE_TASK} = 'SC2DA8A@sc2da8a';
        } elsif ($oracinst eq 'SCUBA2_450') {
          $remote{ORAC_REMOTE_TASK} = 'SC2DA4A@sc2da4a';
        }
      }
    }

    $defaults{ORAC_DATA_OUT} = _mkdir_jcmt( $defaults{ORAC_DATA_OUT} )
      unless $fixout;

    # Override defaults.
    $defaults{'ORAC_DATA_CAL'} = File::Spec->catdir( $env{'ORAC_CAL_ROOT'}, "scuba2" );
    $defaults{'ORAC_DATA_IN'} = File::Spec->catdir( $dataroot, "raw", "scuba2", "ok", @eng, $options{ut} );

    return ( %defaults, %remote );
  };

  # Arguments to use for the alias.

  # Always return -ut argument.
  my $oracdr_args = sub {
    my %extras = ( );
    return ( "-ut" => $options{ut}, %extras );
  };

  # UKIRT instruments use transient groups
  my $ukirt_args = sub {
    return ( $oracdr_args->(),
             "-grptrans" => undef,
           );
  };

  # SCUBA-2 and ACSIS support recsuffix options
  # Add -batch if not today.
  my $jcmt_args = sub {
    my @rec;
    if (exists $options{mode} && defined $options{mode}) {
      if ($options{mode} eq 'QL') {
        push(@rec, "-recsuffix", "QL" );
        # SCUBA2 disables the display in QL mode and uses DRAMA
        if ($inst eq 'SCUBA2') {
          push(@rec,  "-loop" => "task" );
        }
      } elsif ($options{mode} eq 'SUMMIT') {
        push(@rec, "-recsuffix", "SUMMIT");
      }
    }
    if( ! $istoday ) {
      push( @rec, "-batch" => undef );
    }
    return ( $oracdr_args->(), @rec );
  };


  # Now the instrument specific code. We first set up a hash with the obvious defaults.
  # We use coderefs to insert dynamic values. Note that we use sub{} instead of directly
  # executing a coderef inline to prevent additional code triggering for the wrong instrument.
  # The _args coderefs are mean to be innocuous.
  my %default_envs = ( 'ACSIS'  => { code => sub { $acsis_con->( "jcmtdr\@jach.hawaii.edu", "XXX" ); },
                                     ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "acsis", "spectra", $options{ut} ),
                                     ORAC_LOOP => "flag -skip",
                                     args => { $jcmt_args->() },
                                   },
                       'CGS4'   => { code => sub { $ukirt_con->( "cgs4", "stardev\@jach.hawaii.edu", "236" ) },
                                     ORAC_LOOP => "flag -skip",
                                     args => { $ukirt_args->() },
                                   },
                       "CLASSICCAM" => { code => sub { $ukirt_con->( "classiccam", "mjc\@star.rl.ac.uk", "232" ) },
                                         ORAC_LOOP => "flag -skip",
                                         args => { $ukirt_args->() },
                                       },
                       'CURVE'    => { code => sub { $ukirt_con->( "curve", "stardev\@jach.hawaii.edu", "236" ) },
                                       ORAC_DATA_CAL => File::Spec->catfile( $env{ORAC_CAL_ROOT}, "ufti" ),
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },
                                   },
                       'GMOS'     => { code => sub { $ukirt_con->( "gmos", "p.hirst\@gemini.edu", "XXX" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       "INGRID"    => { code => sub { $ukirt_con->( "ingrid", "mjc\@star.rl.ac.uk", "232" ) },
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       # This is old IRCAM
                       'IRCAM'  => { ORAC_DATA_CAL => File::Spec->catfile( $env{'ORAC_CAL_ROOT'}, "ircam" ),
                                     ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "ircam",$options{ut}, "rodir" ),
                                     ($fixout ? () :
                                      (ORAC_DATA_OUT => File::Spec->catfile( $dataroot,
                                                                             "raw", "ircam", $options{ut}, "rodir" ))),
                                     ORAC_PERSON => 'stardev\@jach.hawaii.edu',
                                     ORAC_SUN => '232',
                                     ORAC_LOOP => "wait",
                                     args => { $ukirt_args->() },
                                   },
                       'IRCAM2' => { code => sub { $ukirt_con->("ircam", "stardev\@jach.hawaii.edu", "232" ) },
                                     ORAC_LOOP => "flag -skip",
                                     args => { $ukirt_args->() }, },
                       'IRIS2'     => { code => sub { $iris2_con->() },
                                        ORAC_LOOP => "wait",
                                        args => { $oracdr_args->() }, },
                       'ISAAC'     => { code => sub { $ukirt_con->( "isaac", "mjc\@star.rl.ac.uk", "232,236" ) },
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       # experimental
                       "JCMT_DAS" => { code => sub { $ukirt_con->( "heterodyne", "jcmtdr\@jach.hawaii.edu", "230" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $oracdr_args->() }, },
                       'MICHELLE' => { code => sub { $ukirt_con->( "michelle", "stardev\@jach.hawaii.edu", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },},
                       'NACO'     => { code => sub { $ukirt_con->( "naco", "mjc\@star.rl.ac.uk", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       'NIRI'     => { code => sub { $ukirt_con->( "niri", "p.hirst\@gemini.edu", "XXX" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },},
                       # Old CGS4
                       'OCGS4'    => { code => sub { $ukirt_con->( "cgs4", "stardev\@jach.hawaii.edu", "236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       "SCUBA"     => { code => sub { $scuba_con->() },
                                        ORAC_PERSON => "jcmtdr\@jach.hawaii.edu",
                                        ORAC_SUN => "231",
                                       ORAC_LOOP => "flag -skip",
                                        args => { $oracdr_args->(), "-loop" => "flag", "-skip" => undef },
                                      },
                       "SCUBA2"   => { code => sub { $scuba2_con->() },
                                       ORAC_PERSON => "scuba2dr\@phas.ubc.ca",
                                       ORAC_SUN  => "264",
                                       ORAC_LOOP => "flag -skip",
                                       args => { $jcmt_args->() },
                                     },
                       'SOFI'     => { code => sub { $ukirt_con->( "sofi", "mjc\@star.rl.ac.uk", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       # New UFTI (non-FITS)
                       'UFTI2'    => { code => sub { $ukirt_con->( "ufti", "stardev\@jach.hawaii.edu", "232" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       'UFTI_CASU' => { code => sub { $ukirt_con->( "ufti", "jrl\@ast.cam.ac.uk", "232" ) },
                                        ORAC_DATA_CAL => File::Spec->catdir($env{ORAC_DATA_CAL}, "ufti_casu" ),
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       'UIST'     => { code => sub { $ukirt_con->( "uist", "stardev\@jach.hawaii.edu", "232,236,246" ) },
                                       args => { $ukirt_args->() },
                                       ORAC_LOOP => "$env{ORAC_LOOP} -skip",
                                     },
                       'WFCAM'  => { code => sub { $wfcam_con->( "stardev\@jach.hawaii.edu", "XXX" ) },
                                     ORAC_LOOP => "flag",
                                     args => { $ukirt_args->() },
                                   },
                    );

  # These are identical for the moment
  $default_envs{UFTI} = $default_envs{UFTI2};
  $default_envs{MICHGEM} = $default_envs{MICHELLE};
  $default_envs{NIRI2} = $default_envs{NIRI};

  if (!exists $default_envs{$inst}) {
    my $aka = '';
    if ($inst ne $oracinst) {
      $aka = "($oracinst)";
    }
    croak "Instrument '$inst' $aka not recognized by ORAC-DR\n";
  }

  # Handle code refs first so that explicit values will override
  my $this_env = $default_envs{$inst};
  if (exists $this_env->{code}) {
    %env = ( %env, $this_env->{code}->() );
    delete $this_env->{code};
  }

  # Copy in the standard static values
  %env = ( %env, %{$this_env});

  # Use notification system. Put in an eval since we do not want
  # to stop initialisation
  eval {
    require ORAC::Print;
    ORAC::Print::orac_notify( ORAC::Print::NOT__INIT(),
                              "Pipeline initialisation complete",
                              "Initialised for instrument $inst and UT date $options{ut}" );
  };

  if ($DEBUG) {
    $Data::Dumper::SortKeys = 1;
    print Dumper(\%env);
  }
  return %env;
}

=item B<is_nfs_disk>

Returns the name of the remote NFS server if the path corresponds to an NFS disk,
undef if it is local or if it does not actually exist.

  $isnfs = is_nfs_disk( $path );

Will not be portable since "df" is called.

=cut

sub is_nfs_disk {
  my $path = shift;
  return unless -d $path;

  my $df_args;
  if ($^O eq 'linux') {
    $df_args = "-T $path";
  } elsif ($^O eq 'darwin') {
    $df_args = "-T nfs,autofs $path";
  } else {
    carp "Do not know how to check for NFS disk on system $^O. Assuming local disk\n";
    return;
  }

  open my $fh, "df $df_args |" or croak "Could not open df command: $!";
  my @results = <$fh>;
  close($fh);

  if ($^O eq 'linux') {
    # in general, the presence of a line xxx:/yyy should tell us this
    # is a remote disk regardless of the -T option but we play it safe.
    if (scalar grep { /\bnfs\b/ } @results) {
      for my $row (@results) {
        if ($row =~ /^(\w+):\//) {
          return $1;
        }
      }
    }
  } elsif ($^O eq 'darwin') {
    # so long as the path includes a directory beyond the mountpoint
    # we do not need to run ls first and can simply check for a colon
    for my $row (@results) {
      if ($row =~ /^(\w+):\//) {
        return $1;
      }
    }
  }

  return;
}

=item B<orac_determine_location>

Returns "hilo", "jcmt", "ukirt", "aat", "ing" or false depending on whether
the code is running in Hilo, JCMT, UKIRT, AAT or elsewhere.

The value is cached since it will not change during execution.

=cut

{
my $site = '';
sub orac_determine_location {
  return $site if $site;
  my $dname;
  if (exists $ENV{SITE}) {
    $dname = $ENV{SITE};
    if ($dname =~ /hilo/i) {
      $site = "hilo";
    } elsif ($dname =~ /jcmt/i) {
      $site = "jcmt";
    } elsif ($dname =~ /ukirt/i) {
      $site = "ukirt";
    }
    return $site if $site;
  }

  if (!defined $ENV{ORAC_NO_NET}) {
    $dname = Net::Domain->domainname;
    if ($dname =~ /(jcmt.jach.hawaii.edu|JAC.jcmt)$/ ) {
      $site = "jcmt";
    } elsif ($dname =~ /(ukirt.jach.hawaii.edu|JAC.ukirt)$/ ) {
      $site = "ukirt";
    } elsif ($dname =~ /(jach.hawaii.edu|JAC.Hilo)/ ) {
      # poma reports .edu.edu !!
      $site = "hilo";
    } elsif ($dname =~ /aat/i) {
      $site = "aat";
    } elsif ($dname =~ /ing/i) {
      $site = "ing";
    }
    return $site if $site;
  }

  # got here we do not know
  return $site;
}
}

=item B<orac_determine_loop_behaviour>

This routine determines the default loop behaviour for a the instrument.
It does so by determining if ORAC-DR is being run at UKIRT, JCMT, Hilo,
or some other location, then returning a string for the specific loop
behaviour.

   orac_determine_loop_behaviour( $instrument );

If the instrument is not SCUBA, CGS4, IRCAM, UFTI, or Michelle, or
ORAC-DR is not being run at UKIRT, JCMT, or Hilo, then the loop behaviour
will default to 'list'. This routine is meant to be called by xoracdr,
and the return values are those listed in the loop options in that
program.

=cut

sub orac_determine_loop_behaviour {

  croak 'Usage: orac_determine_loop_behaviour( $instrument )'
    unless scalar(@_) == 1 ;

  my ( $instrument ) = @_;
  my $behaviour = 'list'; # default value

  my $dname = orac_determine_location();
  return $behaviour unless defined $dname;

  if ( $dname eq 'jcmt' ) {

    if ( uc($instrument) eq 'SCUBA' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'JCMT_DAS' ) {
      $behaviour = 'wait';
    } elsif( uc($instrument) =~ /^ACSIS/ ) {
      $behaviour = 'flag';
    }

  } elsif ( $dname eq 'ukirt' ) {

    if ( uc($instrument) eq 'CGS4' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'IRCAM' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'UFTI' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'MICHELLE' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'UFTI2' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) =~ /^WFCAM/ ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'IRCAM2' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'UIST' ) {
      $behaviour = 'flag';
    } elsif ( uc($instrument) eq 'NIRI' || uc($instrument) eq 'NIRI2' ) {
      $behaviour = 'flag';
    }

  } elsif ( $dname eq "aat" ) {
    if ( uc($instrument) eq 'IRIS2' ) {
       $behaviour = 'wait';
    }

  } elsif ( $dname eq 'hilo' ) {
    $behaviour = 'list';
  } elsif ( $dname eq 'ing' ) {
    if ( uc($instrument) eq 'INGRID') {
      $behaviour = "flag";
    }
  }

  return $behaviour;

}

=item B<orac_validate_datadirs>

Given a hash reference containing keys ORAC_DATA_OUT and ORAC_DATA_IN,
see if those values are valid and update if required.

  orac_validate_datadirs( \%env );

Messages are sent to STDERR.

=cut

sub orac_validate_datadirs {
  my $env = shift;

  # Cache current working directory
  my $curdir = File::Spec->rel2abs( File::Spec->curdir );

  # Special case. If ORAC_DATA_OUT/.. corresponds to a local
  # directory and it is not on NFS, attempt to create it.
  if (!-d $env->{ORAC_DATA_OUT}) {
    my $updir = _parentdir($env->{ORAC_DATA_OUT});
    if (-d $updir && !is_nfs_disk($updir)) {
      _mkdir( $env->{ORAC_DATA_OUT} );
    }
  }

  # Check the data directories and suggest alternatives if available
  my $newin = _checkdir( $env->{ORAC_DATA_IN} );
  my $newout = _checkdir( $env->{ORAC_DATA_OUT} );

  if ( ! defined $newin ) {
    print STDERR "Unable to locate a raw data directory. Please fix ORAC_DATA_IN\n";
  }

  if ( ! defined $newout ) {
    print STDERR "Default output directory ($env->{ORAC_DATA_OUT}) does not exist. Assuming current directory.\n";
    $env->{ORAC_DATA_OUT} = $curdir;
  }

  if (defined $newin && defined $newout) {
    # if input and output are the same, we are not really
    # sure which one to use. This would usually indicate that
    # we found a UT date directory in the current directory

    # How clever do we want to be?
    if ($newin eq $newout) {
      my $usein;                # use it as input directory
      my $useout;               # use it as output directory
      opendir my $dh, $newin or die "Could not read directory $newin: $!\n";
      my @files = readdir( $dh );
      # these are all just guesses. .sdf can be in either directory in reality
      if (scalar grep /\.ok$/, @files) {
        # this is an input directory.
        $usein = 1;
      } elsif (scalar grep /^(\.orac|index)/, @files) {
        # has pipeline files in it
        $useout = 1;
      } else {
        # if we were really clever we would ask the ORAC::Frame class to see if there
        # are a few files in the directory that it recognizes
      }

      if ($usein) {
        $env->{ORAC_DATA_IN} = $newin;
        $env->{ORAC_DATA_OUT} = $curdir;
        print STDERR "ORAC_DATA_OUT does not exist. Using current working directory.\n";
      } elsif ($useout) {
        $env->{ORAC_DATA_OUT} = $newout;
        print STDERR "ORAC_DATA_IN does not exist. Please set before running pipeline.\n";
      } else {
        $env->{ORAC_DATA_OUT} = $curdir;
        $env->{ORAC_DATA_IN} = $newin;
        print STDERR "ORAC_DATA_OUT does not exist. Using current working directory.\n";
        print STDERR "ORAC_DATA_IN does not exist. Guessing but please set before running pipeline.\n";
      }

    } else {
      # assume these are the right ones
      $env->{ORAC_DATA_IN} = $newin;
      $env->{ORAC_DATA_OUT} = $newout;
    }
  }

}

=back

=begin __PRIVATE__METHODS__

=head1 PRIVATE FUNCTIONS

Includes instrument setup support classes.

=over 4

=item B<_mkdir>

Make the output directory only if the parent directory is not on NFS.

  _mkdir( $path );

Also sets permissions to include the group sticky bit. Can croak.

=cut

sub _mkdir {
  my $path = shift;
  my $updir = _parentdir( $path );
  my $nfs = is_nfs_disk( $updir );
  if (!$nfs) {
    mkdir $path
      or croak "Unable to create directory $path ($!)";

    print STDERR "**** Created data directory '$path' ****\n";

    # Make sure it is writeable with group gid bit set
    chmod  S_ISGID|S_IRWXU|S_IRWXG|S_IROTH|S_IXOTH, $path;
  } else {
    print STDERR "Remote data directory is not present and can not be created reliably over NFS\n";
  }
}

=item B<_mkdir_wfcam>

Create the wfcam data directories. Only happens if we are on a wfdr machine.

  _mkdir_wfcam( $outdir );

Does not try to make the directory if on NFS.

=cut

sub _mkdir_wfcam {
  my $path = shift;
  my $hostname = hostname();
  if ($hostname =~ /^wfdr[1-5]$/ && !-d $path) {
    _mkdir( $path );
  }
}

=item B<_mkdir_jcmt>

Create the supplied data directory if we are at JCMT. If there is a problem with NFS returns
a new default.

  $outdir = _mkdir_jcmt( $outdir );

=cut

sub _mkdir_jcmt {
  my $outdir = shift;
  my $site = orac_determine_location();

  # if we are at the summit this must be a local disk
  if ($site eq 'jcmt') {
    my $outdirup = _parentdir($outdir);

    # first see if this is NFS. We will not allow the pipeline to continue
    # using this remote disk
    if (-d $outdirup) {
      if (! -d $outdir ) {
        _mkdir( $outdir );
      }

    } else {
      # This is not good
      print STDERR "The expected output data directory ($outdirup) is missing. Please fix and try again.\n";
    }
    if (! -d $outdir ) {
      print STDERR "Using current directory for ORAC_DATA_OUT.\n";
      $outdir = File::Spec->rel2abs(File::Spec->curdir);
    }
  }
  return $outdir;
}

=item B<_parentdir>

Given a directory path, returns the path of the parent.

  $parent = _parentdir( $dir );

=cut

sub _parentdir {
  my $path = shift;
  my @dirs = File::Spec->splitdir( $path );
  pop(@dirs);
  my $updir = File::Spec->catdir(@dirs);
  return $updir;
}

=item B<_checkdir>

Checks to see if the directory exists. If it doesn't then starting
from the bottom up it looks in the current directory to see whether
parts of that tree are present locally

   $dir = _checkdir( $dir );

Returns a new (or the old) path if one is found, returns undef
if nothing suitable was located.

=cut

sub _checkdir {
  my $dir = shift;

  return $dir if -d $dir;

  my @dirs = File::Spec->splitdir( $dir );

  # Try the smallest part first and then augment
  my @test;
  while ( my $next = pop(@dirs) ) {
    unshift( @test, $next ); # put on to front
    my $new = File::Spec->catdir( File::Spec->curdir, @test );
    return File::Spec->rel2abs( $new ) if -d $new;
  }
  return;
}

=item B<_determine_semester>

Given a date string of form YYYYMMDD derive the semster.

  $sem = _determine_semester( $yyyymmdd );

The returned string does not include the prefix. It just includes
the "02a", "02b".

Returns empty string if there are fewer than 8 digits in the
supplied year.

This method is not as accurate as the OMP::General implementation.

=cut

sub _determine_semester {
  my $ut = shift;
  return '' if length($ut) < 8;

  my $sem;

  # Start by splitting the YYYYMMDD string
  # year and month/day
  my $yyyy = substr( $ut, 0, 4 );
  my $mmdd = substr( $ut, 4, 4 );

  # Calculate previous year
  my $prev_yyyy = $yyyy - 1;

  # Two digit years
  my $yy = substr( $yyyy, 2, 2);
  my $prevyy = substr( $prev_yyyy, 2, 2);

  # Need to put the month in the correct
  # semester. Note that 199?0201 is in the
  # previous semester, same for 199?0801
  if ($mmdd > 201 && $mmdd < 802) {
    $sem = "${yy}a";
  } elsif ($mmdd < 202) {
    $sem = "${prevyy}b";
  } else {
    $sem = "${yy}b";
  }

  return $sem;
}

=back

=end __PRIVATE__METHODS__

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
