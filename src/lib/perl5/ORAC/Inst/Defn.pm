package ORAC::Inst::Defn;

=head1 NAME

ORAC::Inst::Defn - Definition of instrument class dependencies

=head1 SYNOPSIS

  use ORAC::Inst::Defn;

  @pars = orac_determine_inst_classes( $instrument );


=head1 DESCRIPTION

This module provides all the instrument specific initialisation
information. This is the information required by ORAC-DR in order
to configure itself before the data detection loop can begin.

This module provides information on class hierarchies, recipe
search paths and intialisation or algorithm engines.

All instrument dependencies are specified in this module.

=cut

use strict;
use Carp;
use File::Spec;
use File::Path;
use Cwd;

use ORAC::Print;

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
  orac_engine_description
  orac_messys_description
  /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Cleanup END blocks. Useful if helper tasks create temporary
# files or directories and dont use File::Temp
# In future should make File::Temp mandatory

# Two lexical array, one for files and one for directories
my (@FILES_TO_UNLINK, @DIRS_TO_UNLINK);

# This code comes directly from File::Temp

END {
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

BEGIN { # A kluge - for some reason kapview does not pick up the
  # correct environment if I leave out the BEGIN block
  # dont understand since the environment is passed to the forked
  # process...
  # Need the second arg in perl versions prior to 5.6.0
  mkdir File::Spec->catdir(File::Spec->tmpdir,"oracdragi"),0777
    or croak "Could not make AGI temp directory: $!";
  $ENV{'AGI_USER'} = "/tmp/oracdragi";
  $ENV{'AGI_NODE'} = "orac_kapview$$";
}

push( @DIRS_TO_UNLINK, "/tmp/oracdragi");



# Internal definitions of algoirthm engine definitions
# Used to construct instrument recipe dependencies

my %MonolithDefns = (
		     kappa_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{KAPPA_DIR}."/kappa_mon",
				  },
		     surf_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{SURF_DIR}/surf_mon",
				  },
		     polpack_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{POLPACK_DIR}/polpack_mon",
				  },
		     ccdpack_reg => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_reg",
				  },
		     ccdpack_red => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_red",
				  },
		     ccdpack_res => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_res",
				  },
		     catselect => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CURSA_DIR}/catselect",
				  },
		     ndf2fits => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CONVERT_DIR}/ndf2fits",
				  },
		     fits2ndf => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CONVERT_DIR}/fits2ndf",
				 },
		     convert_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{CONVERT_DIR}/convert_mon",
				 },
		     kapview_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{KAPPA_DIR}."/kapview_mon",
				  },
		     ndfpack_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{KAPPA_DIR}."/ndfpack_mon",
				  },
		     figaro1 => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{FIG_DIR}."/figaro1",
				  },
		     figaro2 => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{FIG_DIR}."/figaro2",
				  },
		     figaro4 => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => $ENV{FIG_DIR}."/figaro4",
				  },
		     pisa_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{PISA_DIR}/pisa_mon",
				  },
		     photom_mon => {
				   MESSYS => 'AMS',
				   CLASS => 'ORAC::Msg::Task::ADAM',
				   PATH => "$ENV{PHOTOM_DIR}/photom_mon",
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
		     test_mon   => {
				    MESSYS => 'AMS',
				    CLASS => 'ORAC::Msg::Task::ADAM',
				    PATH => "this/is/junk",
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
				       }
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
  } elsif ($inst eq 'UFTI') {
    $groupclass = "ORAC::Group::UFTI";
    $frameclass = "ORAC::Frame::UFTI";
    $calclass   = "ORAC::Calib::IRCAM";
    $instclass  = "ORAC::Inst::IRCAM";
  } elsif ($inst eq 'UFTI2') {
    $groupclass = "ORAC::Group::UFTI";
    $frameclass = "ORAC::Frame::UFTI2";
    $calclass   = "ORAC::Calib::IRCAM";
    $instclass  = "ORAC::Inst::IRCAM";
    $inst = 'UFTI'; # to pick UFTI recipes and primitives as they are
  } elsif ($inst eq 'CGS4') {
    $groupclass = "ORAC::Group::CGS4";
    $frameclass = "ORAC::Frame::CGS4";
    $calclass   = "ORAC::Calib::CGS4";
    $instclass  = "ORAC::Inst::CGS4";
  } elsif ($inst eq 'SCUBA') {
    $groupclass = "ORAC::Group::JCMT";
    $frameclass = "ORAC::Frame::JCMT";
    $calclass   = "ORAC::Calib::SCUBA";
    $instclass  = "ORAC::Inst::SCUBA";
  } elsif ($inst eq 'MICHTEMP') {
    $groupclass = "ORAC::Group::Michelle";
    $frameclass = "ORAC::Frame::MichTemp";
    $calclass = "ORAC::Calib::CGS4";
    $instclass = "ORAC::Inst::CGS4";
  } elsif ($inst eq 'MICHELLE') {
    $groupclass = "ORAC::Group::Michelle";
    $frameclass = "ORAC::Frame::Michelle";
    $calclass = "ORAC::Calib::CGS4";
    $instclass = "ORAC::Inst::CGS4";
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
  return ($frameclass, $groupclass, $calclass, $instclass);
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
    $root = File::Spec->catdir($ENV{ORAC_DIR}, "recipes");
  } else {
    croak "Unable to determine ORAC_DIR location";
  }

  if ($inst eq 'SCUBA') {
    push(@path, File::Spec->catdir( $root, 'SCUBA'));
  } elsif ($inst eq 'CGS4') {
    push(@path, File::Spec->catdir( $root, 'CGS4'));
  } elsif ($inst eq 'IRCAM' or $inst eq 'IRCAM2') {
    push(@path, File::Spec->catdir( $root, "IRCAM"));
  } elsif ($inst eq 'UFTI' or $inst eq 'UFTI2') {
    push(@path, File::Spec->catdir( $root, "UFTI"));
  } elsif ($inst eq 'MICHELLE' or $inst eq 'MICHTEMP') {
    push(@path, File::Spec->catdir( $root, "MICHELLE"));
  } else {
    croak "recipes: Unrecognised instrument: $inst\n";
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
    $root = File::Spec->catdir($ENV{ORAC_DIR}, "primitives");
  } else {
    croak "Unable to determine ORAC_DIR location";
  }

  if ($inst eq 'SCUBA') {
    push(@path, File::Spec->catdir( $root, 'SCUBA'));
  } elsif ($inst eq 'CGS4') {
    push(@path, File::Spec->catdir( $root, 'CGS4'));
  } elsif ($inst eq 'IRCAM' or $inst eq 'IRCAM2') {
    push(@path, File::Spec->catdir( $root, "IRCAM"));
  } elsif ($inst eq 'UFTI' or $inst eq 'UFTI2') {
    push(@path, File::Spec->catdir( $root, "UFTI"));
  } elsif ($inst eq 'MICHELLE' or $inst eq 'MICHTEMP') {
    push(@path, File::Spec->catdir( $root, "MICHELLE"));
  } else {
    croak "primitives: Unrecognised instrument: $inst\n";
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

    @AlgEng = qw/ surf_mon ndfpack_mon /;

  } elsif ($inst eq 'CGS4') {

    @AlgEng = qw/ figaro1 figaro2 figaro4 kappa_mon ndfpack_mon
      ccdpack_reg /;


  } elsif ($inst eq 'IRCAM') {

    @AlgEng = qw/ kappa_mon ndfpack_mon ccdpack_red ccdpack_reg
      ccdpack_res /

  } else {
    croak "Do not know which engines are required for instrument $inst";
  }

  # Return the hash reference
  return @AlgEng;
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

=cut

sub orac_engine_description {
  my $engine = shift;

  if (exists $MonolithDefns{$engine}) {
    return %{ $MonolithDefns{$engine} };
  } else {
    return ();
  }
}

=item B<orac_messys_description>

Returns the details for a specified message system.

  %details = orac_messys_description("AMS");

The hash that is returned contains information on the
class to be used to initialise the message system.
It has the following keys

=over 4

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
      $ENV{FLUXES} = $StarConfig{Star_Bin} ."/fluxes";	
    }
  }

  # Now check that FLUXES directory really does exist
  croak "Error locating fluxes directory. $ENV{FLUXES} does not exist"
    unless -d $ENV{FLUXES};

  # Should chdir to /tmp, create the soft link, launch fluxes
  # and then chdir back to wherever we happen to be.

  my $cwd = cwd; # Store current dir

  # Create temp directory - this is needed in case another
  # oracdr is running fluxes and we want to make sure that
  # the JPLEPH file is not removed when THAT oracdr finishes!
  # Should probably be using File::Temp::tempdir
  my $tmpdir = "/tmp/fluxes_$$";

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
    my $ephdir = ( $ENV{JPL_DIR} || $StarConfig{Star}."/etc/jpl" );

    my $jpleph = $ephdir . "/jpleph.dat";

    # Check that the file exists first
    croak "Could not find JPLEPH file at $jpleph" unless -f $jpleph;

    # Create the soft link required for JPLEPH software to run
    symlink $jpleph, "JPLEPH"
      or croak "Could not create link to JPL ephemeris";
  }

  # Set FLUXPWD variable, required by FLUXES
  $ENV{'FLUXPWD'} = cwd;

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
    return undef;
  }
  $ENV{P4_CONFIG} = $ENV{HOME} . "/.oracdr";
  $ENV{P4_HOME} = $ENV{P4_ROOT};
  $ENV{P4_EXE}  = $ENV{P4_ROOT};
  $ENV{P4_ICL}  = $ENV{P4_ROOT};
  if (exists $ENV{ORAC_DATA_OUT}) {
    $ENV{P4_DATA} = $ENV{ORAC_DATA_OUT};
  } else {
    $ENV{P4_DATA} = '/tmp';
  }
  $ENV{P4_CT}   = $ENV{P4_ROOT} . "/ndf";
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
      return undef;
    }
  }

  # Do P4 startup - copy in a default file
  # unless one is there already.
  unless (-e $ENV{P4_CONFIG} . "/default.p4") {
    orac_print("Creating a default P4 startup file\n",'blue');
    copy ($ENV{P4_ROOT} . "/default.p4", $ENV{P4_CONFIG} . "/default.p4");
  }

  # No cleanup
  # Return it all
  return ("$ENV{CGS4DR_ROOT}/p4", undef);
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>


=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
