
#+ 
#  Name:
#    picard_start.sh

#  Purposes:
#    Launch script for picard

#  Language:
#    Sh-shell script

#  Invocation:
#    $ORAC_DIR/etc/picard_start.csh

#  Description:
#     Determines perl locations and runs picard itself.

#  Authors:
#     Tim Jenness (JAC, Hawaii)
#     {enter_new_authors_here}

#  Notes:
#     Uses standard scheme for determining perl location

#  History:
#     2007-08-22 (TIMJ):
#        First version.

#  Copyright:
#     Copyright (C) 2007 Science and Technology Facilities Council.
#     All Rights Reserved.

#  Licence:
#     This program is free software; you can redistribute it and/or
#     modify it under the terms of the GNU General Public License as
#     published by the Free Software Foundation; either version 3 of the
#     License, or (at your option) any later version.

#     This program is distributed in the hope that it will be
#     useful,but WITHOUT ANY WARRANTY; without even the implied warranty
#     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#     General Public License for more details.

#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software
#     Foundation, Inc., 59 Temple Place,Suite 330, Boston, MA 02111-1307,
#     USA

#-

# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl
starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Set ORAC_LOGDIR if it is not already set and if we have a /jac_logs

if test -z "${ORAC_LOGDIR}"; then
    if test -e /jac_logs/oracdr; then
       export ORAC_LOGDIR=/jac_logs/oracdr
    fi
fi

if test -e $starperl; then
  
  exec $starperl ${ORAC_DIR}/bin/picard ${1+"$@"}

else
  echo "Picard - Pipeline for Combining and Analyzing Reduced Data"
  echo "Starlink PERL could not be found, please install STARPERL"
fi
