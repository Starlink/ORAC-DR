
#+
#  Name:
#     oracdr_wfcam3_eng

#  Purpose:
#     Initialise ORAC-DR environment for use with the third WFCAM
#     chip when run in engineering mode.

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam3_eng.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with WFCAM data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration when WFCAM is run in engineering
#     mode.

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
#        defined it defaults to "/ukirt_sw/oracdr/cal".


#  Examples:
#     oracdr_wfcam3_eng
#        Will set the variables assuming the current UT date.
#     oracdr_wfcam3_eng 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw/eng"
#     (for input) and "reduced/eng" (for output) from root
#     $ORAC_DATA_ROOT/wfcam3/UT
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
#     $Log$
#     Revision 1.11  2006/11/15 20:18:16  bradc
#     set PERL5LIB to point to ukirt_sw for CIRDR stuff
#
#     Revision 1.10  2006/11/15 20:00:46  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.9  2006/10/28 01:37:40  bradc
#     set PERL5LIB for CASU code
#
#     Revision 1.8  2006/10/23 18:59:39  bradc
#     set RTD_REMOTE_DIR back to be the same as ORAC_DATA_OUT
#
#     Revision 1.7  2006/10/03 00:20:06  bradc
#     replaced with ex-SWFCAM version
#
#     Revision 1.4  2006/07/21 02:09:08  bradc
#     set RTD_REMOTE_DIR to $ORAC_DATA_OUT/.., create ORAC_DATA_OUT directory if it does not exist and we are being run on a wfdr machine
#
#     Revision 1.3  2004/11/12 01:22:02  phirst
#      setenv RTD_REMOTE_DIR and HDS_MAP
#
#     Revision 1.2  2004/11/10 02:31:49  bradc
#     ORAC_DATA_CAL is in wfcam, not wfcam now
#
#     Revision 1.1  2004/09/14 21:17:37  bradc
#     initial addition for WFCAM
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
#     $Id: oracdr_wfcam3.csh 6911 2007-05-02 18:45:10Z bradc $

#  Copyright:
#     Copyright (C) 1998-2006 Particle Physics and Astronomy Research
#     Council. Copyright (C) 2007 Science and Techology Facilities
#     Council.  All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /ukirtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /ukirt_sw/oracdr/cal
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

setenv ORAC_INSTRUMENT WFCAM3
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/eng/wfcam3/$oracut
setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/eng/wfcam3/$oracut
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/wfcam

# screen things
setenv ORAC_PERSON bradc
setenv ORAC_LOOP flag
setenv ORAC_SUN

# some other things
setenv HDS_MAP 0
setenv RTD_REMOTE_DIR $ORAC_DATA_OUT/..

# Determine the host, and if we're on a wfdr machine, create
# $ORAC_DATA_OUT if it doesn't already exist.
set hostname = `/bin/hostname`
if( $hostname == "wfdr1" || $hostname == "wfdr2" || $hostname == "wfdr3" || $hostname == "wfdr4" ) then
    if( ! -d ${ORAC_DATA_OUT} ) then
        mkdir $ORAC_DATA_OUT
    endif
endif

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Needed for CASU code.
setenv PERL5LIB /ukirt_sw/cirdr/perlinstall:/ukirt_sw/cirdr/perllib

# Tidy up
unset oracut
unset oracdr_args

