
#+ 
#  Name:
#    fitseditor_start.csh

#  Purposes:
#     Sets aliases for FITS Editor and prints welcome message

#  Language:
#    C-shell script

#  Invocation:
#    source $ORAC_DIR/etc/fitseditor_start.csh

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
#     - $ORACDR_VERSION environment variable can be used to override
#       the package version set during the installation.

#  History:
#     $Log$
#     Revision 1.1  2001/07/02 23:09:08  allan
#     FITS Editor, basic functionality only. Menus not working
#
#
#

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

# Use setenv starperl to pass the location along to the Xoracdr script
if ($?ORAC_PERLBIN) then
  setenv STARPERL $ORAC_PERLBIN
else if ( -e STAR_PERL ) then
  setenv STARPERL STAR_PERL
else
  setenv STARPERL NONE
endif


# Set up back door for the version number

if ($?ORACDR_VERSION) then
  set pkgvers = $ORACDR_VERSION
else
  set pkgvers = PKG_VERS
endif


# These are perl programs

if (-e $STARPERL ) then

  # pass through command line arguements
  set args = ($argv[1-])
  set editor_args = ""
  if ( $#args > 0  ) then
    while ( $#args > 0 )
       set editor_args = "${editor_args} $args[1]"
       shift args       
    end
  endif

  echo " "
  echo " FITS Header Editor -- (Version ${pkgvers})"
  echo " "
  echo " Please wait, spawning fitseditor${editor_args}..."
  $STARPERL  ${ORAC_DIR}/bin/fitseditor.pl ${editor_args}

else
  echo "FITS Header Editor -- (Version $pkgvers)"
  echo "Starlink PERL could not be found, please install STARPERL"
endif
