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

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-
export OS=`uname -s`

if ($OS == 'SunOS'); then
df () { /usr/ucb/df ${1+"$@"}; }
fi


# Calibration root
if !("$ORAC_CAL_ROOT" != ""); then
    export ORAC_CAL_ROOT=/jcmt_sw/oracdr_cal
fi

# Recipe dir
if ("$ORAC_RECIPE_DIR" != ""); then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
fi

# primitive dir
if ("$ORAC_PRIMITIVE_DIR" != ""); then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
fi

#  Read the input UT date
if ($1 != ""); then
    set oracut = $1
else
    set oracut = `date -u +%Y%m%d`
fi

set oracdr_args = "-ut $oracut"

# Instrument
export ORAC_INSTRUMENT=SCUBA

# Cal Directories
export ORAC_DATA_CAL=$ORAC_CAL_ROOT/scuba

# Data directories

# Input data root. Depends on location we are running from if
# ORAC_DATA_ROOT is not defined
if !("$ORAC_DATA_ROOT" != ""); then

  # ORAC_DATA_ROOT depends on our location
  # There are 3 possibilities. We are in Hilo, we are at the JCMT
  # or we are somewhere else. 

  # At the JCMT we need to set ORAC_DATA_ROOT to /jcmtdata
  # In this case the current UT date is the sensible choice
 
  # In Hilo we need to set DATADIR to /scuba/Semester/UTdate/
  # In this case current UT is meaningless and an argument should be
  # used

  # Somewhere else - we have no idea where DATADIR should be
  # so we set data root to the current directory

  # Use domainname to work out where we are

  set orac_dname = `domainname`

  if ($orac_dname == 'JAC.jcmt'); then

    export ORAC_DATA_ROOT=/jcmtdata

  elif ($orac_dname == 'JAC.Hilo') then

    # Hilo is a bit more complicated since now we need to
    # find the semester name - this is done in an external
    # if to prevent issues with semester changes with a fixed
    # ORAC_DATA_ROOT
    export ORAC_DATA_ROOT=/scuba

  else

    export ORAC_DATA_ROOT=`pwd`

  fi

fi


# Note that for SCUBA at the JAC we use
# use /scuba/semester. If we were to set ORAC_DATA_ROOT
# to include the semester we would not be able to change semesters
# after running this script because ORAC_DATA_ROOT would change
# To overcome this I will do a check for /scuba and if $ORAC_DATA_ROOT
# is set to this value I will append the semester value

if ( $ORAC_DATA_ROOT == /scuba ); then

  # Hilo is a bit more complicated since now we need to
  # find the semester name

  # Start by splitting the YYYYMMDD string into bits
  set oracyy = `echo $oracut | cut -c3-4`
  set oracprev_yy = `expr $oracut - 10000 | cut -c3-4`
  set oracmmdd = `echo $oracut | cut -c5-8`

  # Need to put the month in the correct semester
  # Note that 199?0201 is in the previous semester
  # Same for 199?0801
  # The semester changes on UT Feb 2 and Aug 2:
  if ( $oracmmdd > 201 && $oracmmdd < 802 ); then
    set orac_sem = "m${oracyy}a"
  elif ( $oracmmdd < 202 ) then
    set orac_sem = "m${oracprev_yy}b"
  else
   set orac_sem = "m${oracyy}b"
  fi

  unset oracyy
  unset oracprev_yy
  unset oracmmdd

  set orac_sem = ${orac_sem}/
  set dem =''
else
 
  set orac_sem = ''
  set dem = "/dem"
fi

# Input data directory depends on location
if ($ORAC_DATA_ROOT == /jcmtdata ); then
    
    export ORAC_DATA_IN=$ORAC_DATA_ROOT/raw/scuba/$orac_sem$oracut$dem/

elif ($ORAC_DATA_ROOT == /scuba ) then

    export ORAC_DATA_IN=$ORAC_DATA_ROOT/$orac_sem$oracut

else

    export ORAC_DATA_IN=$ORAC_DATA_ROOT/raw/scuba/$oracut

fi

# Output data directory is more problematic.
# If we are at JCMT set it to ORAC_DATA_ROOT/rodir/$oracut
# Else Set to current directory

if ($ORAC_DATA_ROOT == /jcmtdata ); then

 export ORAC_DATA_OUT=$ORAC_DATA_ROOT/reduced/scuba/$oracut

 # Check for the directory and create it
 if (! -d $ORAC_DATA_OUT); then
   echo "CREATING OUTPUT DIRECTORY: $ORAC_DATA_OUT"

   # Parent directory has sticky group bit set so this
   # guarantees correct group ownership
   mkdir $ORAC_DATA_OUT

   # Set the sticky bit for group write 
   # Need to rsh to the NFS server of the partition of it is not local

    # check if ORAC_DATA_OUT is an NFS-mounted partition - 

    set df_out = `df -t nfs $ORAC_DATA_OUT | wc -l`

    # if it is 1 that's just the df header, so we're local
    # if it is 3 we're NFS
    # if it is anything else, the df format is not what we thought it was

    if ($df_out == 1); then

	chmod g+rws $ORAC_DATA_OUT

    elif ($df_out > 1) then

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

    fi

 fi

 # Change umask so that we will create files that are writable
 # by group
 umask 002

 # We are at the summit so we want to force -skip -loop flag
 set oracdr_args = "$oracdr_args -loop flag -skip"
 echo "Setting default oracdr argument list to $oracdr_args"

else 

  export ORAC_DATA_OUT=`pwd`

fi

# screen things
export ORAC_PERSON=timj
export ORAC_LOOP='flag -skip'
export ORAC_SUN=231

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh


# warn again

set df_out = `df -t nfs $ORAC_DATA_OUT | wc -l`

if ($df_out > 1); then

	# get the name of the NFS host
	set nfs_host  = `df -t nfs $ORAC_DATA_OUT | head -2 | tail -1 | awk -F: '{print $1}'`
	# do the deed
	rsh $nfs_host chmod g+rws $ORAC_DATA_OUT
	# whinge to user
	echo '***************************************************'
	echo '*  Your ORAC_DATA_OUT is not local to your machine  '
	echo '*  If you intend to run ORAC-DR you should be       '
	echo "*  using $nfs_host instead, which is where          "
	echo "*  $ORAC_DATA_OUT is located "
	echo '***************************************************'
fi




# Tidy up
unset oracut
unset oracdr_args
unset orac_sem
unset orac_dname
unset oracmm
unset oracdd
unset oracyy
unset nfs_host
unset df_out
