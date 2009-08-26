#+
#  Name:
#     oracdr_acsis

#  Purpose:
#     Initialise ORAC-DR environment for use with ACSIS

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_acsis.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with ACSIS data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes an ACSIS
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in
#        a directory structure similar to that used at JCMT for ACSIS.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, current directory is assumed unless
#        the script is running at the JAC, in which case the root
#        directory points to the location of the ACSIS archive.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/acsis. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".

#  Examples:
#     oracdr_acsis
#        Will set the variables assuming the current UT date.
#     oracdr_acsis 20040919
#        Use UT data 20040919

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
#     07-JUN-2004 (BRADC):
#        Initial import
#     27-OCT-2006 (BRADC):
#        fix ORAC_SUN definition
#     30-OCT-2006 (BRADC):
#        move ORAC_DATA_IN
#     02-NOV-2006 (BRADC):
#        create $ORAC_DATA_OUT if at JCMT and if does not exist
#     06-NOV-2006 (BRADC):
#        - use alternate method for determining if we are at JCMT or not
#        - fix syntax errors
#     09-NOV-2006 (BRADC):
#        set umask to 2 before creating ORAC_DATA_OUT
#     20-DEC-2006 (BRADC):
#        set ORAC_DATA_IN to spectra directory
#     04-MAY-2007 (TIMJ):
#        Use of /sbin/ip is non-portable
 
#  Revision:
#     $Id$
 
#  Copyright:
#     Copyright (C) 1998-2004,2006 Particle Physics and Astronomy Research
#     Council. Copyright (C) 2007 Science and Technology Facilities
#     Council. All Rights Reserved.
 
#-

setenv ORAC_INSTRUMENT ACSIS

# Set the UT date.
set oracut=`${ORAC_DIR}/etc/oracdr_set_ut.csh $1`

# Find Perl.
set starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Run initialization.
set orac_env_setup=`$starperl ${ORAC_DIR}/etc/setup_oracdr_env.pl csh $oracut`
if ( $? != 0 ) then
  echo "**** ERROR IN setup_oracdr_env.pl ****"
  exit 255
endif
eval $orac_env_setup

set oracdr_args = "-ut $oracut"

# Run oracdr_start.
source $ORAC_DIR/etc/oracdr_start.csh

unset oracdr_args
unset oracut
unset starperl
unset orac_env_setup
