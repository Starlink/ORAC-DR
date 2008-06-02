
#+
#  Name:
#     oracdr_swfcam1

#  Purpose:
#     Initialise ORAC-DR environment for use with the short-wave
#     SCUBA-2 arrays

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba2s.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with SCUBA-2 data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a JAC
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
#        If no value is set, "/jcmtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/scuba2. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".


#  Examples:
#     oracdr_scuba2l
#        Will set the variables assuming the current UT date.
#     oracdr_scuba2l 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/scuba2/sx/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the JAC directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2005/02/26 08:15:04  timj
#     Initial commit of scuba2 init script
#
#     Revision 1.3  2004/11/12 01:22:02  phirst
#      setenv RTD_REMOTE_DIR and HDS_MAP
#
#     Revision 1.2  2004/11/10 02:31:49  bradc
#     ORAC_DATA_CAL is in swfcam, not wfcam now
#
#     Revision 1.1  2004/09/14 21:17:37  bradc
#     initial addition for SWFCAM
#
#     Revision 1.2  2004/05/05 11:38:57  jrl
#     Modified to add ORAC_DATA_CASU definition and a small tidy
#
#     Revision 1.1  2003/06/30 09:43:05  jrl
#     initial entry into CVS
#
#     Revision 1.1  2003/01/22 11:54:49  jrl
#     Initial Entry
#
#
#     21 Jan 2003 (jrl)
#        Original Version based on oracdr_wfcam.csh

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2005 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /jcmtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jcmt_sw/oracdr_cal
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

setenv ORAC_INSTRUMENT SCUBA2_SHORT
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/scuba2/ok/$oracut
setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/scuba2_short/$oracut
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/scuba2

# screen things
setenv ORAC_PERSON agibb
setenv ORAC_LOOP flag
setenv ORAC_SUN  xxx

# some other things
setenv RTD_REMOTE_DIR $ORAC_DATA_OUT

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Set stripchart alias
alias xstripchart "xstripchart -cfg=$ORAC_DATA_CAL/jcmt_short.ini &"

# Tidy up
unset oracut
unset oracdr_args

