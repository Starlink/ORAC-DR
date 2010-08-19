package ORAC::Inst::Defn;

=head1 NAME

ORAC::Inst::Defn - Definition of instrument class dependencies

=head1 SYNOPSIS

  use ORAC::Inst::Defn;

  @pars = orac_determine_inst_classes( $instrument );
  orac_determine_initial_algorithm_engines
  orac_determine_recipe_search_path
  orac_determine_primitive_search_path
  orac_engine_description
  orac_messys_description
  orac_configure_for_instrument( $instrument, \%options );

=head1 DESCRIPTION

This module provides all the instrument specific initialisation
information. This is the information required by ORAC-DR in order
to configure itself before the data detection loop can begin.

This module provides information on class hierarchies, recipe
search paths and initialisation or algorithm engines.

All instrument dependencies are specified in this module.

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use File::Spec;
use File::Path;
use Cwd;
use Sys::Hostname;
use Net::Domain;
use ORAC::General;
use ORAC::Print;
use ORAC::Constants qw/ :status /;
use ORAC::Inst::SetupEnv;

use Starlink::Config;  # Need to know where fluxes is

require Exporter;
use vars qw/ @ISA @EXPORT_OK $VERSION $DEBUG/;

$DEBUG = 0;

@ISA = qw/ Exporter /;
@EXPORT_OK = qw/
  orac_determine_inst_classes
  orac_determine_initial_algorithm_engines
  orac_determine_recipe_search_path
  orac_determine_primitive_search_path
  orac_determine_calibration_search_path
  orac_engine_description
  orac_messys_description
  orac_configure_for_instrument
  orac_list_generic_observing_modes
  orac_guess_instrument
 /;

$VERSION = '1.0';


# Cleanup END blocks. Useful if helper tasks create temporary
# files or directories and dont use File::Temp
# In future should make File::Temp mandatory

# Two lexical array, one for files and one for directories
my (@FILES_TO_UNLINK, @DIRS_TO_UNLINK);

# This code comes directly from File::Temp
# Note that File::Temp also keeps track of the process
# creating the directory/file so that it will not be deleted
# on fork.

END {
  local($., $@, $!, $^E, $?); # make sure this does not trash exit status

  # Files
  foreach my $file (@FILES_TO_UNLINK) {

    if (-f $file->[1]) {  # file name is [1]
      unlink $file->[1] or warn "Error removing ".$file->[1];
    }
  }
  # Dirs
  foreach my $dir (@DIRS_TO_UNLINK) {
    if (-d $dir) {
      rmtree($dir, $DEBUG, 1);
    }
  }
}

# The kappa display system requires
# us to set the AGI environment variables
# These should be set to directories that have been created
# by File::Temp so that they will be tidied automatically

BEGIN {
  # A kluge - for some reason kapview does not pick up the
  # correct environment if I leave out the BEGIN block
  # dont understand since the environment is passed to the forked
  # process...
  # Need the second arg in perl versions prior to 5.6.0
  my $agidir =  File::Spec->catdir(File::Spec->tmpdir, "oracdragi" . $$);
  mkdir($agidir,0777)
    or croak "Could not make AGI temp directory $agidir: $!";
  $ENV{'AGI_USER'} = $agidir;
  $ENV{'AGI_NODE'} = "orac_kapview$$";

  push( @DIRS_TO_UNLINK, $agidir);

}

# Internal definitions of algorithm engine definitions
# Used to construct instrument recipe dependencies

my %MonolithDefns = (
         kappa_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'KAPPA_DIR'} ) ? $ENV{KAPPA_DIR}."/kappa_mon" : "" ),
          },
         surf_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'SURF_DIR'} ) ? "$ENV{SURF_DIR}/surf_mon" : "" ),
          },
         polpack_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'POLPACK_DIR'} ) ? "$ENV{POLPACK_DIR}/polpack_mon" : "" ),
          },
         ccdpack_reg => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CCDPACK_DIR'} ) ? "$ENV{CCDPACK_DIR}/ccdpack_reg" : "" ),
          },
         ccdpack_red => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CCDPACK_DIR'} ) ? "$ENV{CCDPACK_DIR}/ccdpack_red" : "" ),
          },
         ccdpack_res => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CCDPACK_DIR'} ) ? "$ENV{CCDPACK_DIR}/ccdpack_res" : "" ),
          },
         catselect => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CURSA_DIR'} ) ? "$ENV{CURSA_DIR}/cursa" : "" ),
          },
         cursa => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CURSA_DIR'} ) ? "$ENV{CURSA_DIR}/cursa" : "" ),
          },
         ndf2fits => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CONVERT_DIR'} ) ? "$ENV{CONVERT_DIR}/ndf2fits" : "" ),
          },
         fits2ndf => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CONVERT_DIR'} ) ? "$ENV{CONVERT_DIR}/fits2ndf" : "" ),
         },
         convert_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CONVERT_DIR'} ) ? "$ENV{CONVERT_DIR}/convert_mon" : "" ),
         },
         kapview_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'KAPPA_DIR'} ) ? $ENV{KAPPA_DIR}."/kapview_mon" : "" ),
          },
         ndfpack_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'KAPPA_DIR'} ) ? $ENV{KAPPA_DIR}."/ndfpack_mon" : "" ),
          },
         figaro1 => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'FIG_DIR'} ) ? $ENV{FIG_DIR}."/figaro1" : "" ),
          },
         figaro2 => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'FIG_DIR'} ) ? $ENV{FIG_DIR}."/figaro2" : "" ),
          },
         figaro3 => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'FIG_DIR'} ) ? $ENV{FIG_DIR}."/figaro3" : "" ),
          },
         figaro4 => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'FIG_DIR'} ) ? $ENV{FIG_DIR}."/figaro4" : "" ),
          },
         figaro5 => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'FIG_DIR'} ) ? $ENV{FIG_DIR}."/figaro5" : "" ),
          },
         extractor =>{
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'EXTRACTOR_DIR'} ) ? "$ENV{EXTRACTOR_DIR}/extractor" : "" ),
          },
         pisa_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'PISA_DIR'} ) ? "$ENV{PISA_DIR}/pisa_mon" : "" ),
          },
         photom_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'PHOTOM_DIR'} ) ? "$ENV{PHOTOM_DIR}/photom_mon" : "" ),
          },
         atools_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'ATOOLS_DIR'} ) ? "$ENV{ATOOLS_DIR}/atools_mon" : "" ),
          },
         smurf_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'SMURF_DIR'} ) ? File::Spec->catfile( $ENV{'SMURF_DIR'}, "smurf_mon" ) : "" ),
          },
         cupid_mon => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => ( defined( $ENV{'CUPID_DIR'} ) ? File::Spec->catfile( $ENV{'CUPID_DIR'}, "cupid_mon" ) : "" ),
          },
         p4         => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => \&p4_helper,
          },
         fluxes => {
           MESSYS => 'AMS',
           CLASS => 'ORAC::Msg::Task::ADAM',
           PATH => \&fluxes_helper,
          },
         FTS2DR => {
           MESSYS => 'DRAMA',
           CLASS => 'ORAC::Msg::Task::DRAMA',
           PATH => (exists $ENV{FTS2DR_DIR} ? $ENV{FTS2DR_DIR}. "/fts2dr.sh" :
		                                 "not_defined"),
         },
         hdstools_mon => {
                          MESSYS => 'AMS',
                          CLASS => 'ORAC::Msg::Task::ADAM',
                          PATH => ( defined( $ENV{'HDSTOOLS_DIR'} ) ? "$ENV{HDSTOOLS_DIR}/hdstools_mon" : "" ),
                         },
	 # SCUBA-2 Acquisition Tasks
	 QLSIM => { # we never start QLSIM
		   MESSYS => 'DRAMA',
		   CLASS => 'ORAC::Msg::Task::DRAMA',
		  },
	 SCU2_8A => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_8B => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_8C => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
         SCU2_8D => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_4A => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_4B => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_4C => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
	 SCU2_4D => {
		     MESSYS => 'DRAMA',
		     CLASS => 'ORAC::Msg::Task::DRAMA'
		     },
         # Testing
	 CSOMON => {
           MESSYS => 'DRAMA',
           CLASS => 'ORAC::Msg::Task::DRAMA',
           PATH => '/tmp/getcso.pl',
         },
       );

# Message system definitions
my %MessageSystemDefns = (
        AMS => {
          CLASS => 'ORAC::Msg::Control::AMS',
         },
        ADAMShell => {
          # shell does not require messaging
          CLASS => 'ORAC::Msg::Control::ADAMShell',
         },
	DRAMA => {
	  CLASS => 'ORAC::Msg::Control::DRAMA',
	},
       );

=head1 FUNCTIONS

The following functions are provided:

=over 4

=item B<orac_determine_inst_classes>

Given an ORAC instrument name, returns the class names to be
used for frames, groups, calibration messaging. The classes
are used so that objects can be instantiated immediately.

  ($frameclass, $groupclass, $calclass, $instclass) =
        orac_determine_inst_classes( $instrument );

The function dies if the classes can not be used.
An empty list is returned if the instrument is not known
to the system.

Returns the Frame class in scalar context.

=cut

sub orac_determine_inst_classes {

  # Upper case the argument
  my $inst = uc($_[0]);

  # The return variables
  my ($frameclass, $groupclass, $calclass, $instclass);

  # Now check for our instrument
  if ($inst eq 'IRCAM') {
    $groupclass = "ORAC::Group::IRCAM";
    $frameclass = "ORAC::Frame::IRCAM";
    $calclass   = "ORAC::Calib::IRCAM";
    $instclass  = "ORAC::Inst::IRCAM";

  } elsif ($inst eq 'IRCAM2') {
    $groupclass = "ORAC::Group::IRCAM";
    $frameclass = "ORAC::Frame::IRCAM2";
    $calclass   = "ORAC::Calib::IRCAM";
    $instclass  = "ORAC::Inst::IRCAM";
    $inst  = 'IRCAM'; # to pick up IRCAM recipes

  } elsif ($inst eq 'INGRID') {
    $groupclass = "ORAC::Group::INGRID";
    $frameclass = "ORAC::Frame::INGRID";
    $calclass   = "ORAC::Calib::INGRID";
    $instclass  = "ORAC::Inst::INGRID";

  } elsif ($inst eq 'IRIS2') {
    $groupclass = "ORAC::Group::IRIS2";
    $frameclass = "ORAC::Frame::IRIS2";
    $calclass   = "ORAC::Calib::IRIS2";
    $instclass  = "ORAC::Inst::IRIS2";

  } elsif ($inst eq 'ISAAC') {
    $groupclass = "ORAC::Group::ISAAC";
    $frameclass = "ORAC::Frame::ISAAC";
    $calclass   = "ORAC::Calib::ISAAC";
    $instclass  = "ORAC::Inst::ISAAC";

  } elsif ($inst eq 'NACO') {
    $groupclass = "ORAC::Group::NACO";
    $frameclass = "ORAC::Frame::NACO";
    $calclass   = "ORAC::Calib::NACO";
    $instclass  = "ORAC::Inst::NACO";

  } elsif ($inst eq 'SOFI') {
    $groupclass = "ORAC::Group::SOFI";
    $frameclass = "ORAC::Frame::SOFI";
    $calclass   = "ORAC::Calib::SOFI";
    $instclass  = "ORAC::Inst::SOFI";

  } elsif ($inst eq 'UFTI') {
    $groupclass = "ORAC::Group::UFTI";
    $frameclass = "ORAC::Frame::UFTI";
    $calclass   = "ORAC::Calib::UFTI";
    $instclass  = "ORAC::Inst::IRCAM";

  } elsif ($inst eq 'UFTI2') {
    $groupclass = "ORAC::Group::UFTI";
    $frameclass = "ORAC::Frame::UFTI2";
    $calclass   = "ORAC::Calib::UFTI";
    $instclass  = "ORAC::Inst::IRCAM";
    $inst = 'UFTI'; # to pick UFTI recipes and primitives as they are

  } elsif ($inst =~ /^WFCAM/) {
    $groupclass = "ORAC::Group::WFCAM";
    $frameclass = "ORAC::Frame::WFCAM";
    $calclass   = "ORAC::Calib::WFCAM";
    $instclass  = "ORAC::Inst::WFCAM";

  } elsif ($inst eq 'CGS4') {
    $groupclass = "ORAC::Group::CGS4";
    $frameclass = "ORAC::Frame::CGS4";
    $calclass   = "ORAC::Calib::CGS4";
    $instclass  = "ORAC::Inst::CGS4";

  } elsif ($inst eq 'OCGS4') {
    $groupclass = "ORAC::Group::CGS4";
    $frameclass = "ORAC::Frame::OCGS4";
    $calclass   = "ORAC::Calib::CGS4";
    $instclass  = "ORAC::Inst::CGS4";
    $inst = 'CGS4'; # to pick up CGS4 recipes and primitives

  } elsif ($inst eq 'SCUBA') {
    $groupclass = "ORAC::Group::SCUBA";
    $frameclass = "ORAC::Frame::SCUBA";
    $calclass   = "ORAC::Calib::SCUBA";
    $instclass  = "ORAC::Inst::SCUBA";

  } elsif ($inst =~ /^SCUBA2/) {
    $groupclass = "ORAC::Group::SCUBA2";
    $frameclass = "ORAC::Frame::SCUBA2";
    $calclass   = "ORAC::Calib::SCUBA2";
    $instclass  = "ORAC::Inst::SCUBA2";

  } elsif ($inst eq 'MICHTEMP') {
    $groupclass = "ORAC::Group::Michelle";
    $frameclass = "ORAC::Frame::MichTemp";
    $calclass = "ORAC::Calib::CGS4";
    $instclass = "ORAC::Inst::CGS4";

  } elsif ($inst eq 'MICHELLE') {
    $groupclass = "ORAC::Group::Michelle";
    $frameclass = "ORAC::Frame::Michelle";
    $calclass = "ORAC::Calib::Michelle";
    $instclass = "ORAC::Inst::Michelle";

  } elsif ($inst eq 'MICHGEM') {
    $groupclass = "ORAC::Group::MichGem";
    $frameclass = "ORAC::Frame::MichGem";
    $calclass = "ORAC::Calib::Michelle";
    $instclass = "ORAC::Inst::Michelle";

  } elsif ($inst eq 'UIST') {
    $groupclass = "ORAC::Group::UIST";
    $frameclass = "ORAC::Frame::UIST";
    $calclass = "ORAC::Calib::UIST";
    $instclass = "ORAC::Inst::UIST";

  } elsif ($inst eq 'GMOS') {
    $groupclass = "ORAC::Group::GMOS";
    $frameclass = "ORAC::Frame::GMOS";
    $calclass = "ORAC::Calib::UIST";
    $instclass = "ORAC::Inst::GMOS";

  } elsif ($inst eq 'GMOS2') {
    $groupclass = "ORAC::Group::GMOS";
    $frameclass = "ORAC::Frame::GMOS2";
    $calclass = "ORAC::Calib::UIST";
    $instclass = "ORAC::Inst::GMOS";

  } elsif ($inst eq 'NIRI') {
    $groupclass = "ORAC::Group::NIRI";
    $frameclass = "ORAC::Frame::NIRI";
    $calclass = "ORAC::Calib::NIRI";
    $instclass = "ORAC::Inst::NIRI";

  } elsif ($inst eq 'NIRI2') {
    $groupclass = "ORAC::Group::NIRI";
    $frameclass = "ORAC::Frame::NIRI2";
    $calclass = "ORAC::Calib::NIRI";
    $instclass = "ORAC::Inst::NIRI";

  } elsif ($inst eq 'CLASSICCAM') {
    $groupclass = "ORAC::Group::ClassicCam";
    $frameclass = "ORAC::Frame::ClassicCam";
    $calclass   = "ORAC::Calib::ClassicCam";
    $instclass  = "ORAC::Inst::ClassicCam";

  } elsif ($inst eq 'SPEX') {
    $groupclass = "ORAC::Group::SPEX";
    $frameclass = "ORAC::Frame::SPEX";
    $calclass   = "ORAC::Calib::SPEX";
    $instclass  = "ORAC::Inst::SPEX";

  } elsif( $inst eq 'JCMT_DAS') {
    $groupclass = "ORAC::Group::JCMT_DAS";
    $frameclass = "ORAC::Frame::JCMT_DAS";
    $calclass = "ORAC::Calib";
    $instclass = "ORAC::Inst::JCMT_DAS";

  } elsif( $inst eq 'ACSIS') {
    $groupclass = "ORAC::Group::ACSIS";
    $frameclass = "ORAC::Frame::ACSIS";
    $calclass = "ORAC::Calib::ACSIS";
    $instclass = "ORAC::Inst::ACSIS";

  } elsif( $inst eq 'ACSIS_QL' ) {
    $groupclass = "ORAC::Group::ACSIS_QL";
    $frameclass = "ORAC::Frame::ACSIS_QL";
    $calclass = "ORAC::Calib";
    $instclass = "ORAC::Inst::ACSIS_QL";

  } elsif ( $inst eq 'PICARD' ) {
    $groupclass = "ORAC::Group::PICARD";
    $frameclass = "ORAC::Frame::PICARD";
    $calclass = "ORAC::Calib";
    $instclass = "ORAC::Inst::PICARD";

  } else {
    orac_err("Instrument $inst is not currently supported in ORAC-DR\n");
    return ();
  }

  # The instrument name was valid so
  # read in the instrument specific classs
  eval "use $groupclass;";
  croak "Error importing $groupclass:\n$@\n" if ($@);
  eval "use $frameclass;";
  croak "Error importing $frameclass:\n$@\n" if ($@);
  eval "use $calclass;";
  croak "Error importing $calclass:\n$@\n" if ($@);
  eval "use $instclass;";
  croak "Error importing $instclass:\n$@\n" if ($@);

  # Return the class names
  if (wantarray) {
    return ($frameclass, $groupclass, $calclass, $instclass);
  } else {
    return $frameclass;
  }
}


=item B<orac_list_generic_observing_modes>

Returns a list of the standard observing modes supported
by ORAC-DR. Currently the list includes just "imaging"
and "spectroscopy" (implicitly assumed to be near-infrared).

Specific instruments always have their own modes.

The list is determined by looking in the recipe directory for
directories that contain all lower case characters.  Upper case
characters imply a specific instrument rather than a generic
mode. This is probably over-the-top given that the search path
functions (below) have to assume that they know the answer.

=cut

sub orac_list_generic_observing_modes {
  # Steal from recipe_search_path
  # Could share the code...
  my $root;
  if (exists $ENV{ORAC_DIR}) {
    $root = File::Spec->catdir( $ENV{ORAC_DIR}, "recipes" );
  } else {
    croak "Unable to determine ORAC_DIR location";
  }

  # Open the directory and look for directory names that are
  # lower case
  opendir( my $dh, $root) or croak "Unable to open dir $root: $!";
  return grep /^[a-z]+$/, readdir($dh);
}


=item B<orac_determine_recipe_search_path>

Returns a list of directories that should be searched in order
to locate recipes for the specified instrument.

  @paths = orac_determine_recipe_search_path( $instrument );

Root location is specified by the C<ORAC_DIR> environment
variable.

=cut

sub orac_determine_recipe_search_path {
  my $inst = uc(shift);
  my @path;

  my $root;
  if (exists $ENV{ORAC_DIR}) {
    $root = File::Spec->catdir( $ENV{ORAC_DIR}, "recipes" );
  } else {
    croak "Unable to determine ORAC_DIR location";
  }
  my $imaging_root =  File::Spec->catdir( $root, "imaging" );
  my $spectro_root =  File::Spec->catdir( $root, "spectroscopy" );
  my $ifu_root     =  File::Spec->catdir( $root, "ifu" );
  my $het_root     =  File::Spec->catdir( $root, "heterodyne" );

  if ($inst eq 'SCUBA') {
    push( @path, File::Spec->catdir( $root, 'SCUBA' ) );

  } elsif ($inst =~ /^SCUBA2/) {
    push( @path, File::Spec->catdir( $root, "SCUBA2" ) );

  } elsif ($inst eq 'JCMT_DAS') {
    push( @path, File::Spec->catdir( $het_root, "JCMT_DAS" ) );
    push( @path, $het_root );

  } elsif ($inst eq 'ACSIS' ) {
    push( @path, File::Spec->catdir( $het_root, 'ACSIS' ) );
    push( @path, $het_root );

  } elsif ($inst eq 'ACSIS_QL' ) {
    push( @path, File::Spec->catdir( $het_root, 'ACSIS_QL' ) );
    push( @path, $het_root );

  } elsif ($inst eq 'CGS4' or $inst eq 'OCGS4') {
    push( @path, File::Spec->catdir( $root, 'CGS4' ) );
    push( @path, File::Spec->catdir( $spectro_root, "CGS4" ) );
    push( @path, $spectro_root );

  } elsif ($inst eq 'IRCAM' or $inst eq 'IRCAM2') {
    push( @path, File::Spec->catdir( $root, "IRCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, "IRCAM" ) );
    push( @path, $imaging_root );

  } elsif ($inst eq 'UFTI' or $inst eq 'UFTI2') {
    push( @path, File::Spec->catdir( $root, "UFTI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "UFTI" ) );
    push( @path, $imaging_root );

  } elsif ($inst =~ /^WFCAM/) {
    push( @path, File::Spec->catdir( $root, "WFCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, "WFCAM" ) );
    push( @path, $imaging_root );

  } elsif ($inst eq 'MICHELLE' or $inst eq 'MICHTEMP' or $inst eq 'MICHGEM') {
    push( @path, File::Spec->catdir( $root, "MICHELLE" ) );
    push( @path, File::Spec->catdir( $imaging_root, "MICHELLE" ) );
    push( @path, File::Spec->catdir( $spectro_root, "MICHELLE" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'UIST') {
    push( @path, File::Spec->catdir( $root, "UIST" ) );
    push( @path, File::Spec->catdir( $ifu_root, "UIST" ) );
    push( @path, File::Spec->catdir( $imaging_root, "UIST" ) );
    push( @path, File::Spec->catdir( $spectro_root, "UIST" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'INGRID') {
    push( @path, File::Spec->catdir( $root, "INGRID" ) );
    push( @path, File::Spec->catdir( $imaging_root, "INGRID" ) );
    push( @path, $imaging_root );

  } elsif ($inst eq 'IRIS2') {
    push( @path, File::Spec->catdir( $root, "IRIS2" ) );
    push( @path, File::Spec->catdir( $imaging_root, "IRIS2" ) );
    push( @path, File::Spec->catdir( $spectro_root, "IRIS2" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'ISAAC') {
    push( @path, File::Spec->catdir( $root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'NACO') {
    push( @path, File::Spec->catdir( $root, "NACO" ) );
    push( @path, File::Spec->catdir( $imaging_root, "NACO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "NACO" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'SOFI') {
    push( @path, File::Spec->catdir( $root, "SOFI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "SOFI" ) );
    push( @path, File::Spec->catdir( $spectro_root, "SOFI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'GMOS' or $inst eq 'GMOS2') {
    push( @path, File::Spec->catdir( $root, "GMOS" ) );
    push( @path, File::Spec->catdir( $ifu_root, "GMOS" ) );
    push( @path, File::Spec->catdir( $imaging_root, "GMOS" ) );
    push( @path, File::Spec->catdir( $spectro_root, "GMOS" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'NIRI' or $inst eq 'NIRI2') {
    push( @path, File::Spec->catdir( $root, "NIRI" ) );
    push( @path, File::Spec->catdir( $ifu_root, "NIRI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "NIRI" ) );
    push( @path, File::Spec->catdir( $spectro_root, "NIRI" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );

  } elsif ($inst eq 'CLASSICCAM') {
    push( @path, File::Spec->catdir( $root, "CLASSICCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, "CLASSICCAM" ) );
    push( @path, $imaging_root );

  } elsif ($inst eq 'SPEX') {
    push( @path, File::Spec->catdir( $root, "SPEX" ) );
    push( @path, File::Spec->catdir( $imaging_root, "SPEX" ) );
    push( @path, $imaging_root );

  } elsif ($inst eq 'PICARD') {
    push( @path, File::Spec->catdir( $root, "PICARD" ) );
  } else {
    croak "Recipes: Unrecognised instrument: $inst\n";
  }

  return @path;
}

=item B<orac_determine_primitive_search_path>

Returns a list of directories that should be searched in order
to locate primitives for the specified instrument.

  @paths = orac_determine_primitive_search_path( $instrument );

Root location is specified by the C<ORAC_DIR> environment
variable.

=cut

sub orac_determine_primitive_search_path {
  my $inst = (shift);
  my @path;

  my $root;
  if (exists $ENV{ORAC_DIR}) {
    $root = File::Spec->catdir( $ENV{ORAC_DIR}, "primitives" );
  } else {
    croak "Unable to determine ORAC_DIR location";
  }
  my $imaging_root =  File::Spec->catdir( $root, "imaging" );
  my $spectro_root =  File::Spec->catdir( $root, "spectroscopy" );
  my $ifu_root     =  File::Spec->catdir( $root, "ifu" );
  my $het_root     =  File::Spec->catdir( $root, "heterodyne" );
  my $general_root =  File::Spec->catdir( $root, "general" );
  my $casu_root    =  File::Spec->catdir( $root, "casu");
  my $jsa_root     =  File::Spec->catdir( $root, "JSA");

  if ($inst eq 'SCUBA') {
    push( @path, File::Spec->catdir( $root, 'SCUBA' ) );
    push( @path, $jsa_root, $general_root );

  } elsif( $inst =~ /^SCUBA2/ ) {
    push( @path, File::Spec->catdir( $root, 'SCUBA2') );
    push( @path, $imaging_root );
    push( @path, $jsa_root, $general_root );

  } elsif( $inst eq 'JCMT_DAS' ) {
    push( @path, File::Spec->catdir( $het_root, 'JCMT_DAS') );
    push( @path, $het_root );
    push( @path, $general_root );

  } elsif( $inst eq 'ACSIS' ) {
    push( @path, File::Spec->catdir( $het_root, 'ACSIS' ) );
    push( @path, $het_root );
    push( @path, $jsa_root, $general_root );

  } elsif( $inst eq 'ACSIS_QL' ) {
    push( @path, File::Spec->catdir( $het_root, 'ACSIS_QL' ) );
    push( @path, $het_root );
    push( @path, $general_root );

  } elsif ($inst eq 'CGS4' or $inst eq 'OCGS4') {
    push( @path, File::Spec->catdir( $root, 'CGS4' ) );
    push( @path, File::Spec->catdir( $spectro_root, "CGS4" ) );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'IRCAM' or $inst eq 'IRCAM2') {
    push( @path, File::Spec->catdir( $root, "IRCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, "IRCAM" ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst eq 'UFTI' or $inst eq 'UFTI2') {
    push( @path, File::Spec->catdir( $root, "UFTI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "UFTI" ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst =~ /^WFCAM/) {
    push( @path, File::Spec->catdir( $root, "WFCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, 'WFCAM' ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst eq 'MICHELLE' or $inst eq 'MICHTEMP' or $inst eq 'MICHGEM') {
    push( @path, File::Spec->catdir( $root, "MICHELLE" ) );
    push( @path, File::Spec->catdir( $imaging_root, "MICHELLE" ) );
    push( @path, File::Spec->catdir( $spectro_root, "MICHELLE" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'UIST') {
    push( @path, File::Spec->catdir( $root, "UIST" ) );
    push( @path, File::Spec->catdir( $ifu_root, "UIST" ) );
    push( @path, File::Spec->catdir( $imaging_root, "UIST" ) );
    push( @path, File::Spec->catdir( $spectro_root, "UIST" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'INGRID') {
    push( @path, File::Spec->catdir( $root, "INGRID" ) );
    push( @path, File::Spec->catdir( $imaging_root, "INGRID" ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst eq 'IRIS2') {
    push( @path, File::Spec->catdir( $root, "IRIS2" ) );
    push( @path, File::Spec->catdir( $imaging_root, "IRIS2" ) );
    push( @path, File::Spec->catdir( $spectro_root, "IRIS2" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'ISAAC') {
    push( @path, File::Spec->catdir( $root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ISAAC" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'NACO') {
    push( @path, File::Spec->catdir( $root, "NACO" ) );
    push( @path, File::Spec->catdir( $imaging_root, "NACO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "NACO" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'SOFI') {
    push( @path, File::Spec->catdir( $root, "SOFI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "SOFI" ) );
    push( @path, File::Spec->catdir( $spectro_root, "SOFI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "ESO" ) );
    push( @path, File::Spec->catdir( $spectro_root, "ESO" ) );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'GMOS' or $inst eq 'GMOS2') {
    push( @path, File::Spec->catdir( $root, "GMOS" ) );
    push( @path, File::Spec->catdir( $ifu_root, "GMOS" ) );
    push( @path, File::Spec->catdir( $imaging_root, "GMOS" ) );
    push( @path, File::Spec->catdir( $spectro_root, "GMOS" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'NIRI' or $inst eq 'NIRI2') {
    push( @path, File::Spec->catdir( $root, "NIRI" ) );
    push( @path, File::Spec->catdir( $ifu_root, "NIRI" ) );
    push( @path, File::Spec->catdir( $imaging_root, "NIRI" ) );
    push( @path, File::Spec->catdir( $spectro_root, "NIRI" ) );
    push( @path, $ifu_root );
    push( @path, $imaging_root );
    push( @path, $spectro_root );
    push( @path, $general_root );

  } elsif ($inst eq 'CLASSICCAM') {
    push( @path, File::Spec->catdir( $root, "CLASSICCAM" ) );
    push( @path, File::Spec->catdir( $imaging_root, "CLASSICCAM" ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst eq 'SPEX') {
    push( @path, File::Spec->catdir( $root, "SPEX" ) );
    push( @path, File::Spec->catdir( $imaging_root, "SPEX" ) );
    push( @path, $imaging_root );
    push( @path, $general_root );

  } elsif ($inst eq 'PICARD') {
    push( @path, File::Spec->catdir( $root, "PICARD" ) );
    push( @path, File::Spec->catdir( $root, 'SCUBA2') );
    push( @path, $het_root );
    push( @path, $jsa_root );
    push( @path, $general_root );
  } else {
    croak "Primitives: Unrecognised instrument: $inst\n";
  }

  return @path;
}

=item B<orac_determine_calibration_search_path>

Returns a list of directories that should be searched in order
to locate calibration files for the specified instrument.

  @paths = orac_determine_calibration_search_path( $instrument );

Root location is specified by the C<ORAC_CAL_ROOT> environment
variable. ORAC_DATA_CAL is included if it is set explicitly.

=cut

sub orac_determine_calibration_search_path {
  my $inst = uc( shift );
  my @path;

  my $root;
  if( exists $ENV{'ORAC_CAL_ROOT'} ) {
    $root = $ENV{'ORAC_CAL_ROOT'};
  } else {
    croak "Unable to determine ORAC_CAL_ROOT location";
  }

  my $general_ir_root = File::Spec->catdir( $root, "general-IR" );
  my $general_submm_root = File::Spec->catdir( $root, "general-submm" );
  my $general_root = File::Spec->catdir( $root, "general" );

  if( $inst eq 'SCUBA' ) {
    push( @path, File::Spec->catdir( $root, 'scuba' ) );
    push( @path, $general_submm_root );

  } elsif( $inst eq 'JCMT_DAS' ) {
    push( @path, File::Spec->catdir( $root, 'jcmt_das' ) );
    push( @path, $general_submm_root );

  } elsif( $inst =~ /^ACSIS/ ) {
    push( @path, File::Spec->catdir( $root, 'acsis' ) );
    push( @path, $general_submm_root );

  } elsif( $inst =~ /^SCUBA2/ ) {
    push( @path, File::Spec->catdir( $root, 'scuba2' ) );
    push( @path, $general_submm_root );

  } elsif( $inst eq 'CGS4' or $inst eq 'OCGS4' ) {
    push( @path, File::Spec->catdir( $root, 'cgs4' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'IRCAM' or $inst eq 'IRCAM2' ) {
    push( @path, File::Spec->catdir( $root, 'ircam' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'UFTI' or $inst eq 'UFTI2' ) {
    push( @path, File::Spec->catdir( $root, 'ufti' ) );
    push( @path, $general_ir_root );

  } elsif( $inst =~ /^WFCAM/ ) {
    push( @path, File::Spec->catdir( $root, 'wfcam' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'MICHELLE' or $inst eq 'MICHTEMP' or $inst eq 'MICHGEM' ) {
    push( @path, File::Spec->catdir( $root, 'michelle' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'UIST' ) {
    push( @path, File::Spec->catdir( $root, 'uist' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'IRIS2' ) {
    push( @path, File::Spec->catdir( $root, 'iris2' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'INGRID' ) {
    push( @path, File::Spec->catdir( $root, 'ingrid' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'ISAAC' ) {
    push( @path, File::Spec->catdir( $root, 'isaac' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'NACO' ) {
    push( @path, File::Spec->catdir( $root, 'naco' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'SOFI' ) {
    push( @path, File::Spec->catdir( $root, 'sofi' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'GMOS' or $inst eq 'GMOS2' ) {
    push( @path, File::Spec->catdir( $root, 'gmos' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'NIRI' or $inst eq 'NIRI2' ) {
    push( @path, File::Spec->catdir( $root, 'niri' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'CLASSICCAM' ) {
    push( @path, File::Spec->catdir( $root, 'classiccam' ) );
    push( @path, $general_ir_root );

  } elsif( $inst eq 'SPEX' ) {
    push( @path, File::Spec->catdir( $root, 'spex' ) );
    push( @path, $general_ir_root );

  } else {

    croak "Calibration directories: Unrecognised instrument: $inst\n";
  }

  # Add ORAC_DATA_CAL to the front of the search path if it exists
  if (exists $ENV{ORAC_DATA_CAL}) {
    unshift(@path, $ENV{ORAC_DATA_CAL});
  }

  return @path;

}

=item B<orac_determine_initial_algorithm_engines>

For the supplied instrument name, returns a list containing the names
of engines to be launched by the pipeline prior to executing any
recipes. This is used so that engines that are always used will be
available at the start of execution rather than being launched on
demand. This approach provides a slight efficiency gain over starting
each engine on demand.

  @engines = orac_determine_initial_algorithm_engines( $instrument)

In principal this list can be empty if no pre-launching is required.

=cut

sub orac_determine_initial_algorithm_engines {
  my $inst = uc($_[0]);

  # Array of mandatory engines
  my @AlgEng;
  if ($inst eq 'SCUBA') {

    @AlgEng = qw/ surf_mon ndfpack_mon kappa_mon /;

  } elsif ($inst =~ /^SCUBA2/) {

    @AlgEng = (); # none at the moment

  } elsif ($inst eq 'JCMT_DAS') {

    @AlgEng = qw/ ndfpack_mon kappa_mon /;

  } elsif( $inst eq 'ACSIS' ) {

    @AlgEng = qw/ ndfpack_mon kappa_mon smurf_mon cupid_mon/;

  } elsif ($inst eq 'ACSIS_QL') {

    @AlgEng = qw/ ndfpack_mon kappa_mon /;

  } elsif ($inst eq 'CGS4') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_reg /;

  } elsif ($inst eq 'IRCAM') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } elsif ($inst eq 'MICHELLE') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg /;

  } elsif ($inst eq 'UIST') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg atools_mon /;

  } elsif ($inst =~ /^WFCAM/) {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /;

  } elsif ($inst eq 'INGRID') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } elsif ($inst eq 'IRIS2') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg ccdpack_res /

  } elsif ($inst eq 'ISAAC') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg atools_mon /;

  } elsif ($inst eq 'NACO') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg /;

  } elsif ($inst eq 'SOFI') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_red ccdpack_reg atools_mon /;

  } elsif ($inst eq 'GMOS') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } elsif ($inst eq 'NIRI') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } elsif ($inst eq 'CLASSICCAM') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } elsif ($inst eq 'SPEX') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
		  ccdpack_res /;

  } elsif ($inst eq 'PICARD') {

    @AlgEng = qw/ kappa_mon ndfpack_mon /;

  } else {
    croak "Do not know which engines are required for instrument $inst";
  }

  # Return the hash reference
  return @AlgEng;
}

=item B<orac_configure_for_instrument>

This routines configures the user environment (e.g. %ENV) for the instrument,
it is called by Xoracdr to replace functionality present in the c-shell setup scripts.

   orac_configure_for_instrument( $instrument, \%options );

=cut

sub orac_configure_for_instrument {

  croak 'Usage: orac_configure_for_instrument( $instrument, \%options )'
    unless scalar(@_) == 2 ;

  my ( $instrument, $options ) = @_;
  $instrument = uc($instrument);

  # We always need to know the UT
  # Take local $oracut from %options{"ut"} in
  # case someone has already et the UT date in the GUI
  my $oracut = $options->{'ut'};

  # Default to no skip
  $options->{skip} = 0;

  # Map the XORAC-DR instrument to low-level ORAC_INSTRUMENT
  if ( $instrument eq "CGS4" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "CGS4";

  } elsif ( $instrument eq "UIST" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "UIST";

  } elsif ( $instrument eq "MICHELLE" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "MICHELLE";

  } elsif ( $instrument eq 'MICHGEM' ) {

    # Instrument
    $ENV{'ORAC_INSTRUMENT'} = 'MICHGEM';

  } elsif ( $instrument eq "IRCAM" or $instrument eq "IRCAM2") {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "IRCAM2";

  } elsif ( $instrument =~ /IRCAM \(old\)/i ) {
    # Can't distinguish IRCAM from IRCAM2 !!

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "IRCAM";

  } elsif ( $instrument eq "SCUBA" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "SCUBA";

    $options->{"skip"} = 1;

  } elsif ( $instrument eq 'JCMT_DAS' ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "JCMT_DAS";

  } elsif ( $instrument eq 'ACSIS' ) {

    # Instrument.
    $ENV{'ORAC_INSTRUMENT'} = 'ACSIS';

  } elsif ( $instrument eq 'SCUBA-2 (850)' || $instrument eq 'SCUBA2_850') {
    $ENV{ORAC_INSTRUMENT} = "SCUBA2_850";

  } elsif ( $instrument eq 'SCUBA-2 (450)' || $instrument eq 'SCUBA2_450') {
    $ENV{ORAC_INSTRUMENT} = "SCUBA2_450";

  } elsif ( $instrument eq "UFTI" or $instrument eq "UFTI2") {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "UFTI2";

  } elsif ( $instrument =~ /UFTI \(old\)/i) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "UFTI";

  } elsif ( $instrument =~ /^WFCAM/ ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = $instrument;
    $options->{"skip"} = 1;

  } elsif ( $instrument eq "INGRID" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "INGRID";

  } elsif ( $instrument eq "IRIS2" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "IRIS2";

  } elsif ( $instrument eq "ISAAC" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "ISAAC";

  } elsif ( $instrument eq "NACO" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "NACO";

  } elsif ( $instrument eq "SOFI" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "SOFI";

  } elsif ( $instrument eq "GMOS" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = "GMOS";

  } elsif ( $instrument eq "NIRI" || $instrument eq "NIRI2" ) {

    # Instrument
    $ENV{"ORAC_INSTRUMENT"} = $instrument;
  } else {
    orac_err(" Instrument $instrument is not currently supported by Xoracdr\n");
  }

  # get the recommended values
  my %env = ORAC::Inst::SetupEnv::orac_calc_instrument_settings( $ENV{ORAC_INSTRUMENT}, %$options );

  # Handle options
  for my $a (keys %{$env{args}}) {
    $options->{$a} = $env{args}->{$a} unless defined $options->{$a};
  }
  delete $env{args};

  # Copy the resultant keys into the environment
  for my $k (keys %env) {
    # be careful to ignore _ROOT variables so as not
    # to trash the xoracdr environment
    next if $k eq 'ORAC_DATA_ROOT';
    next if $k eq 'ORAC_CAL_ROOT';
    next if ($k eq 'ORAC_DATA_OUT' && $options->{honour});

    $ENV{$k} = $env{$k};
  }
  return;
}

=item B<orac_guess_instrument>

Given a Frame object (assumed to be a generic type frame with
a translated FITS header) make a guess at the corresponding
ORAC_INSTRUMENT that should be used.

  $guess = orac_guess_instrument( $Frm );

Useful for converting a base class or a PICARD variant to
a specific type.

Returns undef if none can be guessed.

=cut

sub orac_guess_instrument {
  my $Frm = shift;
  return unless defined $Frm;

  # Get the instrument name and the backend
  my $instrument = $Frm->uhdr( "ORAC_INSTRUMENT" );
  return unless defined $instrument;

  my $backend = $Frm->uhdr( "ORAC_BACKEND" );

  my $oa;
  if (defined $backend &&
      ($backend eq 'ACSIS' || $backend eq 'DAS' || $backend eq 'AOSC')) {
    $oa = "ACSIS";
  } elsif ($instrument eq 'SCUBA-2') {
    $oa = 'SCUBA2';

    # Need to know the subsystem which is not a translated property
    my $hdr = $Frm->hdr;
    my $subsysnr;
    if( exists $hdr->{SUBSYSNR} && defined $hdr->{SUBSYSNR}) {
      $subsysnr = $hdr->{SUBSYSNR};
    } elsif (exists $hdr->{WAVELEN} && defined $hdr->{WAVELEN} ) {
      if ( $hdr->{WAVELEN} > 600e-6 ) {
        $subsysnr = "850";
      } else {
        $subsysnr = "450";
      }
    }
    $oa .= "_$subsysnr" if defined $subsysnr;
  } else {
    # go with instrument. We can add more clauses as we come across more issues
    $oa = $instrument;
  }

  return $oa;
}

=item B<orac_engine_description>

Returns the details for a specified algorithm engine.

  %details = orac_engine_description("polpack_mon");

The hash that is returned contains information on the
class to be used to launch the engine and the location
of the engine. In future it may also return the messaging
system required for the engine to function. The hash currently
has the following keys

=over 4

=item CLASS

The name of the class to be used for this engine.
(e.g. C<ORAC::Msg::Task::ADAM>).

=item PATH

The location of the engine in the file system. If this
is a code reference it should be executed immediately
prior to launching the monolith to configure associated
parameters correctly and to return the actual path.
Additionally, if the helper task is executed it returns
a reference to a cleanup subroutine. See L<"HELPER TASKS">.

=item MESSYS

The name of the message system required to contact the engine.
See L<"orac_messys_description">.

=back

Returns an empty list on error.

If the engine is not specified but is defined in $ORAC_REMOTE_TASK
environment variable, the task is assumed to be DRAMA.

=cut

sub orac_engine_description {
  my $engine = shift;
  if (exists $MonolithDefns{$engine}) {
    return %{ $MonolithDefns{$engine} };
  } else {
    # Look in ORAC_REMOTE_TASK (assumed to be DRAMA)
    my @tasks = orac_remote_task();
    for my $t (orac_remote_task()) {
      if ($engine eq $t) {
	return ( MESSYS => 'DRAMA',
		 CLASS => 'ORAC::Msg::Task::DRAMA');
      }
    }
    return ();
  }
}

=item B<orac_messys_description>

Returns the details for a specified message system.

  %details = orac_messys_description("AMS");

The hash that is returned contains information on the
class to be used to initialise the message system.
It has the following keys

=over 8

=item CLASS

The name of the class to be used for this message system
(e.g. C<ORAC::Msg::ADAM::Control>).

=back

Returns an empty list on error.

=cut

sub orac_messys_description {
  my $engine = shift;

  if (exists $MessageSystemDefns{$engine}) {
    return %{ $MessageSystemDefns{$engine} };
  } else {
    return ();
  }
}

=item B<orac_remote_task>

Returns the override task names specified by the $ORAC_REMOTE_TASK
environment variable.

  @tasks = orac_remote_task();

=cut

sub orac_remote_task {
  if (exists $ENV{ORAC_REMOTE_TASK} && defined $ENV{ORAC_REMOTE_TASK}
      && $ENV{ORAC_REMOTE_TASK} =~ /\w/) {
     return split(/,/, $ENV{ORAC_REMOTE_TASK});
  }
  return ();
}

=back

=head1 HELPER TASKS

Some algorithm engines need to be configured in a slighlty more complex
way than providing a simple path to the engine. This section
describes specific functions that return the name of the path whilst
also configuring the program before launch. For example, can be used
to create a temporary directory for special output. The helper tasks
accept no arguments and are required to return a path to an
engine and a reference to a subroutine to be exected when the
object has been launched. This allows for cleanup code to be executed
and are usually closures.

=over 4

=item B<fluxes_helper>

This function configures the fluxes specific environment variables
and creates a temporary output directory for use by fluxes.

 ($path, $callback) = fluxes_mon_helper;

Returns the path to the monolith and a cleanup function.
The cleanup function is required to change directory back to the
directory that we need to be in (since Fluxes requires the directory
to have special files in it).

=cut

sub fluxes_helper {

  # To start FLUXES requires some environment variables to be defined
  # Fluxes should be changed to use $FLUXES_DIR rather than $FLUXES
  # Some of these are historical. Newer versions are much easier
  unless (exists $ENV{FLUXES}) {
    # FLUXES_DIR is set on recent starlink releases
    if (exists $ENV{FLUXES_DIR}) {
      $ENV{FLUXES} = $ENV{FLUXES_DIR};
    } else { # Guess by looking at the location of starlink
      $ENV{FLUXES} = File::Spec->catdir($StarConfig{Star_Bin},"fluxes");
    }
  }

  # Now check that FLUXES directory really does exist
  croak "Error locating fluxes directory. $ENV{FLUXES} does not exist"
    unless -d $ENV{FLUXES};

  # Should chdir to /tmp, create the soft link, launch fluxes
  # and then chdir back to wherever we happen to be.

  my $cwd = cwd; # Store current dir
  croak "Error determining current working directory. Seems we got undef!"
    unless defined $cwd;

  # Create temp directory - this is needed in case another
  # oracdr is running fluxes and we want to make sure that
  # the JPLEPH file is not removed when THAT oracdr finishes!
  # Should probably be using File::Temp::tempdir
  my $tmpdir = File::Spec->catdir(File::Spec->tmpdir,"fluxes_$$");

  # Register this with a cleanup END block
  # Set up an END block to remove the directory on shutdown
  # This is the only way to tidy up in a non-object-oriented
  # approach, especially if there is no way of supplying this
  # information to the caller.
  push (@DIRS_TO_UNLINK, $tmpdir);


  # Create them
  mkdir $tmpdir,0777 || croak "Could not make directory $tmpdir: $!";

  chdir($tmpdir) || croak "Could not change directory to $tmpdir: $!";

  # Hard-wire in the location of JPLEPH
  # $JPL_DIR is available on newer systems
  # Create soft link to JPLEPH

  # If the JPLEPH file is there already then assume it is okay
  # not sure how that can happen given that we just made the directory!
  unless (-f "JPLEPH") {
    unlink "JPLEPH"; # should be nothing here

    # Determine location of ephemeris file
    my $ephdir = ( $ENV{JPL_DIR} ||
       File::Spec->catdir($StarConfig{Star},"etc") );

    my $jpleph = File::Spec->catfile($ephdir, "jpleph.dat");

    # Check that the file exists first
    croak "Could not find JPLEPH file at $jpleph" unless -f $jpleph;

    # Create the soft link required for JPLEPH software to run
    symlink $jpleph, "JPLEPH"
      or croak "Could not create link to JPL ephemeris";
  }

  # Set FLUXPWD variable, required by FLUXES
  $ENV{'FLUXPWD'} = $tmpdir;

  # Create cleanup sub
  my $cleanup = sub { chdir $cwd; };

  # Create path to monolith
  my $path = File::Spec->catfile($ENV{FLUXES}, "fluxes");

  # Need to return the path and the closure
  return ( $path, $cleanup );
}

=item B<p4_helper>

Helper task for the CGS4-DR P4 display system.

  ($path, $cleanup) = p4_helper;

=cut

sub p4_helper {

  # Set some P4 environment variables
  if (exists $ENV{CGS4DR_ROOT}) {
    $ENV{P4_ROOT} = $ENV{CGS4DR_ROOT};
  } else {
    orac_err('CGS4DR_ROOT environment variable not defined. Cannot find P4.\n');
    return;
  }
  $ENV{P4_CONFIG} = File::Spec->catdir($ENV{HOME}, ".oracdr");
  $ENV{P4_HOME} = $ENV{P4_ROOT};
  $ENV{P4_EXE}  = $ENV{P4_ROOT};
  $ENV{P4_ICL}  = $ENV{P4_ROOT};
  if (exists $ENV{ORAC_DATA_OUT}) {
    $ENV{P4_DATA} = $ENV{ORAC_DATA_OUT};
  } else {
    $ENV{P4_DATA} = File::Spec->tmpdir;
  }
  $ENV{P4_CT}   = File::Spec->catdir($ENV{P4_ROOT}, "ndf");
  $ENV{P4_HC}   = cwd;
  $ENV{P4_DATE} = '19980804';  # irrelevant (I hope)
  $ENV{RGDIR}   = $ENV{P4_DATA};
  $ENV{RODIR}   = $ENV{P4_DATA};
  $ENV{RIDIR}   = $ENV{P4_DATA};
  $ENV{ODIR}   = $ENV{P4_DATA};
  $ENV{IDIR}   = $ENV{P4_DATA};

  # Make the CGS4DR scratch directories
  unless (-d $ENV{P4_CONFIG}) {
    unlink $ENV{P4_CONFIG};       # naughty!
    my $status = mkdir($ENV{P4_CONFIG}, 0770);
    if ($status) {
      orac_print("Creating ORACDR configuration directory...\n");
    } else {
      orac_err("Error creating ORACDR config dir: $!\n");
      return;
    }
  }

  # Do P4 startup - copy in a default file
  # unless one is there already.
  unless (-e File::Spec->catfile($ENV{P4_CONFIG}, "default.p4")) {
    orac_print("Creating a default P4 startup file\n",'blue');
    copy (File::Spec->catfile($ENV{P4_ROOT}, "default.p4"),
    File::Spec->catfile($ENV{P4_CONFIG}, "default.p4"));
  }

  # No cleanup
  # Return it all
  return ("$ENV{CGS4DR_ROOT}/p4", undef);
}

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>,
Paul Hirst E<lt>p.hirst@jach.hawaii.eduE<gt>,
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2006 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
