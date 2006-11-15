
#+
#  Name:
#     oracdr_curve

#  Purpose:
#     Initialise ORAC-DR environment for use with the UKIRT wavefront sensor

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_curve.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with the UKIRT wavefront
#     sensor data. An optional argument is the UT date. This is used to 
#     configure the input and output data directories but assumes a UKIRT
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
#        Root location of the calibration files. Not relevant
#        for the wavefront sensor.

#  Examples:
#     oracdr_ufti
#        Will set the variables assuming the current UT date.
#     oracdr_ufti 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/ufti_data/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Nick Rees (npr@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.3  2006/11/15 20:00:36  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.2  2001/03/17 00:02:30  timj
#     Make sure that curve uses a private disp.dat rather than the version from ORAC_DATA_CAL
#
#     Revision 1.1  2000/12/18 21:57:36  npr
#     Original version of oracdr_curve.csh, based on oracdr_ufti.csh
#


#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /ukirtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jac_sw/oracdr_cal
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
    set oracut = `date -u +%Y%m%d`
endif

set oracdr_args = "-ut $oracut"

setenv ORAC_INSTRUMENT UFTI
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/curve/$oracut/
setenv ORAC_DATA_OUT  $ORAC_DATA_ROOT/reduced/curve/$oracut/
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/ufti

# screen things
setenv ORAC_PERSON mjc
setenv ORAC_LOOP flag
setenv ORAC_SUN  232

if ( ! -f ${ORAC_DATA_OUT}/disp.dat ) then
    echo "NUM TYPE=image TOOL=gaia REGION=1 WINDOW=1 AUTOSCALE=1" > ${ORAC_DATA_OUT}/disp.dat
endif

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset oracdr_args
