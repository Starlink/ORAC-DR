
#+
#  Name:
#     oracdr_wfcam4

#  Purpose:
#     Initialise ORAC-DR environment for use with the "fifth" WFCAM
#     chip.

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam4.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with WFCAM data.
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
#        is set to $ORAC_CAL_ROOT/wfcam. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_wfcam4
#        Will set the variables assuming the current UT date.
#     oracdr_wfcam4 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/wfcam5/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.
#     - this script is used when one of the four primary acquisition
#     machines is down and the hot spare (the fifth) is used.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.2  2006/11/15 20:00:35  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.1  2006/10/03 00:20:05  bradc
#     replaced with ex-SWFCAM version
#

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-
export ORAC_INSTRUMENT=WFCAM5

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh
