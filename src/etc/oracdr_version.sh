#!/bin/sh
#+
#  Name:
#     oracdr_version.sh

#  Purpose:
#     Simplify calculation of oracdr version number

#  Invocation:
#     $ORAC_DIR/etc/oracdr_version.sh

#  Description:
#     Many of the launch scripts require access to the version
#     number. Thi script echoes the version number to standard
#     out so that it can be accessed by all startup scripts without
#     having to duplicate the logic.

#  Authors:
#     Tim Jenness (JAC, Hawaii)

#  History:
#     2007-08-20 (TIMJ):
#        First implementation. Copied from oracdr_start.sh
#     2009-03-17 (TIMJ):
#        Modified for git. Uses perl in the first instance.

#  Notes:
#     - Preferentially calls ORAC::Version->getVersion in perl to get
#       the version. Then falls back to reimplementation in shell.
#     - Requires $ORAC_DIR and $ORAC_PERL5LIB to be set.

#  Copyright:
#     Copyright (C) 2007, 2009 Science and Technology Facilities Council.
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
pkgvers=PKG_VERS

# Find a perl
starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Use the standard oracdr perl logic. This should hopefully work
# most of the time
if test -e $starperl; then
  ppkgvers=`$starperl -I${ORAC_PERL5LIB} -MORAC::Version -e 'print ORAC::Version->getVersion()' 2>/dev/null`
  if test -n "$ppkgvers"; then
    pkgvers="$ppkgvers"
  fi
fi

# if that failed, fall back to reimplementing the logic
if test "$pkgvers" == "PKG_VERS"; then
  if test -e $ORAC_DIR/version.sh; then
    export GIT_DIR=${ORAC_DIR}/../.git
    pkgvers=`sh ${ORAC_DIR}/version.sh 2>/dev/null | head -2 | tail -1 | cut -c 1-12`
  elif test -e $ORAC_DIR/oracdr.version; then
    pkgvers=`cat $ORAC_DIR/oracdr.version | head -2 | tail -1 | cut -c 1-12`
  elif test -n "${ORACDR_VERSION}"; then
    pkgvers=$ORACDR_VERSION
  fi
fi

echo $pkgvers
