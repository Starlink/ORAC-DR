
#+
#  Name:
#     oracdr_wfcam

#  Purpose:
#     Initialise ORAC-DR environment for use with WFCAM

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam.sh

#  Description:
#     This script simply looks to see if we're on a wfdr machine, and
#     sources the appropriate oracdr_wfcam?.sh file

#  Parameters:
      # Parameters are simply passed on to the oracdr_wfcam?.sh

#  Authors:
#     Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
#     Paul Hirst <p.hirst@jach.hawaii.edu>

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-


hostname=`/bin/hostname`

script="none"

if ($hostname == "wfdr1"); then
    script=oracdr_wfcam1.csh
fi

if ($hostname == "wfdr2"); then
    script=oracdr_wfcam2.csh
fi

if ($hostname == "wfdr3"); then
    script=oracdr_wfcam3.csh
fi

if ($hostname == "wfdr4"); then
    script=oracdr_wfcam4.csh
fi

if ($script == "none"); then
    echo "You must be logged onto a wfcamdr machine for oracdr_wfcam to work"
    echo "Otherwise, use oracdr_wfcamN where N=camera number"
else
   source ${ORAC_DIR}/etc/$script $1 $2 $3 $4
fi
