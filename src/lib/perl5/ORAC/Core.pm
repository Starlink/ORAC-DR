package ORAC::Core;

=head1 NAME

ORAC::Core - core routines for data pipelining

=head1 SYNOPSIS

  use ORAC::Core;

  orac_process_frame($Frm, $Grp, $Cal, $OverRecipe, $instrument);

  orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr, $ut);

=head1 DESCRIPTION

This module contains the core routines that actually handle the 
data processing. Routines are provided for constructing groups
and for processing those groups.

=cut

use strict;
use Carp;

use ORAC::Print;
use ORAC::Basic;

require Exporter;

use vars qw/$VERSION @EXPORT @ISA $CONVERT/;

@ISA = qw/Exporter/;
@EXPORT = qw/orac_process_frame orac_store_frm_in_correct_grp /;

$VERSION = '0.10';

=head1 SUBROUTINES

The following subroutines are available:

=over 4


=item orac_store_frm_in_correct_grp

Stores the supplied frame into a Grp (usually specified in the Frame),
creating a new Group object if necessary. The Group objects are stored
in a hash (reference supplied) and, optionally, an array (unless undef).
This is so that Groups can be retrieved in the order in which they
were created. The GrpType specifies the type of Group that should be
created (eg ORAC::Group::UFTI, ORAC::Group::JCMT etc). The UT
is supplied purely so that the Group can be named (using the file_from_bits
method).

  orac_store_frm_in_correct_grp($Frm, $GrpType, \%Groups, \@Groups, $ut);
  orac_store_frm_in_correct_grp($Frm, $GrpType, \%Groups, undef, $ut);

The current Grp (ie the Group associated with the supplied Frm)
is returned.

=cut


sub orac_store_frm_in_correct_grp {

  croak 'Usage: orac_store_frm_in_correct_grp($Frm, $GrpType, $GrpHash, $GrpArr,$ut)'
    unless scalar(@_) == 5;

  # Variable declaration - Frossie loves this stuff :-)
  my ($use_arr, $Grp);

  # Read the argument list
  my ($Frm, $GrpObjectType, $GrpHash, $GrpArr, $ut) = @_;

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
  
  do {
    
    $Grp = new $GrpObjectType($grpname);
    $Grp->file($Grp->file_from_bits($ut, $Frm->number));
    unlink($Grp->file); # wont work since .sdf is not included
    $GrpHash->{$grpname} = $Grp;		# store group object
    orac_print ("A new group ".$Grp->file." has been created\n","blue");

    # Store the Grp on the array as well
    push(@$GrpArr, $Grp) if $use_arr;

  } unless (exists $GrpHash->{$grpname});

  # Retrieve the current group object
  $Grp = $GrpHash->{$grpname};

  # push current Frame onto Group
  $Grp->push($Frm);
  orac_print ("This observation is part of group ".$Grp->file."\n","blue");

  # Return the current Group
  return $GrpHash->{$grpname};

}


=item orac_process_frame

This is the core ORAC-DR pipeline processing routine.
It processes the supplied frame object that belongs to the group object,
using the supplied calibration object. The instrument name and default
recipe are required for recipe/primitive reading since recipes and
primitives are stored in instrument specific directories.

  orac_process_frame($Frm, $Grp, $Cal, $default_recipe, $instrument);


=cut


sub orac_process_frame {
  use strict;

  croak 'Usage: orac_process_frame($Frm, $Grp, $Cal, $OverRecipe, $instrument)'
    unless scalar(@_)  == 5;

  # Variable declaration
  my ($Recipe);

  # Read arguments
  my ($Frm, $Grp, $Cal, $OverRecipe, $instrument) = @_;

  # Store the header of the current frame in the calibration object
  $Cal->thing($Frm->header);

  #
  # at this point the recipe method should be queried if it hasn't
  # been explicitly set
  # Query frame for a recipe

  my $frmrecipe = $Frm->recipe;

  # KLUDGE: If recipe is not defined take the one specified on the command
  # Line. Else use the one instructed by the frame.
  # This needs to be changed such that we override all recipes except for
  # calibrators
  
  if (defined $OverRecipe) {
    $Recipe = $OverRecipe;
    orac_print "Using recipe $Recipe specified on command-line\n";
  } else {
    $Recipe = $frmrecipe;
    orac_print "Using recipe $Recipe read from header\n";
  };





  # Read in the selected recipe - note that this returns an array reference
  my $recipe_ref = orac_read_recipe($Recipe, $instrument);	# read recipe
  
  # In order to save time here we should not be 
  # passing an enormous array around (can contain hundereds of lines
  # of code). Instead pass around an array reference
  # Since we use a reference to a array we dont need to explicitly
  # return it either.
  while (grep /^\s*_/,@$recipe_ref) {	# while it contains other recipes
    $recipe_ref = orac_parse_recipe($recipe_ref, $instrument); # keep parsing recipes
  };

  # Now that the recipe is parsed, insert code for automatic error
  # checking, etc

  $recipe_ref = orac_add_code_to_recipe($recipe_ref);
  
  orac_execute_recipe($recipe_ref,$Frm,$Grp,$Cal); # execute parsed recipe

  # delete symlink to raw data file
  unlink($Frm->raw) if (-l $Frm->raw);


}

=back

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu) and 
Tim Jenness (t.jenness@jach.hawaii.edu)

=cut

1;
