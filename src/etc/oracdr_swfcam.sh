
#+
#  Name:
#     oracdr_swfcam

#  Purpose:
#     Initialise ORAC-DR environment for use with WFCAM

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_swfcam.sh

#  Description:
#     This script simply looks to see if we're on a wfdr machine, and
#     sources the appropriate oracdr_swfcam?.sh file

#  Parameters:
      # Parameters are simply passed on to the oracdr_swfcam?.sh

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
    script=oracdr_swfcam1.csh
fi

if ($hostname == "wfdr2"); then
    script=oracdr_swfcam2.csh
fi

if ($hostname == "wfdr3"); then
    script=oracdr_swfcam3.csh
fi

if ($hostname == "wfdr4"); then
    script=oracdr_swfcam4.csh
fi

if ($script == "none"); then
    echo "You must be logged onto a wfcamdr machine for oracdr_swfcam to work"
    echo "Otherwise, use oracdr_swfcamN where N=camera number"
else
   source ${ORAC_DIR}/etc/$script $1 $2 $3 $4
fi
