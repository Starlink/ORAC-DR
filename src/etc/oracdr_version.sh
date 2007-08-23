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

#  Notes:
#     - Currently reimplements the logic found in ORAC::Version
#       perl code.
#     - Requires $ORAC_DIR to be set

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
pkgvers=PKG_VERS

if test -e $ORAC_DIR/.version; then
  pkgvers=`cat $ORAC_DIR/.version`
elif test -e $ORAC_DIR/../.svn; then
  pkgvers=`svnversion $ORAC_DIR/../`
elif test -e $ORAC_DIR/.svn; then
  pkgvers=`svnversion $ORAC_DIR`
elif test -z "${ORACDR_VERSION}"; then
  pkgvers=$ORACDR_VERSION
fi

echo $pkgvers