
#+
#  Name:
#     oracdr_start

#  Purposes:
#     Sets aliases for ORAC-DR and prints welcome message

#  Language:
#    C-shell script

#  Invocation:
#    source $ORAC_DIR/etc/oracdr_start.csh

#  Description:
#    Sets all the aliases required to run ORAC-DR commands and
#    then prints the welcome message. Must be called from one
#    of the ORAC-DR instrument startup scripts.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  Notes:
#     - Requires that the location of Starlink perl is inserted
#     during the install.
#     - Requires that the package version is inserted during the
#     install
#     - Must be called from an instrument startup script (eg oracdr_ufti)
#     else the environment variables required to run oracdr itself
#     will not be set correctly and an error will result.
#     - $ORAC_PERLBIN environment variable can be used to override
#     the use of Starlink PERL.

#  History:
#     $Log$
#     Revision 1.1  2000/02/03 02:50:45  timj
#     Starlink startup scripts
#

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-


# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl but needs
# to be set at script install time.

# Can do this by a secret override or by using the Starlink
# install system

# Check for the existence of a $ORAC_PERLBIN environment variable
# and allow that to be used in preference to the starlink version
# if set (and if it exists)

if ($?ORAC_PERLBIN) then
  set starperl = $ORAC_PERLBIN
else if ( -e STAR_PERL ) then
  set starperl = STAR_PERL
else
  set starperl = NONE
endif

# These are perl programs

if (-e $starperl ) then

  # ORAC-DR
  # Might have an argument to oracdr passed in to this routine.
  # Therefore need to check for $oracdr_args shell variable
  # and use it for the alias to oracdr
  if !($?oracdr_args) then
    set oracdr_args ''
  endif

  alias oracdr      "$starperl  ${ORAC_DIR}/bin/oracdr $oracdr_args"
  alias oracdr_db   "$starperl -d ${ORAC_DIR}/bin/oracdr"
  alias oracdr_nuke "$starperl  ${ORAC_DIR}/bin/oracdr_nuke"
  alias oracdisp    "$starperl  ${ORAC_DIR}/bin/oracdisp"

else
  echo "************ Starlink perl could not be located. ********"
  echo "************       Please install STARPERL       ********"

  alias oracdr       echo 'Command not available - needs Starlink PERL'
  alias oracdr_db    echo 'Command not available - needs Starlink PERL'
  alias oracdr_nuke  echo 'Command not available - needs Starlink PERL'
  alias oracdisp     echo 'Command not available - needs Starlink PERL'

endif

# These are shell scripts

alias oracman     'csh ${ORAC_DIR}/bin/oracman'


# Start up message

echo " "
echo "     ORAC Data Reduction Pipeline -- (ORAC-DR Version PKG_VERS)"
echo "     Configured for instrument $ORAC_INSTRUMENT"
echo " "
echo '     Type "oracdr -h" for usage'
echo "     Type 'showme sun${ORAC_SUN}' to browse the hypertext documentation"
echo " "
echo " "
echo " Raw data will appear in $ORAC_DATA_IN"
echo " Reduced data will appear in $ORAC_DATA_OUT"
echo " "
echo "+++++++++ For automatic $ORAC_INSTRUMENT reduction use oracdr -loop $ORAC_LOOP +++++++++"
echo ""
echo For comments specific to $ORAC_INSTRUMENT data reduction mail $ORAC_PERSON@jach.hawaii.edu
echo 'For problems with the ORAC-DR system mail helpme@jach.hawaii.edu'
echo '         http://www.jach.hawaii.edu/UKIRT/software/oracdr/'
echo ""
echo ""
