
#+
#  Name:
#     oracdr_scuba2_850_ql

#  Purpose:
#     Initialise ORAC-DR environment for use with the long-wave
#     SCUBA-2 arrays in QUICK-LOOK mode

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba2_850_ql.csh

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
#     oracdr_scuba2_850_ql
#        Will set the variables assuming the current UT date.
#     oracdr_scuba2_850_ql 20081101
#        Use UT date 20081101.

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#       are UNSET by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#       (for input) and "reduced" (for output) from root
#       $ORAC_DATA_ROOT/scuba2/sx/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#       set manually if the JAC directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#       this routine.

#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Andy Gibb (agg@astro.ubc.ca)
#     {enter_new_authors_here}

#  History:
#     2011-03-18 (TIMJ):
#        Do not run qlgather

#  Copyright:
#     Copyright (C) 2008-2011 Science and Technology Facilties Council.
#     Copyright (C) 2008 University of British Columbia. All
#     Rights Reserved.

#-

# Define instrument
setenv ORAC_INSTRUMENT SCUBA2_850

# Source general alias file and print welcome screen
set oracdr_setup_args="--drmode=QL"
source $ORAC_DIR/etc/oracdr_start.csh

# Set stripchart alias
if ( $?ORAC_DATA_CAL ) then
  alias xstripchart "xstripchart -cfg=$ORAC_DATA_CAL/jcmt_ql.ini &"
endif

# qlgather alias
alias qlgather "$STARLINK_DIR/Perl/bin/perl $ORAC_DIR/bin/qlgather"

echo " Use 'xstripchart' to monitor pipeline output time series data"
echo
echo " To run QL processing the QL data gatherer must be run up."
echo " Make sure that DRAMA networking tasks are running and then:"
echo
echo "    qlgather &"
echo "    oracdr &"
echo
echo " ORAC_REMOTE_TASK can be set to monitor specific tasks but"
echo " this is not necessary by default."
echo

