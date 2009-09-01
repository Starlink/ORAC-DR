#+
#  Name:
#     oracdr_ocgs4

#  Purpose:
#     Initialise ORAC-DR environment for use with CGS4 old style data

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_ocgs4.csh

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
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_ocgs4
#        Will set the variables assuming the current UT date.
#     oracdr_ocgs4 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/cgs4_data/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Paul Hirst (p.hirst@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.3  2006/11/15 20:00:41  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.2  2001/05/01 00:05:52  timj
#     Paul Hirst is now "in charge" of CGS4
#
#     Revision 1.1  2001/04/30 21:46:46  phirst
#     Support for old-stlye cgs4 data
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

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

setenv ORAC_INSTRUMENT OCGS4

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
