#+
#  Name:
#     oracdr_acsis

#  Purpose:
#     Initialise ORAC-DR environment for use with ACSIS

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_acsis.sh

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
#        defined it defaults to "$ORAC_DIR/../cal".

#  Examples:
#     oracdr_acsis
#        Will set the variables assuming the current UT date.
#     oracdr_acsis 20040919
#        Use UT data 20040919

#  Notes:
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN may have to be
#     may have to be set manually after this command is issued.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.


#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  Copyright:
#     Copyright (C) 1998-2004 Particle Physics and Astronomy Research
#     Council. 2009 Science and Technology Facilities Council.  All
#     Rights Reserved.

#-

# Instrument.
export ORAC_INSTRUMENT='ACSIS'

# Set the UT date.
oracut=`csh ${ORAC_DIR}/etc/oracdr_set_ut.csh $1`

# Find Perl.
starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Run initialization.
orac_env_setup=`$starperl ${ORAC_DIR}/etc/setup_oracdr_env.pl bash $oracut`
if test ! $?; then
  echo "**** ERROR IN setup_oracdr_env.pl ****"
  exit 255
fi
eval $orac_env_setup

oracdr_args="-ut $oracut -recsuffix SUMMIT"

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh
 
# Tidy up
unset oracut
unset oracdr_args
unset starperl
unset orac_env_setup
