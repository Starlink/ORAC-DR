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
#     $Log$
#     Revision 1.9  2006/11/06 21:04:31  bradc
#     more syntax fixes
#
#     Revision 1.8  2006/11/06 20:59:58  bradc
#     more syntax fixes
#
#     Revision 1.7  2006/11/06 20:50:53  bradc
#     fix syntax
#
#     Revision 1.6  2006/11/06 20:44:45  bradc
#     use alternate method for determining if we are at JCMT or not
#
#     Revision 1.5  2006/11/02 01:45:28  bradc
#     fix syntax error
#
#     Revision 1.4  2006/11/02 01:40:27  bradc
#     create $ORAC_DATA_OUT if at JCMT and if does not exist
#
#     Revision 1.3  2006/10/30 21:25:17  bradc
#     move ORAC_DATA_IN
#
#     Revision 1.2  2006/10/27 00:28:35  bradc
#     fix ORAC_SUN definition
#
#     Revision 1.1  2004/06/07 20:40:39  bradc
#     initial addition for ACSIS
#
#
 
#  Revision:
#     $Id$
 
#  Copyright:
#     Copyright (C) 1998-2004 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.
 
#-
 
# Calibration root
if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jcmt_sw/oracdr_cal
endif
 
# Recipe dir
if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif
 
# primitive dir
if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif
 
#  Read the input UT date
if ($1 != "") then
    set oracut = $1
else
    set oracut = `date -u +%Y%m%d`
endif
 
set oracdr_args = "-ut $oracut"
 
# Instrument
setenv ORAC_INSTRUMENT ACSIS

# Cal Directories
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/acsis
 
# Data directories
setenv ORAC_DATA_ROOT /jcmtdata
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/acsis/acsis00/$oracut
setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/acsis/$oracut/

# Check to see if we're at JCMT. If we are, then create the
# ORAC_DATA_OUT directory.
set jcmt = `/sbin/ip addr show to 128.171.92/24 | awk -F: '{print $1}' | awk '{print $2}'`
if ( $jcmt != '' ) then
  if ( ! -d $ORAC_DATA_OUT ) then
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

# screen things
setenv ORAC_PERSON bradc
setenv ORAC_LOOP 'flag'
setenv ORAC_SUN XXX
 
# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
 
# Tidy up
unset oracut
unset oracdr_args
unset orachost
