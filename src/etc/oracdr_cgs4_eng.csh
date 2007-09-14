#+
#  Name:
#     oracdr_cgs4

#  Purpose:
#     Initialise ORAC-DR environment for use with CGS4 engineering

#  Language:
#     C-shell script

#  Invocation:
#     source oracdr_cgs4_eng.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with CGS4 data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in 
#        a directory structure similar to that used at UKIRT.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, "/ukirtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/cgs4. If ORAC_CAL_ROOT is not
#        defined it defaults to "/ukirt_sw/oracdr_cal".


#  Examples:
#     oracdr_cgs4_eng
#        Will set the variables assuming the current UT date.
#     oracdr_cgs4_eng 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/eng/cgs4/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log: oracdr_cgs4.csh,v $
#     Revision 1.4  2002/04/02 03:04:51  mjc
#     Use \date command to override aliases.
#
#     Revision 1.3  2001/05/01 00:05:52  timj
#     Paul Hirst is now "in charge" of CGS4
#
#     Revision 1.2  2000/08/05 07:36:25  frossie
#     ORAC style
#
#     Revision 1.1  2000/05/02 02:24:28  frossie
#     Initial version
#
#     Revision 1.2  2000/02/03 03:43:38  timj
#     Correct doc typo
#
#     Revision 1.1  2000/02/03 02:50:45  timj
#     Starlink startup scripts
#
#     02 Jun 1999 (frossie)
#        Original Version

#  Revision:
#     $Id: oracdr_cgs4.csh,v 1.4 2002/04/02 03:04:51 mjc Exp $

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /ukirtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /ukirt_sw/oracdr_cal
endif

if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif

if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif


if ($1 != "") then
    set oracut = $1
else
    set oracut = `\date -u +%Y%m%d`
endif

set oracdr_args = "-ut $oracut"

setenv ORAC_INSTRUMENT CGS4
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/eng/cgs4/$oracut
setenv ORAC_DATA_OUT  $ORAC_DATA_ROOT/reduced/eng/cgs4/$oracut
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/cgs4

# screen things
setenv ORAC_PERSON phirst
setenv ORAC_LOOP flag
setenv ORAC_SUN  230

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset oracdr_args
