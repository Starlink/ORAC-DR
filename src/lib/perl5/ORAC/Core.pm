package ORAC::Core;

=head1 NAME

ORAC::Core - core routines for data pipelining

=head1 SYNOPSIS

  use ORAC::Core;

  orac_process_frame($Frm, $Grp, $Cal,\%Mon,$OverRecipe, $instrument);

  orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr, $ut);

=head1 DESCRIPTION

This module contains the core routines that actually handle the 
data processing. Routines are provided for constructing groups
and for processing those groups.

=cut

use strict;
use Carp;

use ORAC::Print;
use ORAC::Recipe;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_process_frame orac_store_frm_in_correct_grp /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);



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
        $ut, $resume);
  orac_store_frm_in_correct_grp($Frm, $GrpType, \%Groups, undef, 
        $ut, $resume);

The resume flag is used to determine the behaviour of the group when
it is first created. If resume is false, any existing Group file is 
removed before proceeding; if it is true, the Group file is retained
and any coadd information is read using the coaddsread() Group
method.

The current Grp (ie the Group associated with the supplied Frm)
is returned.

=cut


sub orac_store_frm_in_correct_grp {

  croak 'Usage: orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr,$ut, $resume)'
    unless scalar(@_) == 6;

  # Variable declaration - Frossie loves this stuff :-)
  my ($use_arr, $Grp);

  # Read the argument list
  my ($Frm, $GrpObjectType, $GrpHash, $GrpArr, $ut, $resume) = @_;

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

  # query Frame for its group

  my $grpname = $Frm->group;

  # create a new group object and remove the previous file
  # unless such an object already exists
  # note that the "existence" of this group is only meaningful
  # over the lifetime of the pipeline
  # Unless the primitive is written to recognise -resume

  do {

    # Create the group
    $Grp = new $GrpObjectType($grpname);

    # File name from constrituent parts
    # If the group name is a number itself we should
    # use it rather than the current frame number
    my $grpnum = ( $grpname =~ /^\d+$/ ? $grpname : $Frm->number);
    $Grp->file($Grp->file_from_bits($ut, $grpnum));
    $GrpHash->{$grpname} = $Grp;		# store group object
    orac_print ("A new group ".$Grp->file." has been created\n","blue");

    # Store the Grp on the array as well
    push(@$GrpArr, $Grp) if $use_arr;

    # Deal with the resume flag
    # Only relevant if the Group file already exists
    if ($Grp->file_exists) {
      if ($resume) {
	$Grp->coaddsread;
	$Grp->readhdr;
      } else {
	$Grp->erase;
      }
    }

  } unless (exists $GrpHash->{$grpname});

  # Retrieve the current group object
  $Grp = $GrpHash->{$grpname};

  # push current Frame onto Group
  $Grp->push($Frm);
  orac_print ("This observation is part of group ".$Grp->file."\n","blue");

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

  orac_process_frame(
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
                     );

Additional parameters are provided to configure the recipe
environment. Defaults are provided for Debug and Batch.
(both false). Those options relate to the C<-debug> and C<-batch>
command line options.

=cut


sub orac_process_frame {

  my %args = @_;

  # Require Frame, Group, Calibration, Display and Engines
  for (qw/ Frame Group Calibration Display Engines Instrument/) {
    croak "orac_process_frame: Arg hash must include keyword $_\n"
      unless exists $args{$_};
  }

  # Check args
  croak "Engines must be supplied as hash reference\n"
    unless ref($args{Engines}) eq 'HASH';

  # Copy the objects
  my $Frm = $args{Frame};
  my $Grp = $args{Group};
  my $Cal = $args{Calibration};
  my $Mon = $args{Engines};
  my $Display = $args{Display};


  # Store the header of the current frame in the calibration object
  $Cal->thing($Frm->hdr);

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
  };

  # Create new recipe object
  my $recipe = new ORAC::Recipe( NAME => $RecipeName,
				 INSTRUMENT => $args{Instrument});

  # Configure debugging and batch flags
  $recipe->debug( $args{Debug} ) if exists $args{Debug};
  $recipe->batch( $args{Batch} ) if exists $args{Batch};


  # parse the recipe
  $recipe->parse;

  # Execute the recipe
  $recipe->execute( $Frm, $Grp, $Cal, $Display, $Mon );

  # delete symlink to raw data file
  # Only want to do this if we created it initially....
  unlink($Frm->raw) if (-l $Frm->raw);


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
