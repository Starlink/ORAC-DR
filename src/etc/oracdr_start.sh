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

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 2006 Particle Physics and Astronomy Research
#     Council. Copyright (C) 2007 Science and Technology Facilities
#     Council. All Rights Reserved.

#-


# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl but needs
# to be set at script install time.

# Can do this by a secret override or by using the Starlink
# install system.

# Check for the existence of a $ORAC_PERLBIN environment variable
# and allow that to be used in preference to the starlink version
# if set (and if it exists)

if test ! -z "${ORAC_PERLBIN}"; then
  starperl=$ORAC_PERLBIN
elif test -e STAR_PERL; then
  starperl=STAR_PERL
else
  starperl=NONE
fi

# Set up back door for the version number

if test -e $ORAC_DIR/.version; then
  pkgvers=`cat $ORAC_DIR/.version`
elif test -e $ORAC_DIR/../.svn; then
  pkgvers=`svnversion $ORAC_DIR/../`
elif test -e $ORAC_DIR/.svn; then
  pkgvers = `svnversion $ORAC_DIR`
elif test -z "${ORACDR_VERSION}"; then
  pkgvers=$ORACDR_VERSION
else
  pkgvers=PKG_VERS
fi

# Set ORAC_LOGDIR if it is not already set and if we have a /jac_logs

if test -z "${ORAC_LOGDIR}"; then
    if test -e /jac_logs/oracdr; then
       export ORAC_LOGDIR=/jac_logs/oracdr
    fi
fi

# These are perl programs

if test -e $starperl; then

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

else
  echo "************ Starlink perl could not be located. ********"
  echo "************       Please install STARPERL       ********"

alias oracdr="echo 'Command not available - needs Starlink PERL'"
alias oracdr_db="echo 'Command not available - needs Starlink PERL'"
alias oracdr_nuke="echo 'Command not available - needs Starlink PERL'"
alias oracdisp="echo 'Command not available - needs Starlink PERL'"
alias oracdr_monitor="echo 'Command not available - needs Starlink PERL'"

fi

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
echo '     Type "oracdr -h" for usage'
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
echo 'For problems with the ORAC-DR system mail helpme@jach.hawaii.edu'
echo '         http://www.jach.hawaii.edu/UKIRT/software/oracdr/'
echo ""
echo ""
