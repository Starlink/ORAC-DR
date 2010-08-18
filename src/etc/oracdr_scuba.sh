#+
#  Name:
#     oracdr_scuba

#  Purpose:
#     Initialise ORAC-DR environment for use with SCUBA

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with UFTI data.
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
#        If no value is set, current directory is assumed unless
#        the script is running at the JAC, in which case the root
#        directory points to the location of the SCUBA archive.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/ufti. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".


#  Examples:
#     oracdr_scuba
#        Will set the variables assuming the current UT date.
#     oracdr_cuba 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - $ORAC_DATA_OUT is set to the current working directory by default.
#     - At the JAC, the default input directory will be set depending
#     on whether the script is run from Hilo or the JCMT (assuming
#     $ORAC_DATA_ROOT is not set)
#     - If the script is not run from the JAC, and $ORAC_DATA_ROOT is
#     not set, the root of the input directory will be the directory
#     YYYYMMDD from the current working directory.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN may have to be
#     may have to be set manually after this command is issued.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.


#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.2  2006/09/07 00:35:24  bradc
#     fix for proper bash scripting
#
#     Revision 1.1  2006/09/06 02:30:02  bradc
#     initial addition
#
#     Revision 1.16  2004/01/09 02:04:50  frossie
#
#     If only all OSes had the -Posix option on df
#
#     Revision 1.15  2004/01/09 01:57:43  frossie
#
#     Modified to avoid any hard-coded machine names. Warning is issued on
#     NFS mounted ORAC_DATA_OUT regardless. Tested on Solaris and Linux only.
#
#     Revision 1.14  2002/10/11 21:09:07  timj
#     Tweak a mamo comment
#
#     Revision 1.13  2002/10/11 01:16:25  timj
#     SCUBA can now use -flag
#
#     Revision 1.12  2002/10/07 05:21:43  timj
#     Should hopefully work in Hilo
#
#     Revision 1.11  2002/08/02 03:25:01  frossie
#     Grr, what a mess. Added the 'dem' bit if we are at JCMT
#
#     Revision 1.8  2001/05/01 00:14:45  timj
#     Update semester determination so it works with 20010122
#
#     Revision 1.7  2000/08/08 21:40:08  timj
#     Realise that csh if's do not short circuit ($orachost)
#
#     Revision 1.6  2000/04/07 20:02:25  timj
#     Force -loop wait -skip at JCMT
#
#     Revision 1.5  2000/04/03 20:09:56  timj
#     Use rsh to mamo to set write permissions.
#     Add -skip to ORAC_LOOP
#
#     Revision 1.4  2000/03/23 22:48:03  timj
#     Set sticky bit and umask
#
#     Revision 1.3  2000/03/15 02:36:24  timj
#     Update for the summit
#
#     Revision 1.2  2000/02/03 08:13:16  timj
#     Replace /ukirt with /jcmt
#
#     Revision 1.1  2000/02/03 04:53:23  timj
#     First version
#

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# Instrument
export ORAC_INSTRUMENT=SCUBA

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh
