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