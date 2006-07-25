#!/bin/csh

#+
#  Name:
#     isaac2oracdr.csh

#  Purpose:
#     Converts ISAAC raw or archive data into a UKIRT-like named files
#     for use in ORAC-DR.

#  Language:
#     Unix C-shell

#  Invocation:
#     isaac2oracdr.csh

#  Description:
#     This script processes all the ISAAC*.FITS files in the current
#     working directory each forming an NDF suitable for use by the 
#     ORAC-DR imaging pipeline.
#
#     The NDFs are named isaac<date>_<observation_number>.  The UT
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
#     2002 December 4 (MJC):
#        Original version.
#     2003 January 19 (MJC):
#        No longer translated hierarchical headers, as now recognised by
#        ORAC-DR via AStro::FITS::Header.
#     2003 May 7 (MJC):
#        Allow for raw data naming.
#     2005 February 28 (MJC):
#        Account for night calibrations' mixed data types by splitting
#        into groups of each type.
#     {enter_further_changes_here}

#-

# Setup
# =====

# Interruption causes exit.
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
    set previous_type = " "
    set previous_file = " "
    set splitcalib = 0

# Search for each file and extract time metadata.
# ===============================================

# Process all the ISAAC FITS files in the current directory.
    foreach file ( ISAAC*.fits )
       echo ""
       echo "Processing $file"

# Files either have an archive name containing the time in the form
# ISAAC.yyyy-mm-dd:hh:mm:ss.sss.fits, or one describing the type
# of observation ISAAC<description>_nnnn.fits where nnnn is the
# observation sequence number for the night.
       if ( $file =~ ISAAC.[0-9][0-9][0-9][0-9]*.fits ) then
          set arcname = $file

# Obtain the archive format name from the headers.  This is
# an inefficient approach doing an on-the-fly conversion.  Avoid
# "records in" and "records out" messages by redirection.
       else
          (fitshead $file | grep ARCFILE | awk '{print $3}' | sed "s/'//g" >fitshead$$) >&/dev/null
          set arcname = `grep ISAAC fitshead$$`
          \rm fitshead$$
       endif

# Extract the date in yyyymmdd format.
       set date = `echo $arcname | awk '{print substr($0,7,10)}' | sed 's/-//g'`
       set hour = `echo $arcname | awk '{print substr($0,18,2)}'`
       set min = `echo $arcname | awk '{print substr($0,21,2)}'`
       set sec = `echo $arcname | awk '{print substr($0,24,6)}'`
       set htime = `calc \"$hour+$min/60.0+$sec/3600.0\"` 
       echo "Date is $date   Time is $htime"

# Determine the file name (from UT date and observation number).
# ==============================================================
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
       set name = "isaac${date}_${obsnumstr}"

# Obtain more metadata.
# =====================

# Extract the index number of the observation within the group.  Avoid
# "records in" and "records out" messages by redirection.
       (fitshead $file | grep "TPL EXPNO" | awk '{split($0,a," "); print a[6]}'>fitshead$$) >&/dev/null
       set grpmem = `grep \[0-9\] fitshead$$`
       \rm fitshead$$

# Extract the number of the observations within the group.  Avoid
# "records in" and "records out" messages by redirection.
       (fitshead $file | grep "TPL NEXP" | awk '{split($0,a," "); print a[6]}'>fitshead$$) >&/dev/null
       set grpcount = `grep \[0-9\] fitshead$$`
       \rm fitshead$$

# Extract the observation technique.
       (fitshead $file | grep "DPR TECH" | awk '{split($0,a," "); print a[6]}' | sed "s/'//g" >fitshead$$) >&/dev/null
       set technique = `grep \[A-Z\] fitshead$$`
       \rm fitshead$$

# Extract the observation type.
       (fitshead $file | grep "DPR TYPE" | awk '{split($0,a," "); print a[6]}' | sed "s/'//g" >fitshead$$) >&/dev/null
       set type = `grep \[A-Z,\] fitshead$$`
       \rm fitshead$$

# Extract the exposure name.
       set expname = ""
       if ( "$technique" == "POLARIMETRY" ) then
          (fitshead $file | grep "DET EXP NAME" | awk '{split($0,a," "); print a[7]}'| sed "s/'//g" >fitshead$$) >&/dev/null
          set expname = `grep \[A-Za-z0-9\] fitshead$$ | awk '{print substr($0,1,5)}'`
          echo "expname: $expname"
          \rm fitshead$$
       endif

# Extract the template name.
       (fitshead $file | grep "TPL ID" | awk '{split($0,a," "); print a[6]}' | sed "s/'//g" >fitshead$$) >&/dev/null
       set template = `grep \[A-z\] fitshead$$`
       set tname =  `echo $template |  awk '{print substr($0,18,10)}'`
       set nightcalib = 0
       if ( "$tname" == "NightCalib" ) then
          set nightcalib = 1
       endif
       \rm fitshead$$

# Detemine the group number.
# ==========================

# The group index (member) number of 1 indicates the start of a new
# group.  By convention the group number is the observation number of
# the first group member.
       if ( $grpmem == 1 && ( "$expname" == "" || "$expname" == "Pol00" ) ) then
          set grpnum = $obsnum
          echo "Starting group $grpnum"

# Night Calibration
# -----------------

# There is a special case.  The spectroscopy night calibration may
# contain two groups---arc and flat---although bundled as one group.
# These need to be split.
       else if ( $nightcalib == 1 ) then
          if ( "$type" != "$previous_type" ) then
             set grpnum = $obsnum
             echo "Starting group $grpnum"

# Correct previous NDF's group size.
# ----------------------------------
# Also the number of group members needs to be reduced in the previous
# file.  While it would be good to edit all the group members, this is
# sufficient.
             @ previous_size = $grpmem - 1

# The file steer will contain the required new value for the group size
# header.  Retain the comment ($C).
             if ( -e steer$$ ) then
                \rm steer$$
             endif
             touch steer$$

             cat >>! steer$$ <<EOF
U HIERARCH.ESO.TPL.NEXP $previous_size \$C
EOF

# Edit the headers within the FITS airlock of the previous NDF.
             fitsmod ndf=$previous_name mode=file table=steer$$
             \rm steer$$

# Correct the current NDF's group size.
# -------------------------------------

# Specify the number of frames in the new group, i.e. take off those
# that were allocated to the first group of the partition.
             @ groupsize = $grpcount - $previous_size
             set splitcalib = 1
          endif

# Flag that this is part of a calibration group requiring header value
# changes.
          if ( $grpmem != $grpcount ) then
             set previous_type = " "
          endif
          set previous_name = $name
       endif

# Convert the data and add metadata for ORAC-DR.
# ==============================================

# Convert the FITS file to a simple NDF.  Redirect the information
# about the number of files processed to the bin.
       fits2ndf $file $name > /dev/null
       echo "...forming $name"

# The file steer will contain the required renaming of headers for
# the ORAC-DR group and frame number.  It will also contain the
# required new value for the group size header from a night
# calibration, where we retain the comment ($C).
       if ( -e steer$$ ) then
          \rm steer$$
       endif
       touch steer$$

       if ( $splitcalib == 1 ) then
          cat >>! steer$$ <<EOF
W OBSNUM(OBSERVER) $obsnum "Observation number"
W GRPNUM(OBSERVER) $grpnum "Group number"
U HIERARCH.ESO.TPL.NEXP $groupsize \$C
EOF
       else
          cat >>! steer$$ <<EOF
W OBSNUM(OBSERVER) $obsnum "Observation number"
W GRPNUM(OBSERVER) $grpnum "Group number"
EOF
       endif

# Edit the headers within the FITS airlock of the current NDF.
       fitsmod ndf=$name mode=file table=steer$$
       \rm steer$$

# End of the night calibration group.
       if ( $nightcalib == 1 && $grpmem != $grpcount ) then
          set splitcalib = 0
          set nightcalib = 0
       endif

# Increment observation counter and set the previous date and
# observation type for the next file.
       @ obsnum++
       set prevdate = $date
       set previous_type = $type
       set previous_name = $name
    end
    
EXIT:

#  Remove any intermediate files.
    \rm fitshead$$ steer$$ >& /dev/null
    exit
