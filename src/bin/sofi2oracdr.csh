#!/bin/csh

#+
#  Name:
#     sofi2oracdr.csh

#  Purpose:
#     Converts SOFI raw or archive data into a UKIRT-like named files
#     for use in ORAC-DR.

#  Language:
#     Unix C-shell

#  Invocation:
#     sofi2oracdr.csh

#  Description:
#     This script processes all the SOFI*.FITS files in the current
#     working directory each forming an NDF suitable for use by the 
#     ORAC-DR imaging pipeline.
#
#     The NDFs are named sofi<date>_<observation_number>.  The UT
#     date is determined from the headers, and is in the numerical
#     format yyyyddmm.  Observations which span UT midnight take the
#     UT date of the first observation of that night available.  The
#     observation numbers come from the order in which they are
#     processed.  They are a 5-digit integer with leading zeroes
#     counting from 1.  While the script can handle data from different
#     nights, each with its own sequence of observation numbers, it's
#     recommended that you have one directory for each night's
#     observations.
#
#     Two FITS headers are written in each NDF: the observation number
#     in OBSNUM, and the group number in GRPNUM.  The latter is derived
#     form the HIERARCH.ESO.TPL.EXPNO header.  A group starts when this
#     header's value is 1, whereupon the group number is the observation
#     number.  The group number is unchanged until the next group is
#     located.
#
#     The script reports the input FITS file as it is processed, and its
#     date and time.  It also reports the creation of each NDF.

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
#     2004 June 11 (MJC):
#        Original version based upon isaac2oracdr.
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
    set obsnum = 1
    set grpnum = 1
    set first = 1
    set temp
    set samedate
    set utdates = ( )
    set obscounts = ( )

# Process all the SOFI FITS files in the current directory.
    foreach file ( SOFI*.fits )
       echo ""
       echo "Processing $file"

# Files either have an archive name containing the time in the form
# SOFI.yyyy-mm-dd:hh:mm:ss.sss.fits, or one describing the type
# of observation SOFI<description>_nnnn.fits where nnnn is the
# observation sequence number for the night.
       if ( $file =~ SOFI.[0-9][0-9][0-9][0-9]*.fits ) then
          set arcname = $file

# Obtain the archive format name from the headers.  This is
# an inefficient approach doing an on-the-fly conversion.  Avoid
# "records in" and "records out" messages by redirection.
       else
          (fitshead $file | grep ARCFILE | awk '{print $3}' | sed "s/'//g" >fitshead$$) >&/dev/null
          set arcname = `grep SOFI fitshead$$`
          \rm fitshead$$
       endif

# Extract the date in yyyymmdd format.
       set date = `echo $arcname | awk '{print substr($0,6,10)}' | sed 's/-//g'`
       set hour = `echo $arcname | awk '{print substr($0,17,2)}'`
       set min = `echo $arcname | awk '{print substr($0,20,2)}'`
       set sec = `echo $arcname | awk '{print substr($0,23,6)}'`
       set htime = `calc \"$hour+$min/60.0+$sec/3600.0\"` 
       echo "Date is $date   Time is $htime"

       if ( $first == 1 ) then
          set first = 0

# Record the first date and its corresponding observation number.
          set utdates = ( $utdates $date )
          set obscounts = ( $obscounts $obsnum )

# Start a new observation number sequence for a new date, apart from a
# change over midnight.  Retain the first-half date for observations
# spanning midnight.
       else
          @ samedate = $prevdate + 1
          if ( $date == $samedate && $hour < 19 ) then
             @ date--

# Different date.
          else if ( $date != $prevdate ) then

# Record the observation number for the previous date.
             set match = 0
             set i = 1
             foreach ut ( $utdates )
                if ( $ut == $prevdate ) then
                echo $obscounts
                   set obscounts[$i] = $obsnum
                   break
                endif
                @ i++
             end

# Look to see if the date is already known.  If it is, set
# the observation number to its previous value.
             set match = 0
             set i = 1
             foreach ut ( $utdates )
                if ( $ut == $date ) then
                   set obsnum = $obscounts[$i]
                   set match = 1
                   break
                endif
                @ i++
             end

# It's a new date.  Counting starts at one.
             if ( $match == 0 ) then
                set obsnum = 1
                set grpnum = 1

# Record the date and its corresponding observation number.
                set utdates = ( $utdates $date )
                set obscounts = ( $obscounts $obsnum )
             endif
          endif
       endif

# Create a name in the UKIRT style.
       @ temp = 100000 + $obsnum
       set obsnumstr = `echo $temp | awk '{print substr($0,2,5)}'`
       set name = "sofi${date}_${obsnumstr}"

# Extract the index number of the observation within the group.  Avoid
# "records in" and "records out" messages by redirection.
       (fitshead $file | grep "TPL EXPNO" | awk '{split($0,a," "); print a[6]}'>fitshead$$) >&/dev/null
       set grpmem = `grep \[0-9\] fitshead$$`
       \rm fitshead$$

# Extract the observation technique.
       (fitshead $file | grep "DPR TECH" | awk '{split($0,a," "); print a[6]}' | sed "s/'//g" >fitshead$$) >&/dev/null
       set technique = `grep \[A-Z\] fitshead$$`
       \rm fitshead$$

# Extract the exposure name.
       set expname = ""
       if ( "$technique" == "POLARIMETRY" ) then
          (fitshead $file | grep "DET EXP NAME" | awk '{split($0,a," "); print a[7]}'| sed "s/'//g" >fitshead$$) >&/dev/null
          set expname = `grep \[A-Za-z0-9\] fitshead$$ | awk '{print substr($0,1,5)}'`
          echo "expname: $expname"
          \rm fitshead$$
       endif

# The group index (member) number of 1 indicates the start of a new
# group.  By convention the group number is the observation number of
# the first group member.
       if ( $grpmem == 1 && ( "$expname" == "" || "$expname" == "Pol00" ) ) then
          set grpnum = $obsnum
          echo "Starting group $grpnum"
       endif

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
W OBSNUM(OBSERVER) $obsnum "Observation number"
W GRPNUM(OBSERVER) $grpnum "Group number"
EOF

# Edit the headers within the FITS airlock.
       fitsmod ndf=$name mode=file table=steer$$
       \rm steer$$

# Increment observation counter and set the previous date for the next
# file.
       @ obsnum++
       set prevdate = $date
    end
    
EXIT:

#  Remove any intermediate files.
    \rm fitshead$$ steer$$ >& /dev/null
    exit
