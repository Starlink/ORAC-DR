
#+
#  Name:
#     oracdr_wfcam

#  Purpose:
#     Initialise ORAC-DR environment for use with WFCAM

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam.csh

#  Description:
#     This script simply looks to see if we're on a wfdr machine, and
#     sources the appropriate oracdr_wfcam?.csh file

#  Parameters:
      # Parameters are simply passed on to the oracdr_wfcam?.csh

#  Authors:
#     Paul Hirst <p.hirst@jach.hawaii.edu>

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-


set hostname = `/bin/hostname`

set script = "/bin/false"

if ($hostname == "wfdr1") then
    set script = oracdr_wfcam1.csh
endif

if ($hostname == "wfdr2") then
    set script = oracdr_wfcam2.csh
endif

if ($hostname == "wfdr3") then
    set script = oracdr_wfcam3.csh
endif

if ($hostname == "wfdr4") then
    set script = oracdr_wfcam4.csh
endif

source ${ORAC_DIR}/etc/$script $1 $2 $3 $4
