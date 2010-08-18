#!/bin/csh

#+
#  Name:
#     spex2oracdr.csh

#  Purpose:
#     Converts SPEX raw data into a UKIRT-like named
#     files for use in ORAC-DR.

#  Language:
#     Unix C-shell

#  Invocation:
#     spex2oracdr.csh

#  Description:
#     This script processes all the BD*.FITS files in the current
#     working directory each forming an NDF suitable for use by the
#     ORAC-DR imaging pipeline.
#
#     The NDFs are named spex<date>_<observation_number>.  The UT
#     date is determined from the headers, and is in the numerical
#     format yyyyddmm.  Observations which span UT midnight take the
#     UT date of the first observation of that night available.  The
#     observation numbers come from the order in which they are
#     processed.  They are a 5-digit integer with leading zeroes
#     counting from 1.  To avoid name clashes each night's data
#     must be in its own directory.
#
#     Three FITS headers are written in each NDF: the observation number
#     in OBSNUM, the group number in GRPNUM, and the number of offsets
#     (number of group members plus one) in NOFFSETS.  The group number
#     is equated to the observation number when any of four main headers:
#     object name, filter, exposure time, reasdout limits---changes value.
#     The group number is unchanged until the next group is located.
#
#     The script reports the input FITS file as it is processed, and its
#     date and time.  It also reports the creation of each NDF and
#     each new group.

#  Notes:
#     The FITS to NDF conversion uses the default parameter values.

#  Tasks:
#     KAPPA: FITSMOD, NDFCOPY; CONVERT: FITS2NDF.

#  Deficiencies:
#     Doesn't use the time of observation to order the sequence numbers.

#  Authors:
#     MJC: Malcolm J. Currie (Starlink)
#     {enter_new_authors_here}

#  History:
#     2005 February 24 (MJC):
#        Original version.
#     {enter_further_changes_here}

#-

#  Interruption causes exit.
    onintr EXIT

# Define KAPPA and CONVERT commands, but hide reports from view.
    alias echo 'echo >/dev/null'
    convert
    kappa
    unalias echo

# Initialise variables.
    set prefix = "spex"
    set obsnum = 1
    set grpnum = 1
    set first = 1
    set c_object = "null"
    set c_filter = "null"
    set c_exptime = -1
    set c_bounds = "null"
    set c_obsnum = -1
    set noffsets = 1
    set temp
    set samedate

# Process all the SPEX FITS files in the current directory.
# Files are named BD_NNNN.a,fits, where NNNN is the observation
# number starting at 1, or dark_NNNN.a.fits.  In case there are
# others we'll search for .a.fits.  There may be .b.fits for sky.
    foreach file ( *.[ab].fits )
       echo ""
       echo "Processing $file"

# Obtain the UT date.  Archive format name from the headers.  This is
# an inefficient approach doing an on-the-fly conversion.  Avoid
# "records in" and "records out" messages by redirection.
       ( fitshead $file > fitshead$$ ) >&/dev/null
       set etad = `grep DATE_OBS fitshead$$ | awk '{print substr($0,20,10)}'`
       set hms = `grep TIME_OBS fitshead$$ | awk '{print substr($0,15,15)}'`
       set hour = `echo $hms | awk '{print substr($0,1,2)}'`
       set obsnums = `grep IRAFNAME fitshead$$ | awk '{print substr($0,index($0,"_")+1,4)}'`

# Lose the leading zeroes.
       @ obsnum = $obsnums + 0

# Extract the date from yyyy-MM-dd format.
       set year = `echo $etad | awk '{print substr($0,1,4)}'`
       set month = `echo $etad | awk '{print substr($0,6,2)}'`
       set day = `echo $etad | awk '{print substr($0,9,2)}'`

# Form date in UKIRT standard notation.
       set date = `echo $year$month$day`
       echo "Date is $date   Time is $hms"

       if ( $first == 1 ) then
          set firstobs = $obsnum
          set first = 0

# Start a new observation number sequence for a new date, apart from a
# change over midnight.  Retain the first-half date for observations
# spanning midnight.
       else
          @ samedate = $prevdate + 1
          if ( $date == $samedate && $hour < 14 ) then
             @ date--
          endif
       endif

# Create a name in the UKIRT style.
       @ temp = 100000 + $obsnum
       set obsnumstr = `echo $temp | awk '{print substr($0,2,5)}'`
       set name = "spex${date}_${obsnumstr}"

# Obtain some important headers which will specify where a group starts.
# This is crude, but it's more efficient than doing an on the fly
# conversion to use fitsval.
       set object = `grep OBJECT fitshead$$ | awk '{print substr($0,12,17)}'`
       set filter = `grep GFLT fitshead$$ | awk '{print substr($0,18,13)}'`
       set exptime = `grep ITIME fitshead$$ | awk '{print substr($0,11,20)}'`
       set bounds = `grep ARRAY0 fitshead$$ | awk '{print substr($0,11,20)}'`

# Get a few more headers to be reformatted correctly later.
       set ra = `grep 'RA    ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set dec = `grep 'DEC   ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set dsptmfle = `grep DSPTMFLE fitshead$$ | awk '{print substr($0,20,11)}'`
       set beam = `grep BEAM fitshead$$ | awk '{print substr($0,29,1)}'`
       set timegps = `grep 'TIME_GPS' fitshead$$ | awk '{print substr($0,17,14)}'`
       set bgreset = `grep BGRESET fitshead$$ | awk '{print substr($0,16,15)}'`
       set calmir = `grep CALMIR fitshead$$ | awk '{print substr($0,20,11)}'`
       set dit = `grep 'DIT   ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set osf = `grep 'OSF   ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set slit = `grep 'SLIT   ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set grat = `grep 'GRAT   ' fitshead$$ | awk '{print substr($0,20,11)}'`
       set qthlamp = `grep QTH_LAMP fitshead$$ | awk '{print substr($0,20,11)}'`
       set inclamp = `grep INC_LAMP fitshead$$ | awk '{print substr($0,20,11)}'`
       set argsrc = `grep ARG_SRC fitshead$$ | awk '{print substr($0,20,11)}'`
       set irsrc = `grep IR_SRC fitshead$$ | awk '{print substr($0,20,11)}'`
       set shutter = `grep SHUTTER fitshead$$ | awk '{print substr($0,20,11)}'`
       set ha = `grep 'HA    ' fitshead$$ | awk '{print substr($0,20,11)}'`

# Get the airmass.
       set airmass = `grep AIRMASS fitshead$$ | awk '{print substr($0,20,11)}'`

       \rm fitshead$$

# If any of the headers change from the previous frame, we deem this
# to indicate a new group.
       if ( "$object" != "$c_object" || "$filter" != "$c_filter" || \
            "$exptime" != "$c_exptime" || "$bounds" != "$c_bounds" ) then

# If this is not the first group to be processed, we need to assign
# the number of offsets to the headers for the previous group.
# Add one to the number of offsets to allow for the UKIRT convention
# of the offset to 0,0.  The NOFFSETS keyword is placed before the
# ORIGIN keyword.
          if ( $grpnum >= $firstobs ) then
             echo "Group $grpnum has $noffsets members"
             set obs = $grpnum
             @ noffsets++
             while ( $obs <= $c_obsnum )
                @ temp = 100000 + $obs
                set obsstr = `echo $temp | awk '{print substr($0,2,5)}'`
                set ndf = "${prefix}${date}_${obsstr}"
                if ( -e ${ndf}.sdf ) then
                   fitsmod ndf=$ndf edit=write keyword=NOFFSETS value=$noffsets \
                           position=ORIGIN comment=\"Number of offsets\"
                endif
                @ obs++
             end
          endif

# New group, assigned to the observation number.  Start counting
# the group members.
          set grpnum = $obsnum
          echo "Starting a new group $grpnum"

          set noffsets = 1

# Keep a count of the number of group members.
       else
          @ noffsets++
       endif

# Store the first positions in a group as the base co-ordinates.
       if ( $noffsets == 1 ) then
          set rabase = $ra
          set decbase = $dec
       endif

# Copy the header values for comparison with the next frame.
       set c_object = "$object"
       set c_filter = "$filter"
       set c_exptime = $exptime
       set c_bounds = $bounds
       set c_obsnum = $obsnum

# Convert the FITS file to a simple NDF.  Redirect the information
# about the number of files processed to the bin.
       fits2ndf $file $name > /dev/null
       echo "...forming $name"

# The file steer will contain the required renaming of headers for
# the ORAC-DR group and frame number, plus reformatting selected headers
# to the FITS standard.
       if ( -e steer$$ ) then
          \rm steer$$
       endif
       touch steer$$

       cat >>! steer$$ <<EOF
R EPOCH EQUINOX
W OBSNUM(EQUINOX) $obsnum "Observation number"
W GRPNUM(EQUINOX) $grpnum "Group number"
U DATE_OBS $etad \$C
U TIME_OBS $hms \$C
R DATE_OBS DATE-OBS
R TIME_OBS TIME-OBS
U GFLT $filter \$C
U ARRAY0 $bounds \$C
U RA $ra \$C
U DEC $dec \$C
W UTEND $hms "End UTC (dummy)"
W AMEND(AIRMASS) $airmass "End airmass (dummy)"
W RABASE(DEC) $rabase "Base position right ascension"
W DECBASE(DEC) $decbase "Base position declination"
U DSPTMFLE $dsptmfle \$C
U BEAM $beam \$C
U TIME_GPS $timegps \$C
U BGRESET $bgreset \$C
U CALMIR $calmir \$C
U DIT $dit \$C
U OSF $osf \$C
U SLIT $slit \$C
U GRAT $grat \$C
U QTH_LAMP $qthlamp \$C
U INC_LAMP $inclamp \$C
U IR_SRC $irsrc \$C
U ARG_SRC $argsrc \$C
U SHUTTER $shutter \$C
U HA $ha \$C
EOF

# Edit the headers within the FITS airlock.
       fitsmod ndf=$name mode=file table=steer$$
       \rm steer$$

# Set the previous date for the next file.
       set prevdate = $date
    end

# The number offsets needs to be set in the final group.
# Add one to the number of offsets to allow for the UKIRT convention
# of the offset to 0,0.  The NOFFSETS keyword is placed before the
# EQUINOX keyword.
    if ( $grpnum >= $firstobs ) then
             echo "Group $grpnum has $noffsets members"
       set obs = $grpnum
       @ noffsets++
       while ( $obs <= $c_obsnum )
          @ temp = 100000 + $obs
          set obsstr = `echo $temp | awk '{print substr($0,2,5)}'`
          set ndf = "${prefix}${date}_${obsstr}"
          if ( -e ${ndf}.sdf ) then
             fitsmod ndf=$ndf edit=write keyword=NOFFSETS value=$noffsets \
                     position=EQUINOX comment=\"Number of offsets\"
          endif
          @ obs++
       end
    endif

EXIT:

#  Remove any intermediate files.
    \rm fitshead$$ steer$$ >& /dev/null
    exit
