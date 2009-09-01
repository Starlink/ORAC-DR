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

 ut => Specify UT date. Defaults to current.
 eng => Boolean indicating whether engineering directories
        are to be selected.
 mode => QL or SUMMIT pipeline. Undef defaults to standard.

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
  # been told to use today.
  my $today = ORAC::General::utdate();
  my $istoday = 0;
  if (!defined $options{ut}) {
    $options{ut} = $today;
    $istoday = 1;
  } elsif ($options{ut} == $today) {
    $istoday = 1;
  }

  # Place to put the results
  my %env;

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
      print "Can not find data directory in default locations so using current directory\n";
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
             ORAC_DATA_OUT => File::Spec->catdir( $dataroot, "reduced", @eng, $root, $localut ),
             ORAC_SUN => $sun,
             ORAC_PERSON => $auth,
           );
  };

  # IRIS-2 has truncated ut data directories
  my $iris2_con = sub {
    # AAT uses truncated directory names
    my $auth = "oracdr_iris2";
    my $sun = "230,232,236";
    my $ut = substr($options{ut},2);
    my %defaults = $ukirt_con->( "iris2", $auth, $sun, $ut );
    # if we are at the AAT we use different trees
    if ($site eq 'aat') {
      $defaults{ORAC_DATA_IN} = File::Spec->catdir( File::Spec->rootdir, "data_vme10",
                                                    "aatobs", "iris2_data", $ut );
      $defaults{ORAC_DATA_OUT} = File::Spec->catdir( File::Spec->rootdir, "iris2_reduce",
                                                     "iris2red", $ut );
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
            ORAC_DATA_OUT => File::Spec->catdir( $dataroot, "reduced", "scuba", $options{ut}),
           );
  };

  # summit standards conventions involve the creation of the data directory
  # at the summit for some instruments

  my $wfcam_con = sub {
    my @eng = ($options{eng} ? ("eng") : ());
    my %defaults = $ukirt_con->( "wfcam", @_ );
    $defaults{ORAC_DATA_IN} = File::Spec->catdir( $dataroot, "raw", @eng,
                                                   lc($oracinst), $options{ut} );
    my $outdir =  File::Spec->catdir( $dataroot, "reduced", @eng,
                                       lc($oracinst), $options{ut} );
    _mkdir_wfcam($outdir);
    $defaults{ORAC_DATA_OUT} = $outdir;

    # Make sure that we use a shared RTD_REMOTE_DIR for each night
    if (!$options{eng}) {
      my $updir = _parentdir( $outdir );
      if (-d $updir) {
        $defaults{ORAC_RESPECT_RTD_REMOTE} = 1;
        $defaults{RTD_REMOTE_DIR} = $updir;
      }
    } else {
      # in -eng mode we make sure we use the non-eng directory tree
      my $newout = File::Spec->catdir( $dataroot, "reduced", lc($oracinst) );
      if (-d $newout) {
        $defaults{ORAC_RESPECT_RTD_REMOTE} = 1;
        $defaults{RTD_REMOTE_DIR} = $newout;
      }
    }

    return %defaults;
  };

  my $acsis_con = sub {
    # call UKIRT to do basics
    my %defaults = $ukirt_con->( "acsis", @_ );
    # but we are allowed to create the output directory
    $defaults{ORAC_DATA_OUT} = _mkdir_jcmt( $defaults{ORAC_DATA_OUT});
    return %defaults;
  };

  # SCUBA-2 reads from a ok directory
  my $scuba2_con = sub {
    my @eng = ($options{eng} ? ("eng") : ());

    # The summit reduced directory depends on the orac_instrument variable and
    # the processing mode.
    my %path;
    if ( exists $options{mode} && defined $options{mode} && $options{mode} eq 'QL') {
      %path = ( SCUBA2_LONG => "scuba2ql_long",
                SCUBA2_SHORT => "scuba2ql_short");
    } else {
      %path = ( SCUBA2_LONG => "scuba2_long",
                SCUBA2_SHORT => "scuba2_short",);
    }
    if (!exists $path{$oracinst}) {
      print STDERR "Unrecognized SCUBA-2 instrument type: $oracinst. Using SCUBA2_LONG\n";
      $oracinst = "SCUBA2_LONG";
    }

    my %remote;
    if (exists $options{mode} && defined $options{mode}) {
      if ($options{mode} eq 'QL') {
        # Decide which remote tasks to talk to
        if ($oracinst eq 'SCUBA2_LONG') {
          $remote{ORAC_REMOTE_TASK} = 'SC2DA8A@sc2da8a';
        } elsif ($oracinst eq 'SCUBA2_SHORT') {
          $remote{ORAC_REMOTE_TASK} = 'SC2DA4A@sc2da4a';
        }
      }
    }

    # Calculate the parent output directory so we can check path
    my $outdir = File::Spec->catdir( $dataroot, "reduced", $path{$oracinst}, $options{ut} );
    $outdir = _mkdir_jcmt( $outdir );

    return ( ORAC_DATA_IN => File::Spec->catdir( $dataroot, "raw", "scuba2", "ok", @eng, $options{ut} ),
             ORAC_DATA_CAL => File::Spec->catdir( $env{ORAC_CAL_ROOT}, "scuba2" ),
             ORAC_DATA_OUT => $outdir,
             %remote,
           );
  };

  # Arguments to use for the alias.

  # Default to -ut for non-today
  my $oracdr_args = sub {
    return ( $istoday ? () : ("-ut" => $options{ut}) );
  };

  # UKIRT instruments use transient groups
  my $ukirt_args = sub {
    return ( $oracdr_args->(),
             "-grptrans" => undef,
           );
  };

  # SCUBA-2 and ACSIS support recsuffix options
  my $jcmt_args = sub {
    my @rec;
    if (exists $options{mode} && defined $options{mode}) {
      if ($options{mode} eq 'QL') {
        push(@rec, "-recsuffix", "QL" );
        # SCUBA2 disables the display in QL mode and uses DRAMA
        if ($inst eq 'SCUBA2') {
          push(@rec, "-nodisplay" => undef, "-loop" => "task" );
        }
      } elsif ($options{mode} eq 'SUMMIT') {
        push(@rec, "-recsuffix", "SUMMIT");
      }
    }
    return ( $oracdr_args->(), @rec );
  };


  # Now the instrument specific code. We first set up a hash with the obvious defaults.
  # We use coderefs to insert dynamic values. Note that we use sub{} instead of directly
  # executing a coderef inline to prevent additional code triggering for the wrong instrument.
  # The _args coderefs are mean to be innocuous.
  my %default_envs = ( 'ACSIS'  => { code => sub { $acsis_con->( "b.cavanagh", "XXX" ); },
                                     ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "acsis", "spectra", $options{ut} ),
                                     ORAC_LOOP => "flag -skip",
                                     args => { $jcmt_args->() },
                                   },
                       'CGS4'   => { code => sub { $ukirt_con->( "cgs4", "b.cavanagh", "236" ) },
                                     ORAC_LOOP => "flag -skip",
                                     args => { $ukirt_args->() },
                                   },
                       "CLASSICCAM" => { code => sub { $ukirt_con->( "classiccam", "m.currie", "232" ) },
                                         ORAC_LOOP => "flag -skip",
                                         args => { $ukirt_args->() },
                                       },
                       'CURVE'    => { code => sub { $ukirt_con->( "curve", "b.cavanagh", "236" ) },
                                       ORAC_DATA_CAL => File::Spec->catfile( $env{ORAC_CAL_ROOT}, "ufti" ),
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },
                                   },
                       'GMOS'     => { code => sub { $ukirt_con->( "gmos", "p.hirst", "XXX" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       "INGRID"    => { code => sub { $ukirt_con->( "ingrid", "m.currie", "232" ) },
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       # This is old IRCAM
                       'IRCAM'  => { ORAC_DATA_CAL => File::Spec->catfile( $env{'ORAC_CAL_ROOT'}, "ircam" ),
                                     ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "ircam",$options{ut}, "rodir" ),
                                     ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "raw", "ircam", $options{ut}, "rodir" ),
                                     ORAC_PERSON => 'b.cavanagh',
                                     ORAC_SUN => '232',
                                     ORAC_LOOP => "wait",
                                     args => { $ukirt_args->() },
                                   },
                       'IRCAM2' => { code => sub { $ukirt_con->("ircam", "b.cavanagh", "232" ) },
                                     ORAC_LOOP => "flag -skip",
                                     args => { $ukirt_args->() }, },
                       'IRIS2'     => { code => sub { $iris2_con->() },
                                        ORAC_LOOP => "wait",
                                        args => { $oracdr_args->() }, },
                       'ISAAC'     => { code => sub { $ukirt_con->( "isaac", "m.currie", "232,236" ) },
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       # experimental
                       "JCMT_DAS" => { code => sub { $ukirt_con->( "heterodyne", "b.cavanagh", "230" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $oracdr_args->() }, },
                       'MICHELLE' => { code => sub { $ukirt_con->( "michelle", "b.cavanagh", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },},
                       'NACO'     => { code => sub { $ukirt_con->( "naco", "m.currie", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       'NIRI'     => { code => sub { $ukirt_con->( "niri", "p.hirst", "XXX" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() },},
                       # Old CGS4
                       'OCGS4'    => { code => sub { $ukirt_con->( "cgs4", "b.cavanagh", "236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       "SCUBA"     => { code => sub { $scuba_con->() },
                                        ORAC_PERSON => "t.jenness",
                                        ORAC_SUN => "231",
                                       ORAC_LOOP => "flag -skip",
                                        args => { $oracdr_args->(), "-loop" => "flag", "-skip" => 1 },
                                      },
                       "SCUBA2"   => { code => sub { $scuba2_con->() },
                                       ORAC_PERSON => "a.gibb",
                                       ORAC_SUN  => "264",
                                       ORAC_LOOP => "flag -skip",
                                       args => { $jcmt_args->() },
                                     },
                       'SOFI'     => { code => sub { $ukirt_con->( "sofi", "m.currie", "232,236" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       # New UFTI (non-FITS)
                       'UFTI2'    => { code => sub { $ukirt_con->( "ufti", "b.cavanagh", "232" ) },
                                       ORAC_LOOP => "flag -skip",
                                       args => { $ukirt_args->() }, },
                       'UFTI_CASU' => { code => sub { $ukirt_con->( "ufti", "j.lewis", "232" ) },
                                        ORAC_DATA_CAL => File::Spec->catdir($env{ORAC_DATA_CAL}, "ufti_casu" ),
                                        ORAC_LOOP => "flag -skip",
                                        args => { $ukirt_args->() }, },
                       'UIST'     => { code => sub { $ukirt_con->( "uist", "b.cavanagh", "232,236,246" ) },
                                       args => { $ukirt_args->() },
                                       ORAC_LOOP => "$env{ORAC_LOOP} -skip",
                                     },
                       'WFCAM'  => { code => sub { $wfcam_con->( "b.cavanagh", "XXX" ) },
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


  if ($DEBUG) {
    $Data::Dumper::SortKeys = 1;
    print Dumper(\%env);
  }
  return %env;
}

=item B<is_nfs_disk>

Returns the name of the remote NFS server if the path corresponds to an NFS disk,
undef if it is local.

  $isnfs = is_nfs_disk( $path );

Will not be portable since "df" is called.

=cut

sub is_nfs_disk {
  my $path = shift;

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

Returns "hilo", "jcmt", "ukirt", "aat", "ing" or undef depending on whether
the code is running in Hilo, JCMT, UKIRT, AAT or elsewhere.

The value is cached since it will not change during execution.

=cut

{
my $site;
sub orac_determine_location {
  return $site if defined $site;
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
    return $site if defined $site;
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
    return $site if defined $site;
  }

  # got here we do not know
  return;
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
      or croak "Unable to create output directory $path";

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
