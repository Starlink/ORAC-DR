
#+
#  Name:
#     oracdr_swfcam

#  Purpose:
#     Initialise ORAC-DR environment for use with WFCAM

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_swfcam.csh

#  Description:
#     This script simply looks to see if we're on a wfdr machine, and
#     sources the appropriate oracdr_swfcam?.csh file

#  Parameters:
      # Parameters are simply passed on to the oracdr_swfcam?.csh

#  Authors:
#     Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
#     Paul Hirst <p.hirst@jach.hawaii.edu>

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-


set hostname = `/bin/hostname`

set script = "none"

if ($hostname == "wfdr1") then
    set script = oracdr_swfcam1.csh
endif

if ($hostname == "wfdr2") then
    set script = oracdr_swfcam2.csh
endif

if ($hostname == "wfdr3") then
    set script = oracdr_swfcam3.csh
endif

if ($hostname == "wfdr4") then
    set script = oracdr_swfcam4.csh
endif

if ($script == "none") then
    echo "You must be logged onto a wfcamdr machine for oracdr_swfcam to work"
    echo "Otherwise, use oracdr_swfcamN where N=camera number"
else
   source ${ORAC_DIR}/etc/$script $1 $2 $3 $4
endif
