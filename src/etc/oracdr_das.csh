#+
#  Name:
#     oracdr_das

#  Purpose:
#     Initialise ORAC-DR environment for use with JCMT DAS

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_das.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with JCMT DAS data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a JCMT
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
#        If no value is set, current directory is assumed unless
#        the script is running at the JAC, in which case the root
#        directory points to the location of the DAS archive.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/jcmt_das. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".


#  Examples:
#     oracdr_das
#        Will set the variables assuming the current UT date.
#     oracdr_das 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - $ORAC_DATA_OUT is set to the current working directory by default.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN may have to be
#     may have to be set manually after this command is issued.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.


#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2003/11/18 01:31:43  bradc
#     initial addition
#

#  Copyright:
#     Copyright (C) 1998-2003 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# Instrument
setenv ORAC_INSTRUMENT JCMT_DAS

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
