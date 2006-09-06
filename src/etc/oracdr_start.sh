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
#     $Log$
#     Revision 1.1  2006/09/06 02:30:11  bradc
#     initial addition
#
#     Revision 1.7  2002/04/04 08:21:20  mjc
#     Allow for multiple Starlink User Notes.
#
#     Revision 1.6  2001/03/19 23:33:30  timj
#     Add oracdr_monitor
#
#     Revision 1.5  2000/10/11 01:13:51  timj
#     Add oracdr_parse_recipe
#
#     Revision 1.4  2000/02/03 04:52:50  timj
#     Slight change to startup screen
#
#     Revision 1.3  2000/02/03 03:44:09  timj
#     Add check for existence of IN/OUT directories
#
#     Revision 1.2  2000/02/03 03:14:18  timj
#     Add ORACDR_VERSION
#
#     Revision 1.1  2000/02/03 02:50:45  timj
#     Starlink startup scripts
#

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
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

if ( "$ORAC_PERLBIN" != "" ); then
  set starperl = $ORAC_PERLBIN
elif ( -e STAR_PERL ); then
  set starperl = STAR_PERL
else
  set starperl = NONE
fi

# Set up back door for the version number

if ( "$ORACDR_VERSION" != "" ); then
  set pkgvers = $ORACDR_VERSION
else
  set pkgvers = PKG_VERS
fi


# These are perl programs

if ( -e $starperl ); then

  # ORAC-DR
  # Might have an argument to oracdr passed in to this routine.
  # Therefore need to check for $oracdr_args shell variable
  # and use it for the alias to oracdr
  if !("$oracdr_args" != ""); then
    set oracdr_args ''
  fi

oracdr () {      "$starperl  ${ORAC_DIR}/bin/oracdr $oracdr_args" ${1+"$@"}; }
oracdr_db () {   "$starperl -d ${ORAC_DIR}/bin/oracdr" ${1+"$@"}; }
oracdr_nuke () { "$starperl  ${ORAC_DIR}/bin/oracdr_nuke" ${1+"$@"}; }
oracdisp () {    "$starperl  ${ORAC_DIR}/bin/oracdisp" ${1+"$@"}; }
oracdr_parse_recipe () { "$starperl ${ORAC_DIR}/bin/oracdr_parse_recipe" ${1+"$@"}; }
oracdr_monitor () { "$starperl ${ORAC_DIR}/bin/oracdr_monitor" ${1+"$@"}; }

else
  echo "************ Starlink perl could not be located. ********"
  echo "************       Please install STARPERL       ********"

oracdr () {       echo 'Command not available - needs Starlink PERL' ${1+"$@"}; }
oracdr_db () {    echo 'Command not available - needs Starlink PERL' ${1+"$@"}; }
oracdr_nuke () {  echo 'Command not available - needs Starlink PERL' ${1+"$@"}; }
oracdisp () {     echo 'Command not available - needs Starlink PERL' ${1+"$@"}; }
oracdr_monitor () { echo 'Command not available - needs Starlink PERL' ${1+"$@"}; }

fi

# These are shell scripts

oracman () {     'csh ${ORAC_DIR}/bin/oracman' ${1+"$@"}; }

# Define default documentation instruction.
set doc_command = "'showme sun${ORAC_SUN}'"

# Allow for more than one document per instrument.  Determine whether
# or not there is a comma in document number.
set comma_index = `echo ${ORAC_SUN} | awk '{print index($0,",")}'`
if ( $comma_index > 0 ); then

# Extract the document numbers.
   set doc_numbers = `echo ${ORAC_SUN} | awk '{i=1;while(i<=split($0,a,",")){print a[i];i++}}'`

# Form concatenated instruction giving options for finding documentation. 
   set doc_command = "'showme sun$doc_numbers[1]'"
   shift doc_numbers
   foreach doc ( $doc_numbers )
      set doc_command = "$doc_command or 'showme sun$doc'"
   end
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
if !( -d $ORAC_DATA_IN ); then
  echo '     \!\!\!\!\!\!\!\!\!\!\!\! but that directory does not exist \!\!\!\!\!\!\!\!\! '
fi

echo " Reduced data will appear in $ORAC_DATA_OUT"

# Check for that `out' directory
if !(-d $ORAC_DATA_OUT); then
  echo '     \!\!\!\!\!\!\!\!\!\!\!\! but that directory does not exist \!\!\!\!\!\!\!\!\! '
fi

echo " "
echo "+++++++++ For online $ORAC_INSTRUMENT reduction use oracdr -loop $ORAC_LOOP +++++++++"
echo ""
echo For comments specific to $ORAC_INSTRUMENT data reduction mail $ORAC_PERSON@jach.hawaii.edu
echo 'For problems with the ORAC-DR system mail helpme@jach.hawaii.edu'
echo '         http://www.jach.hawaii.edu/UKIRT/software/oracdr/'
echo ""
echo ""
