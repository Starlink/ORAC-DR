# !/bin/csh
#+
#  Name:
#     nongeneric_imaging.csh

#  Purpose:
#     Creates the non-generic, deprecated ORAC-DR imaging recipes.

#  Language:
#     Unix C-shell

#  Invocation:
#     nongeneric_imaging.csh

#  Description:
#     This script creates within directory $ORAC_DIR/recipes/imaging
#     the now deprecated imaging recipes with a specified number of
#     jitter positions in their names, i.e. the non-generic recipes.
#     It uses sed applied to the current generic versions to make the
#     jitter-specific versions.  The NUMBER argument is appended to
#     the <recipe>_HELLO_ invocation.
#
#     Existing non-generic recipes are first removed.

#  Output:
#     The following recipes in $ORAC_DIR/recipes/imaging:
#       CHOP_SKY_JITTER9, CHOP_SKY_JITTER9_BASIC, JITTER[359]_SELF_FLAT,
#       JITTER5_SELF_FLAT_APHOT, JITTER[59]_SELF_FLAT_BASIC,
#       JITTER5_SELF_FLAT_NCOLOUR, JITTER[59]_SELF_FLAT_NO_MASK,
#       JITTER9_SELF_FLAT_TELE, MOVING_JITTER9_SELF_FLAT,
#       MOVING_JITTER9_SELF_FLAT_BASIC, NOD[48]_SELF_FLAT_NO_MASK,
#       NOD[48]_SELF_FLAT_NO_MASK_APHOT POL_JITTER3 SKY_AND_JITTER5,
#       and SKY_AND_JITTER5_APHOT.

#  Prior Requirements:
#     -  Environment variable ORAC_DIR must be defined.

#  Authors:
#     MJC: Malcolm J. Currie (JAC)
#     {enter_new_authors_here}

#  History:
#     2001 December 7 (MJC):
#        Original version.
#     {enter_further_changes_here}

#-

# Obtain the argument values.

if ( "$ORAC_DIR" == "" ) then
   echo "\$ORAC_DIR is undefined.  The non-generic recipes are not created."
   exit
endif

# Store the current directory, and move to the imaging-recipe directory.
onintr tidy
set current = `pwd`
cd $ORAC_DIR/recipes/imaging

# Remove earlier versions of old non-generic recipes.
\rm CHOP_SKY_JITTER9 CHOP_SKY_JITTER9_BASIC JITTER[359]_SELF_FLAT
\rm JITTER5_SELF_FLAT_APHOT JITTER[59]_SELF_FLAT_BASIC JITTER5_SELF_FLAT_NCOLOUR
\rm JITTER[59]_SELF_FLAT_NO_MASK JITTER9_SELF_FLAT_TELE MOVING_JITTER9_SELF_FLAT
\rm MOVING_JITTER9_SELF_FLAT_BASIC NOD[48]_SELF_FLAT_NO_MASK
\rm NOD[48]_SELF_FLAT_NO_MASK_APHOT POL_JITTER3 SKY_AND_JITTER5 SKY_AND_JITTER5_APHOT

# Make non-generic recipes derived from the latest recipes.
sed -e '/^ *_/s/CHOP_SKY_HELLO_/CHOP_SKY_HELLO_ NUMBER=9/' CHOP_SKY_JITTER >                          CHOP_SKY_JITTER9
sed -e '/^ *_/s/CHOP_SKY_HELLO_/CHOP_SKY_HELLO_ NUMBER=9/' CHOP_SKY_JITTER_BASIC >                    CHOP_SKY_JITTER9_BASIC
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=3/' JITTER_SELF_FLAT >         JITTER3_SELF_FLAT
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=5/' JITTER_SELF_FLAT >         JITTER5_SELF_FLAT
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=5/' JITTER_SELF_FLAT_APHOT >   JITTER5_SELF_FLAT_APHOT
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=5/' JITTER_SELF_FLAT_BASIC >   JITTER5_SELF_FLAT_BASIC
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=5/' JITTER_SELF_FLAT_NCOLOUR > JITTER5_SELF_FLAT_NCOLOUR
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=5/' JITTER_SELF_FLAT_NO_MASK > JITTER5_SELF_FLAT_NO_MASK
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' JITTER_SELF_FLAT >         JITTER9_SELF_FLAT
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' JITTER_SELF_FLAT_BASIC >   JITTER9_SELF_FLAT_BASIC
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' JITTER_SELF_FLAT_NO_MASK > JITTER9_SELF_FLAT_NO_MASK
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' JITTER_SELF_FLAT_TELE >    JITTER9_SELF_FLAT_TELE
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' MOVING_JITTER_SELF_FLAT >  MOVING_JITTER9_SELF_FLAT
sed -e '/^ *_/s/JITTER_SELF_FLAT_HELLO_/JITTER_SELF_FLAT_HELLO_ NUMBER=9/' MOVING_JITTER_SELF_FLAT_BASIC > MOVING_JITTER9_SELF_FLAT_BASIC
sed -e '/^ *_/s/NOD_SELF_FLAT_HELLO_/NOD_SELF_FLAT_HELLO_ NUMBER=4/' NOD_SELF_FLAT_NO_MASK >          NOD4_SELF_FLAT_NO_MASK
sed -e '/^ *_/s/NOD_SELF_FLAT_HELLO_/NOD_SELF_FLAT_HELLO_ NUMBER=4/' NOD_SELF_FLAT_NO_MASK_APHOT >    NOD4_SELF_FLAT_NO_MASK_APHOT
sed -e '/^ *_/s/NOD_SELF_FLAT_HELLO_/NOD_SELF_FLAT_HELLO_ NUMBER=8/' NOD_SELF_FLAT_NO_MASK >          NOD8_SELF_FLAT_NO_MASK
sed -e '/^ *_/s/NOD_SELF_FLAT_HELLO_/NOD_SELF_FLAT_HELLO_ NUMBER=8/' NOD_SELF_FLAT_NO_MASK_APHOT >    NOD8_SELF_FLAT_NO_MASK_APHOT
sed -e '/^ *_/s/POL_JITTER_HELLO_/POL_JITTER_HELLO_ NUMBER=3/' POL_JITTER >                           POL_JITTER3
sed -e '/^ *_/s/SKY_AND_JITTER_HELLO_/SKY_AND_JITTER_HELLO_ NUMBER=5/' SKY_AND_JITTER >               SKY_AND_JITTER5
sed -e '/^ *_/s/SKY_AND_JITTER_HELLO_/SKY_AND_JITTER_HELLO_ NUMBER=5/' SKY_AND_JITTER_APHOT >         SKY_AND_JITTER5_APHOT

tidy:

# Restore the original directory.
cd $current
exit
