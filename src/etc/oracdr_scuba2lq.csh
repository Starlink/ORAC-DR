
#+
#  Name:
#     oracdr_scuba2lq

#  Purpose:
#     Initialise ORAC-DR environment for use with the long-wave
#     SCUBA-2 arrays in QUICK-LOOK mode

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba2lq.csh

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
#     oracdr_scuba2lq
#        Will set the variables assuming the current UT date.
#     oracdr_scuba2lq 20081101
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
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     Andy Gibb (agg@astro.ubc.ca)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.2  2008/12/05 08:15:04  agg
#     Create output directory if at JCMT
#
#     Revision 1.1  2005/02/26 08:15:04  timj
#     Initial commit of scuba2 init script
#
#     Revision 1.3  2004/11/12 01:22:02  phirst
#      setenv RTD_REMOTE_DIR and HDS_MAP
#
#     Revision 1.2  2004/11/10 02:31:49  bradc
#     ORAC_DATA_CAL is in swfcam, not wfcam now
#
#     Revision 1.1  2004/09/14 21:17:37  bradc
#     initial addition for SWFCAM
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
#     21 Jan 2003 (jrl)
#        Original Version based on oracdr_wfcam.csh

#  Revision:
#     $Id: oracdr_scuba2l.csh 5923 2005-02-26 08:15:04Z timj $

#  Copyright:
#     Copyright (C) 1998-2005 Particle Physics and Astronomy Research
#     Council. Copyright (C) 2008 University of British Columbia. All
#     Rights Reserved.

#-

# ORAC data and calibration root locations
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /jcmtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jcmt_sw/oracdr_cal
endif

# Unset existing recipe & primitive directory definitions
if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif

if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif

# See if a UT date was given on the command line
if ($1 != "") then
    set oracut = $1
else
    set oracut = `\date -u +%Y%m%d`
endif

# QL-specific args - in QL the display is handled by oracdr_monitor
set oracdr_args = "-ut $oracut -loop task -recsuffix QL -nodisplay"

# Define instrument
setenv ORAC_INSTRUMENT SCUBA2_LONG

# Data directories
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/scuba2/ok/$oracut
setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/scuba2ql_long/$oracut

# Calibration directory
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/scuba2

# DRAMA task name - 1 subarray to begin with
setenv ORAC_REMOTE_TASK SC2DA8A@sc2da8a

# Check to see if we're at JCMT. If we are, then create the
# ORAC_DATA_OUT directory.
set jcmt = ''
if ($?SITE) then
  if ($SITE == 'jcmt') then
     set jcmt = $SITE
  endif
endif
if ( $jcmt != '' ) then
  if ( ! -d $ORAC_DATA_OUT ) then

    umask 002

    echo "CREATING OUTPUT DIRECTORY: $ORAC_DATA_OUT"

    mkdir $ORAC_DATA_OUT
   # Set the sticky bit for group write
   # Need to rsh to the NFS server of the partition of it is not local

    # check if ORAC_DATA_OUT is an NFS-mounted partition -

    set df_out = `df -t nfs $ORAC_DATA_OUT | wc -l`

    # if it is 1 that's just the df header, so we're local
    # if it is 3 we're NFS
    # if it is anything else, the df format is not what we thought it was

    if ($df_out == 1) then

      chmod g+rws $ORAC_DATA_OUT

    else if ($df_out > 1) then

      # get the name of the NFS host
      set nfs_host  = `df -t nfs $ORAC_DATA_OUT | head -2 | tail -1 | awk -F: '{print $1}'`
      # do the deed
      rsh $nfs_host chmod g+rws $ORAC_DATA_OUT
      # whinge to user
      echo '***************************************************'
      echo '* Your ORAC_DATA_OUT is not local to your machine  '
      echo '* If you intend to run ORAC-DR you should be       '
      echo "* using $nfs_host instead, which is where          "
      echo "* $ORAC_DATA_OUT is located *"
      echo '***************************************************'
    else

      echo Unable to establish whether $ORAC_DATA_OUT is local or remote
      echo Please report this error to the JAC software group

    endif
  endif
endif

# Misc things for printing to screen
setenv ORAC_PERSON agibb
setenv ORAC_LOOP flag
setenv ORAC_SUN  xxx

# some other things
setenv RTD_REMOTE_DIR $ORAC_DATA_OUT

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Set stripchart alias
alias xstripchart "xstripchart -cfg=$ORAC_DATA_CAL/jcmt_ql.ini &"

# Tidy up
unset oracut
unset oracdr_args

