#!/bin/sh
#+
#  Name:
#    fitseditor_start.h

#  Purposes:
#     Sets aliases for FITS Editor and prints welcome message

#  Language:
#    Bourne shell

#  Invocation:
#    $ORAC_DIR/etc/fitseditor_start.sh

#  Description:
#    Sets all the aliases required to run the FITS Header Editor and
#    then starts the GUI

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)
#     {enter_new_authors_here}

#  Notes:
#     - Requires that the location of Starlink perl is inserted
#       during the install.
#     - Requires that the package version is inserted during the
#       install
#     - $ORAC_PERLBIN environment variable can be used to override
#       the use of Starlink PERL.
#     - $ORAC_VERSION environment variable can be used to override
#       the package version set during the installation.

#  History:
#     $Log$
#     Revision 1.2  2001/10/24 14:35:25  allan
#     Re-integrate FITS Editor into ORAC-DR tree post-ADASS XI
#
#     Revision 1.1  2001/07/02 23:09:08  allan
#     FITS Editor, basic functionality only. Menus not working

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl
STARPERL=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Set up back door for the version number
pkgvers=`${ORAC_DIR}/etc/oracdr_version.sh`

# Default for ORAC_PERL5LIB

if [[ -z "$ORAC_PERL5LIB" ]]; then
  export ORAC_PERL5LIB="${ORAC_DIR}/lib/perl5"
  echo " "
  echo " Warning: ORAC_PERL5LIB = ${ORAC_PERL5LIB}"
fi

# These are perl programs

if [[ -e "$STARPERL" ]]; then
  echo " "
  echo " FITS Header Editor -- (Version ${pkgvers})"
  echo " "
  echo " Please wait, spawning fitseditor $@ ..."
  $STARPERL ${ORAC_DIR}/bin/fitseditor.pl  ${1+"$@"}

else
  echo "FITS Header Editor -- (Version $pkgvers)"
  echo "Starlink PERL could not be found, please install STARPERL"
fi
