#+
#  Name:
#     oracdr_scuba

#  Purpose:
#     Initialise ORAC-DR environment for use with SCUBA

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba.csh

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
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.


#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.10  2002/08/02 01:23:05  frossie
#     Change summit disk and machine locations
#     These really ought to be parametrised at the top!
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
setenv ORAC_INSTRUMENT SCUBA

# Cal Directories
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/scuba

# Data directories

# Input data root. Depends on location we are running from if
# ORAC_DATA_ROOT is not defined
if !($?ORAC_DATA_ROOT) then

  # ORAC_DATA_ROOT depends on our location
  # There are 3 possibilities. We are in Hilo, we are at the JCMT
  # or we are somewhere else. 

  # At the JCMT we need to set ORAC_DATA_ROOT to /jcmtarchive
  # In this case the current UT date is the sensible choice
 
  # In Hilo we need to set DATADIR to /scuba/Semester/UTdate/
  # In this case current UT is meaningless and an argument should be
  # used

  # Somewhere else - we have no idea where DATADIR should be
  # so we set data root to the current directory

  # Use domainname to work out where we are

  set orac_dname = `domainname`

  if ($orac_dname == 'JAC.jcmt') then

    setenv ORAC_DATA_ROOT /jcmtdata

  else if ($orac_dname == 'JAC.Hilo') then

    # Hilo is a bit more complicated since now we need to
    # find the semester name - this is done in an external
    # if to prevent issues with semester changes with a fixed
    # ORAC_DATA_ROOT
    setenv ORAC_DATA_ROOT /scuba

  else

    setenv ORAC_DATA_ROOT `pwd`

  endif

endif


# Note that for SCUBA at the JAC we use
# use /scuba/semester. If we were to set ORAC_DATA_ROOT
# to include the semester we would not be able to change semesters
# after running this script because ORAC_DATA_ROOT would change
# To overcome this I will do a check for /scuba and if $ORAC_DATA_ROOT
# is set to this value I will append the semester value

if ( $ORAC_DATA_ROOT == /scuba ) then

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
  if ( $oracmmdd > 201 && $oracmmdd < 802 ) then
    set orac_sem = "m${oracyy}a"
  else if ( $oracmmdd < 202 ) then
    set orac_sem = "m${oracprev_yy}b"
  else
   set orac_sem = "m${oracyy}b"
  endif

  unset oracyy
  unset oracprev_yy
  unset oracmmdd

  set orac_sem = ${orac_sem}/

else
 
  set orac_sem = ''

endif


# First start with input directory - $ORAC_DATA_ROOT is set up
# depending on location (domainname) if not set explicitly.

setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/scuba/$orac_sem$oracut/

# Output data directory is more problematic.
# If we are at JCMT set it to ORAC_DATA_ROOT/rodir/$oracut
# Else Set to current directory

if ($ORAC_DATA_ROOT == /jcmtdata ) then

 setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/scuba/$oracut

 # Check for the directory and create it
 if (! -d $ORAC_DATA_OUT) then
   echo "CREATING OUTPUT DIRECTORY: $ORAC_DATA_OUT"

   # Parent directory has sticky group bit set so this
   # guarantees correct group ownership
   mkdir $ORAC_DATA_OUT

   # Sticky bit set plus group write
   # The sticky bit can not be set on a nfs disk
   # so this does not work unless we are on mamo
   if (`hostname` != 'kolea') then
     echo Setting write permissions on directory by using rsh to mamo
     echo -n Please wait....
     ssh kolea chmod g+rws $ORAC_DATA_OUT
     echo complete.
   else
     # simply chmod
     chmod g+rws $ORAC_DATA_OUT
   endif

 endif

 # Change umask so that we will create files that are writable
 # by group
 umask 002

 # If we are not on mamo print a warning
 set orachost = `hostname`
 if ($orachost != 'kolea') then
   echo '***************************************************'
   echo '**** PLEASE USE KOLEA FOR ORAC-DR DATA REDUCTION ***'
   echo '***************************************************'
 endif

 # We are at the summit so we want to force -skip -loop wait
 set oracdr_args = "$oracdr_args -loop wait -skip"
 echo "Setting default oracdr argument list to $oracdr_args"

else 

  setenv ORAC_DATA_OUT  `pwd`

endif

# screen things
setenv ORAC_PERSON timj
setenv ORAC_LOOP 'wait -skip'
setenv ORAC_SUN  231

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Print additional warning if required
if ($?orachost) then 
   # csh does not short circuit so we cant combine the ifs
   if ($orachost != 'kolea') then
       echo '***************************************************'
       echo '**** PLEASE USE KOLEA FOR ORAC-DR DATA REDUCTION ***'
       echo '***************************************************'
   endif
endif



# Tidy up
unset oracut
unset oracdr_args
unset orac_sem
unset orac_dname
unset oracmm
unset oracdd
unset oracyy
if ($?orachost) unset orachost
