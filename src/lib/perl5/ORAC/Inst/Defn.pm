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
require Exporter;
use vars qw/ @ISA @EXPORT_OK $VERSION /;

@ISA = qw/ Exporter /;
@EXPORT_OK = qw/ 
  orac_determine_inst_classes
  orac_determine_algorithm_engines
  orac_determine_recipe_search_path
  orac_determine_primitive_search_path
  orac_engine_description
  /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Internal definitions of algoirthm engine definitions
# Used to construct instrument recipe dependencies

my %MonolithDefns = (
		     kappa_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{KAPPA_DIR}."/kappa_mon",
				  },
		     surf_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{SURF_DIR}/surf_mon",
				  },
		     polpack_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{POLPACK_DIR}/polpack_mon",
				  },
		     ccdpack_reg => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_reg",
				  },
		     ccdpack_red => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_red",
				  },
		     ccdpack_res => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{CCDPACK_DIR}/ccdpack_res",
				  },
		     catselect => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{CURSA_DIR}/catselect",
				  },
		     ndf2fits => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{CONVERT_DIR}/ndf2fits",
				  },
		     kapview_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{KAPPA_DIR}."/kapview_mon",
				  },
		     ndfpack_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{KAPPA_DIR}."/ndfpack_mon",
				  },
		     figaro1 => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{FIG_DIR}."/figaro1",
				  },
		     figaro2 => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{FIG_DIR}."/figaro2",
				  },
		     figaro4 => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => $ENV{FIG_DIR}."/figaro4",
				  },
		     pisa_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{PISA_DIR}/pisa_mon",
				  },
		     photom_mon => {
				   CLASS => 'ORAC::Msg::ADAM::Task',
				   PATH => "$ENV{PHOTOM_DIR}/photom_mon",
				  },
		     test_mon   => {
				    CLASS => 'ORAC::Msg::ADAM::Task',
				    PATH => "this/is/junk",
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


=item B<orac_determine_algorithm_engines>

For the supplied instrument name, returns a reference to a hash
containing keys of the name of the engine and values of an anonymous
hash with the location and type of the engine and whether the engine
is optional or required. An example structure is:

  %algeng = (
	     kappa_mon => {
			   CLASS => 'ORAC::Msg::ADAM::Task',
			   PATH  => "$ENV{KAPPA_DIR}/kappa_mon"
			   REQUIRED => 1,
			  },
	     ccdpack_reg => {
			     ...
			    }
	    );

  $algeng = orac_determine_algorithm_engines( $instrument );

It is possible that this information may be moved to the specific
instrument frame class. Once engine-launch-on-demand is implemented
this routine will most likely become obsolete.

=cut

sub orac_determine_algorithm_engines {
  my $inst = uc($_[0]);

  # internally, set up a simple hash where the keys are the
  # alg engine names and the value is whether the engine is
  # mandatory or not. Then translate this hash to the required 
  # format by merging with the monolith definitions from the start
  # of the file. Really need launch-on-demand

  my %alg;
  if ($inst eq 'SCUBA') {

    %alg = (
	    surf_mon => 1,
	    kappa_mon => 1,
	    kapview_mon => 1,
	    ndfpack_mon => 1,
	    ndf2fits => 0,
	    polpack_mon => 0,
	    ccdpack_reg => 0,
	    catselect => 0,
	   );

  } elsif ($inst eq 'CGS4') {

    %alg = (
	    figaro1 => 1,
	    figaro2 => 1,
	    figaro4 => 1,
	    ndf2fits => 1,
	    ccdpack_reg => 1,
	    kappa_mon => 1,
	    ndfpack_mon => 1,
	   );


  } elsif ($inst eq 'IRCAM') {

    %alg = (
	    photom_mon => 1,
	    ccdpack_red => 1,
	    ccdpack_reg => 1,
	    ccdpack_res => 1,
	    kappa_mon => 1,
	    ndfpack_mon => 1,
	    pisa_mon => 1,
	    polpack_mon => 1,
	    catselect => 1,
	   );

  } else {
    croak "Do not know which engines are required for instrument $inst";
  }

  # Now generate the required return hash
  my %AlgEng;
  for my $eng (keys %alg) {

    $AlgEng{$eng} = {
		     %{ $MonolithDefns{$eng} },
		     REQUIRED => $alg{$eng},
		    };
  }

  # Return the hash reference
  return \%AlgEng;
}

=item B<orac_engine_description>

Returns the details for a specified algorithm engine.

  %details = orac_engine_description("polpack_mon");

The hash that is returned contains information on the
class to be used to launch the engine and the location
of the engine. In future it may also return the messaging
system required for the engine to function.

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
