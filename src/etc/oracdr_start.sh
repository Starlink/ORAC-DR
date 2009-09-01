#+
#  Name:
#     oracdr_start

#  Purposes:
#     Sets aliases for ORAC-DR and prints welcome message

#  Language:
#    sh shell script

#  Invocation:
#    source $ORAC_DIR/etc/oracdr_start.sh

#  Description:
#    Sets all the aliases required to run ORAC-DR commands and
#    then prints the welcome message. Must be called from one
#    of the ORAC-DR instrument startup scripts.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Malcolm J. Currie (mjc@jach.hawaii.edu)
#     Brad Cavanagh (JAC, Hawaii)
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
#     - $ORACDR_VERSION environment variable can be used to override
#     the package version set during the installation.

#  History:
#     06-SEP-2006 (BRADC):
#        Initial addition
#     07-SEP-2006 (BRADC):
#        fix argument check
#     22-AUG-2007 (TIMJ):
#        Factor out perl and version determination

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 2006 Particle Physics and Astronomy Research
#     Council. Copyright (C) 2007 Science and Technology Facilities
#     Council. All Rights Reserved.

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


# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl
starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Set up back door for the version number
pkgvers=`${ORAC_DIR}/etc/oracdr_version.sh`

# These are perl programs

if test -e $starperl; then

  # Run initialization.
  orac_env_setup=`$starperl ${ORAC_DIR}/etc/setup_oracdr_env.pl bash $*`
  if test ! $?; then
    echo "**** ERROR IN setup_oracdr_env.pl ****"
    exit 255
  fi
  eval $orac_env_setup
  unset orac_env_setup

  # ORAC-DR
  # Might have an argument to oracdr passed in to this routine.
  # Therefore need to check for $oracdr_args shell variable
  # and use it for the alias to oracdr
  if test -z "${oracdr_args}"; then
    oracdr_args=''
  fi

alias oracdr="$starperl ${ORAC_DIR}/bin/oracdr ${oracdr_args}"
alias oracdr_db="$starperl -d ${ORAC_DIR}/bin/oracdr"
alias oracdr_nuke="$starperl ${ORAC_DIR}/bin/oracdr_nuke"
alias oracdisp="$starperl ${ORAC_DIR}/bin/oracdisp"
alias oracdr_parse_recipe="$starperl ${ORAC_DIR}/bin/oracdr_parse_recipe"
alias oracdr_monitor="$starperl ${ORAC_DIR}/bin/oracdr_monitor"

# These are shell scripts

oracman () {     'csh ${ORAC_DIR}/bin/oracman' ${1+"$@"}; }

# Define default documentation instruction.
doc_command="'showme sun${ORAC_SUN}'"

# Allow for more than one document per instrument.  Determine whether
# or not there is a comma in document number.
set comma_index=`echo ${ORAC_SUN} | awk '{print index($0,",")}'`
if test -z "$comma_index"; then
  comma_index=0
fi
if test "$comma_index" -gt 0; then

# Extract the document numbers.
   doc_numbers=`echo ${ORAC_SUN} | sed -e 's/,/ /g'`
   doc_num_array=($doc_numbers)

# Form concatenated instruction giving options for finding documentation. 
   doc_command="'showme sun${doc_num_array[0]}'"
   element_count=${#doc_num_array[@]}
   index=1
   while [ "$index" -lt "$element_count" ]
   do
      doc_command="${doc_command} or 'showme sun${doc_num_array[$index]}'"
      let "index = $index + 1"
   done
fi

# Start up message
echo " "
echo "     ORAC Data Reduction Pipeline -- (ORAC-DR Version $pkgvers)"
echo "     Configured for instrument $ORAC_INSTRUMENT"
echo " "
echo '     Type "oracdr -man" for usage'
echo "     Type $doc_command to browse the hypertext documentation"
echo " "
echo " "
echo " Raw data will be read from $ORAC_DATA_IN"

# Check for that `in' directory
if ! test -d $ORAC_DATA_IN; then
  echo '     !!!!!!!!!!!! but that directory does not exist !!!!!!!!! '
fi

echo " Reduced data will appear in $ORAC_DATA_OUT"

# Check for that `out' directory
if ! test -d $ORAC_DATA_OUT; then
  echo '     !!!!!!!!!!!! but that directory does not exist !!!!!!!!! '
fi

echo " "
echo "+++++++++ For online $ORAC_INSTRUMENT reduction use oracdr -loop $ORAC_LOOP +++++++++"
echo ""
echo For comments specific to $ORAC_INSTRUMENT data reduction mail $ORAC_PERSON@jach.hawaii.edu
echo 'For problems with the ORAC-DR system mail oracdr@jach.hawaii.edu'
echo '         http://www.oracdr.org'
echo ""
echo ""

else
  # Nothing is going to work
  echo "************ Starlink perl could not be located. ********"
  echo "************       Please install STARPERL       ********"

alias oracdr="echo 'Command not available - needs Starlink PERL'"
alias oracdr_db="echo 'Command not available - needs Starlink PERL'"
alias oracdr_nuke="echo 'Command not available - needs Starlink PERL'"
alias oracdisp="echo 'Command not available - needs Starlink PERL'"
alias oracdr_monitor="echo 'Command not available - needs Starlink PERL'"

fi

unset starperl
unset oracdr_args