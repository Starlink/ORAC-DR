
#+
#  Name:
#     oracdr_locateperl.sh

#  Purpose:
#     Simplify determination of appropriate perl

#  Invocation:
#     $ORAC_DIR/etc/oracdr_locateperl.sh

#  Description:
#     Many of the launch scripts need to know which perl to use
#     to run the command. This script works through the alternatives
#     and returns a full path to standard out. If no perl can be
#     found returns a string that will not be found. This script
#     can be used to avoid duplication of logic.

#  Authors:
#     Tim Jenness (JAC, Hawaii)

#  History:
#     2007-08-20 (TIMJ):
#        First implementation. Copied from oracdr_start.sh

#  Notes:
#     - ORAC_PERLBIN perl is preferred
#     - Then starperl if it is in the path
#     - Path relative to $ORAC_DIR (if it is being distributed with
#       Starlink software)
#     - Then Starlink perl derived from environment variables
#        STARLINK_DIR, STARLINK, STARCONF_DEFAULT_STARLINK
#     - hard-coded /star

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

# Default value is undefined. Historically this value
# would be substituted during install.
starperl=STAR_PERL

# Check for the existence of a $ORAC_PERLBIN environment variable
# and allow that to be used in preference to the starlink version
# if set (and if it exists)

if test ! -z "${ORAC_PERLBIN}"; then
    starperl=$ORAC_PERLBIN
    echo $starperl
    exit 0
fi

# "starperl" in the path is our next guess
# OSX bash does not send anything to stderr if the command is not
# found. Centos5 bash seems to need stderr to be redirected.
starperlbin=`which starperl 2>/dev/null`
if test ! -z "${starperlbin}"; then
    starperl=$starperlbin
else
    paths="${STARLINK_DIR} ${STARLINK} ${STARCONF_DEFAULT_STARLINK}"
    # Relative to ORAC-DR itself
    if test ! -z "${ORAC_DIR}"; then
	paths="${ORAC_DIR}/../.. ${paths}"
    fi
    # if all else fails take a stab at looking relative to KAPPA
    if test ! -z "${KAPPA_DIR}"; then
	paths="${paths} ${KAPPA_DIR}/../.."
    fi
    # Panic and try /star
    paths="${paths} /star /stardev"

    # Now try all the options
    for f in ${paths} " "; do
	if test -e "${f}/Perl/bin/perl"; then
	    starperl="${f}/Perl/bin/perl"
	    break
	fi
    done
fi

echo $starperl
