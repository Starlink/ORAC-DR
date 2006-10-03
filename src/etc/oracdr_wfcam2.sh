
#+
#  Name:
#     oracdr_wfcam2

#  Purpose:
#     Initialise ORAC-DR environment for use with the second WFCAM
#     chip.

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam2.sh

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
#        defined it defaults to "/ukirt_sw/oracdr_cal".


#  Examples:
#     oracdr_wfcam2
#        Will set the variables assuming the current UT date.
#     oracdr_wfcam2 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/wfcam2/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2006/10/03 00:20:02  bradc
#     replaced with ex-SWFCAM version
#
#     Revision 1.2  2006/09/07 00:35:27  bradc
#     fix for proper bash scripting
#
#     Revision 1.1  2006/09/06 02:30:15  bradc
#     initial addition
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
#        Original Version based on oracdr_wfcam.sh

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if test -z "$ORAC_DATA_ROOT"; then
    export ORAC_DATA_ROOT=/ukirtdata
fi

if test -z "$ORAC_CAL_ROOT"; then
    export ORAC_CAL_ROOT=/ukirt_sw/oracdr_cal
fi

if ! test -z "$ORAC_RECIPE_DIR"; then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unset ORAC_RECIPE_DIR
fi

if ! test -z "$ORAC_PRIMITIVE_DIR"; then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unset ORAC_PRIMITIVE_DIR
fi


if test ! -z "$1"; then
    oracut=$1
else
    oracut=`\date -u +%Y%m%d`
fi

export oracdr_args="-ut $oracut"

export ORAC_INSTRUMENT=WFCAM2
export ORAC_DATA_IN=$ORAC_DATA_ROOT/raw/wfcam2/$oracut
export ORAC_DATA_OUT=$ORAC_DATA_ROOT/reduced/wfcam2/$oracut
export ORAC_DATA_CAL=$ORAC_CAL_ROOT/wfcam

# some other things
export HDS_MAP=0
export RTD_REMOTE_DIR=$ORAC_DATA_OUT/..

# Determine the host, and if we're on a wfdr machine, create
# $ORAC_DATA_OUT if it doesn't already exist.
hostname=`/bin/hostname`
if( $hostname == "wfdr1" || $hostname == "wfdr2" || $hostname == "wfdr3" || $hostname == "wfdr4" ); then
    if( ! -d ${ORAC_DATA_OUT} ); then
        mkdir $ORAC_DATA_OUT
    fi
fi

# screen things
export ORAC_PERSON=bradc
export ORAC_LOOP=flag
export ORAC_SUN

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh

# Tidy up
unset oracut
unset oracdr_args

