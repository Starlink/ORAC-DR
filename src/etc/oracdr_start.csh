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
#     the package version set during the installation. This is only used
#     if the source code is not inside a subversion tree and there is no
#     $ORAC_DIR/.version file.

#  History:
#     03-FEB-2000 (TIMJ):
#        Create Starlink startup scripts.
#        - Add ORACDR_VERSION.
#        - Add check for existence of IN/OUT directories
#        - Slight change to startup screen
#     11-OCT-2000 (TIMJ):
#        Add oracdr_parse_recipe
#     19-MAR-2001 (TIMJ):
#        Add oracdr_monitor
#     04-APR-2002 (MJC):
#        Allow for multiple Starlink User Notes
#     04-MAY-2007 (TIMJ):
#        Expand version reporting logic

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research Council
#     Copyright (C) 2007 Science and Technology Facilities Council.
#     All Rights Reserved.

#-


# Need to make sure we use the Starlink PERL command
# in general this is in /star/Perl/bin/perl but needs
# to be set at script install time.

# Can do this by a secret override or by using the Starlink
# install system.

# Check for the existence of a $ORAC_PERLBIN environment variable
# and allow that to be used in preference to the starlink version
# if set (and if it exists)

if ( $?ORAC_PERLBIN ) then
  set starperl = $ORAC_PERLBIN
else if ( -e STAR_PERL ) then
  set starperl = STAR_PERL
else
  set starperl = NONE
endif

# Set up back door for the version number

if (-e $ORAC_DIR/.version) then
  set pkgvers = `cat $ORAC_DIR/.version`
else if (-e $ORAC_DIR/../.svn) then
  set pkgvers = `svnversion $ORAC_DIR/../`
else if (-e $ORAC_DIR/.svn) then
  set pkgvers = `svnversion $ORAC_DIR`
else if ( $?ORACDR_VERSION ) then
  set pkgvers = $ORACDR_VERSION
else
  set pkgvers = PKG_VERS
endif


# These are perl programs

if ( -e $starperl ) then

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
  alias oracdr_parse_recipe "$starperl ${ORAC_DIR}/bin/oracdr_parse_recipe"
  alias oracdr_monitor "$starperl ${ORAC_DIR}/bin/oracdr_monitor"

else
  echo "************ Starlink perl could not be located. ********"
  echo "************       Please install STARPERL       ********"

  alias oracdr       echo 'Command not available - needs Starlink PERL'
  alias oracdr_db    echo 'Command not available - needs Starlink PERL'
  alias oracdr_nuke  echo 'Command not available - needs Starlink PERL'
  alias oracdisp     echo 'Command not available - needs Starlink PERL'
  alias oracdr_monitor echo 'Command not available - needs Starlink PERL'

endif

# These are shell scripts

alias oracman     'csh ${ORAC_DIR}/bin/oracman'

# Define default documentation instruction.
set doc_command = "'showme sun${ORAC_SUN}'"

# Allow for more than one document per instrument.  Determine whether
# or not there is a comma in document number.
set comma_index = `echo ${ORAC_SUN} | awk '{print index($0,",")}'`
if ( $comma_index > 0 ) then

# Extract the document numbers.
   set doc_numbers = `echo ${ORAC_SUN} | awk '{i=1;while(i<=split($0,a,",")){print a[i];i++}}'`

# Form concatenated instruction giving options for finding documentation. 
   set doc_command = "'showme sun$doc_numbers[1]'"
   shift doc_numbers
   foreach doc ( $doc_numbers )
      set doc_command = "$doc_command or 'showme sun$doc'"
   end
endif

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
if !( -d $ORAC_DATA_IN ) then
  echo '     \!\!\!\!\!\!\!\!\!\!\!\! but that directory does not exist \!\!\!\!\!\!\!\!\! '
endif

echo " Reduced data will appear in $ORAC_DATA_OUT"

# Check for that `out' directory
if !(-d $ORAC_DATA_OUT) then
  echo '     \!\!\!\!\!\!\!\!\!\!\!\! but that directory does not exist \!\!\!\!\!\!\!\!\! '
endif

echo " "
echo "+++++++++ For online $ORAC_INSTRUMENT reduction use oracdr -loop $ORAC_LOOP +++++++++"
echo ""
echo For comments specific to $ORAC_INSTRUMENT data reduction mail $ORAC_PERSON@jach.hawaii.edu
echo 'For problems with the ORAC-DR system mail helpme@jach.hawaii.edu'
echo '         http://www.jach.hawaii.edu/UKIRT/software/oracdr/'
echo ""
echo ""
