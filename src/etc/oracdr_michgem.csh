#+
#  Name:
#     oracdr_michelle

#  Purpose:
#     Initialise ORAC-DR environment for use with Michelle on Gemini.

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_michgem.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with Michelle data.
#     An optional argument is the UT date.  This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        The UT date of interest.  This should be in YYYYMMDD format.
#        It is used to set the location of the input and output data
#        directories.  This assumes that the data are located in a
#        directory structure similar to that used at UKIRT.  The UT date
#        also sets an appropriate alias for ORAC-DR itself.  If no value
#        is specified, the current UT date is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given & Returned)
#        The root location of the data input and output directories.
#        If no value is set, $ORAC_DATA_ROOT is set to "/ukirtdata".
#     $ORAC_CAL_ROOT = Environment Variable (Given & Returned)
#        The root location of the calibration files.  $ORAC_DATA_CAL is
#        derived from this variable by adding the appropriate value of
#        $ORAC_INSTRUMENT.  In this case $ORAC_DATA_CAL is set to
#        $ORAC_CAL_ROOT/michelle.  If ORAC_CAL_ROOT is not defined
#        defined it defaults to "/jac_sw/oracdr_cal".

#  Examples:
#     oracdr_michgem
#        Will set the variables assuming the current UT date.
#     oracdr_michgem 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables ORAC_RECIPE_DIR and ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be:
#     $ORAC_DATA_ROOT/raw/michelle/<UT> for the "raw" data, and
#     $ORAC_DATA_ROOT/reduced/michelle/<UT> for the "reduced" data.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     MJC: Malcolm J. Currie (mjc@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     2004 October 5 (BRADC):
#        Original version based upon Michelle equivalent.
#     2001 March 3 (MJC):
#        Original version based upon CGS4 equivalent.
#     2001 November 27 (MJC):
#        SUN number from reassigned 234 to 2132,236.  Added comments.

#  Copyright:
#     Copyright (C) 1998-2004 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# ORAC things.
# ===========

# Define root directories of data and calibration source.
    if !( $?ORAC_DATA_ROOT ) then
       setenv ORAC_DATA_ROOT /ukirtdata
    endif

    if !( $?ORAC_CAL_ROOT ) then
       setenv ORAC_CAL_ROOT /jac_sw/oracdr_cal
    endif

# Remove private source directories from code search paths.
    if ( $?ORAC_RECIPE_DIR ) then
       echo "Warning: resetting ORAC_RECIPE_DIR"
       unsetenv ORAC_RECIPE_DIR
    endif

    if ( $?ORAC_PRIMITIVE_DIR ) then
       echo "Warning: resetting ORAC_PRIMITIVE_DIR"
       unsetenv ORAC_PRIMITIVE_DIR
    endif

# Set the UT date.
    if ($1 != "") then
       set oracut = $1
    else
       set oracut = `\date -u +%Y%m%d`
    endif

    set oracdr_args = "-ut $oracut"

# Define input and output data, and calibration directories.
    setenv ORAC_INSTRUMENT MICHGEM
    setenv ORAC_DATA_IN  $ORAC_DATA_ROOT/raw/michelle/$oracut
    setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/michelle/$oracut
    setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/michelle

# Define screen environment variables.
    setenv ORAC_PERSON bradc
    setenv ORAC_LOOP flag
    setenv ORAC_SUN  232,236

# Source general alias file and print welcome screen.
    source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up.
    unset oracut
    unset oracdr_args
