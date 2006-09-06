
#+ 
#  Name:
#    xoracdr_start.sh

#  Purposes:
#     Sets aliases for ORAC-DR and prints welcome message

#  Language:
#    sh shell script

#  Invocation:
#    source $ORAC_DIR/etc/xoracdr_start.sh

#  Description:
#    Sets all the aliases required to run the ORAC-DR GUI pipeline
#    launcher and then starts the GUI.

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
#     - $ORACDR_VERSION environment variable can be used to override
#       the package version set during the installation.

#  History:
#     $Log$
#     Revision 1.2  2006/09/06 23:52:57  bradc
#     fix for proper bash scripting
#
#     Revision 1.1  2006/09/06 02:30:26  bradc
#     initial addition

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# Need to make sure we use the Starlink PERL command in general this is
# in /star/Perl/bin/perl but needs to be set at script install time.

# Can do this by a secret override or by using the Starlink install system

# Check for the existence of a $ORAC_PERLBIN environment variable and allow 
# that to be used in preference to the starlink version if set.

if test ! -z "${ORAC_PERLBIN}"; then
  starperl=$ORAC_PERLBIN
elif test -e STAR_PERL; then
  starperl=STAR_PERL
else
  starperl=NONE
fi

# Set up back door for the version number

if test -z "${ORACDR_VERSION}"; then
  pkgvers=$ORACDR_VERSION
else
  pkgvers=PKG_VERS
fi


# These are perl programs

if test -e $starperl; then

  if test -z "${oracdr_args}"; then
    oracdr_args=''
  fi

  echo " "
  echo " ORAC Data Reduction Pipeline -- (ORAC-DR Version ${pkgvers})"
  echo " "
  echo " Please wait, spawning Xoracdr${oracdr_args}..."
  $starperl ${ORAC_DIR}/bin/Xoracdr ${oracdr_args}

else
  echo "ORAC Data Reduction Pipeline -- (ORAC-DR Version $pkgvers)"
  echo "Starlink PERL could not be found, please install STARPERL"
fi
