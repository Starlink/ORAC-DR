#!/bin/csh

#+
#  Name:
#     cc2oracdr.csh

#  Purpose:
#     Converts ClassicCam raw or archive data into a UKIRT-like named
#     files for use in ORAC-DR.

#  Language:
#     Unix C-shell

#  Invocation:
#     cc2oracdr.csh

#  Description:
#     This script processes all the ir*.FITS files in the current
#     working directory each forming an NDF suitable for use by the
#     ORAC-DR imaging pipeline.
#
#     The NDFs are named cc<date>_<observation_number>.  The UT
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
#     object name, filter, exposure time, quadrant---changes value.
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
#     2003 July 16 (MJC):
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
    set obsnum = 100
    set grpnum = 100
    set first = 1
    set c_object = "null"
    set c_filter = "null"
    set c_exptime = -1
    set c_quad = -1
    set c_obsnum = -1
    set noffsets = 1
    set temp
    set samedate

# Process all the ClassicCam FITS files in the current directory.
# Files are named irNNN,fits, where NNN is the observation number
# starting at 100.
    foreach file ( ir*.fits )
       echo ""
       echo "Processing $file"

# Obtain the UT date.  archive format name from the headers.  This is
# an inefficient approach doing an on-the-fly conversion.  Avoid
# "records in" and "records out" messages by redirection.
       ( fitshead $file > fitshead$$ ) >&/dev/null
       set etad = `grep DATE-OBS fitshead$$ | awk '{print substr($0,12,18)}'`
       set time = `grep 'UT      ' fitshead$$ | awk '{print substr($0,12,19)}'`
       set hour = `echo $time | awk '{print substr($0,1,2)}'`
       set obsnum = `grep IRPICNO fitshead$$ | awk '{print substr($0,28,3)}'`

# Extract the date from ddMMMyy format.  This is an assumption; it might
# be dMMMyy for single digit days.
       set day = `echo $etad | awk '{print substr($0,1,2)}'`
       set month = `echo $etad | awk '{print substr($0,3,3)}'`
       set year = `echo $etad | awk '{print substr($0,6,2)}'`

# Convert the year to yyyy.  The camera didn't exist before 1980, and
# is retired so these limits are largely arbitrary.
       if ( $year > 80 ) then
          @ year += 1900
       else
          @ year += 2000
       endif

# Convert three-letter month to numerical form with leading zero.
       switch ( "$month" )
       case Jan:
           set month = "01"
           breaksw
       case Feb:
           set month = "02"
           breaksw
       case Mar:
           set month = "03"
           breaksw
       case Apr:
           set month = "04"
           breaksw
       case May:
           set month = "05"
           breaksw
       case Jun:
           set month = "06"
           breaksw
       case Jul:
           set month = "07"
           breaksw
       case Aug:
           set month = "08"
           breaksw
       case Sep:
           set month = "09"
           breaksw
       case Oct:
           set month = "10"
           breaksw
       case Nov:
           set month = "11"
           breaksw
       case Dec:
           set month = "12"
           breaksw
       endsw

# Form date in UKIRT standard notation.
       set date = `echo $year$month$day`
       echo "Date is $date   Time is $time"

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
       set name = "cc${date}_${obsnumstr}"

# Obtain some important headers which will specify where a group starts.
# This is crude, but it's more efficient than doing an on the fly
# conversion to use fitsval.
       set object = `grep OBJECT fitshead$$ | awk '{print substr($0,12,17)}'`
       set filter = `grep 'FILTER  ' fitshead$$ | awk '{print substr($0,12,17)}'`
       set exptime = `grep EXPTIME fitshead$$ | awk '{print substr($0,11,20)}'`
       set loopnum = `grep LOOPNUM fitshead$$ | awk '{print substr($0,30,1)}'`
       set loop = `grep 'LOOP    ' fitshead$$ | awk '{print substr($0,29,2)}'`
       set quad = `grep QUAD fitshead$$ | awk '{print substr($0,30,1)}'`
       \rm fitshead$$

# If any of the headers change from the previous frame, we deem this
# to indicate a new group.
       if ( "$object" != "$c_object" || "$filter" != "$c_filter" || \
             "$exptime" != "$c_exptime" || "$quad" != "$c_quad" ) then

# If this is not the first group to be processed, we need to assign
# the number of offsets to the headers for the previous group.
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
                set ndf = "cc${date}_${obsstr}"
                if ( -e ${ndf}.sdf ) then
                   fitsmod ndf=$ndf edit=write keyword=NOFFSETS value=$noffsets \
                           position=EQUINOX comment=\"Number of offsets\"
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

# Copy the header values for comparison with the next frame.
       set c_object = "$object"
       set c_filter = "$filter"
       set c_exptime = $exptime
       set c_quad = $quad
       set c_obsnum = $obsnum

# Convert the FITS file to a simple NDF.  Redirect the information
# about the number of files processed to the bin.
       fits2ndf $file $name > /dev/null
       echo "...forming $name"

# The file steer will contain the required renaming of headers for
# the ORAC-DR group and frame number.
       if ( -e steer$$ ) then
          \rm steer$$
       endif
       touch steer$$

       cat >>! steer$$ <<EOF
W OBSNUM(EQUINOX) $obsnum "Observation number"
W GRPNUM(EQUINOX) $grpnum "Group number"
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
          set ndf = "cc${date}_${obsstr}"
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
