
#+ 
#  Name:
#    fitseditor_start.sh

#  Purposes:
#     Sets aliases for FITS Editor and prints welcome message

#  Language:
#    sh shell script

#  Invocation:
#    source $ORAC_DIR/etc/fitseditor_start.sh

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
#     Revision 1.1  2006/09/06 02:29:48  bradc
#     initial addition
#
#     Revision 1.2  2001/10/24 14:35:25  allan
#     Re-integrate FITS Editor into ORAC-DR tree post-ADASS XI
#
#     Revision 1.1  2001/07/02 23:09:08  allan
#     FITS Editor, basic functionality only. Menus not working

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# Need to make sure we use the Starlink PERL command in general this is
# in /star/Perl/bin/perl but needs to be set at script install time.

# Can do this by a secret override or by using the Starlink install system

# Check for the existence of a $ORAC_PERLBIN environment variable and
# allow that to be used in preference to the starlink version if set.

# Use setenv starperl to pass the location along to the Xoracdr script
if ("$ORAC_PERLBIN" != ""); then
  export STARPERL=$ORAC_PERLBIN
elif ( -e STAR_PERL ); then
  export STARPERL=STAR_PERL
else
  export STARPERL=NONE
fi


# Set up back door for the version number

if ("$ORAC_VERSION" != ""); then
  set pkgvers = $ORAC_VERSION
else
  set pkgvers = PKG_VERS
fi

# Default for ORAC_PERL5LIB

if (! $?ORAC_PERL5LIB); then
  export ORAC_PERl5LIB=${ORAC_DIR}/lib/perl5
  echo " "
  echo " Warning: ORAC_PERL5LIB = ${ORAC_PERl5LIB}"
fi

# These are perl programs

if (-e $STARPERL ); then

  # pass through command line arguements
  set args = ($argv[1-])
  set editor_args = ""
  if ( $#args > 0  ); then
    while ( $#args > 0 )
       set editor_args = "${editor_args} $args[1]"
       shift args       
    end
  fi

  echo " "
  echo " FITS Header Editor -- (Version ${pkgvers})"
  echo " "
  echo " Please wait, spawning fitseditor${editor_args}..."
  $STARPERL ${ORAC_DIR}/bin/fitseditor.pl ${editor_args}

else
  echo "FITS Header Editor -- (Version $pkgvers)"
  echo "Starlink PERL could not be found, please install STARPERL"
fi
