
#+ 
#  Name:
#    xoracdr_start.csh

#  Purposes:
#     Sets aliases for ORAC-DR and prints welcome message

#  Language:
#    C-shell script

#  Invocation:
#    source $ORAC_DIR/etc/xoracdr_start.csh

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
#     Revision 1.3  2001/03/02 05:06:37  allan
#     Working SelectRecipe widget used for Edit Recipe and Override Recipe menu items, plus minor GUI tweaks and a couple of bug fixes
#
#     Revision 1.2  2001/02/24 03:07:24  allan
#     Merged main line with Xoracdr branch
#
#     Revision 1.1.2.4  2001/02/02 03:15:10  allan
#     Corrected typo
#
#     Revision 1.1.2.3  2001/02/02 02:40:55  allan
#     Xoracdr GUI tweaks
#
#     Revision 1.1.2.2  2001/01/26 06:42:08  allan
#     Prototype Xoracdr GUI, minimal functionality
#
#     Revision 1.1.2.1  2001/01/24 04:10:49  allan
#     Skeleton version of Xoracdr, no functionality
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
set pkgvers = `${ORAC_DIR}/etc/oracdr_version.sh`

# These are perl programs

if (-e $STARPERL ) then

  # pass through command line arguements
  set args = ($argv[1-])
  set oracdr_args = ""
  if ( $#args > 0  ) then
    while ( $#args > 0 )
       set oracdr_args = "${oracdr_args} $args[1]"
       shift args       
    end
  endif

  echo " "
  echo " ORAC Data Reduction Pipeline -- (ORAC-DR Version ${pkgvers})"
  echo " "
  echo " Please wait, spawning Xoracdr${oracdr_args}..."
  $STARPERL  ${ORAC_DIR}/bin/Xoracdr ${oracdr_args}

else
  echo "ORAC Data Reduction Pipeline -- (ORAC-DR Version $pkgvers)"
  echo "Starlink PERL could not be found, please install STARPERL"
endif
