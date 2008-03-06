
#+
#  Name:
#     oracdr_gmos

#  Purpose:
#     Initialise ORAC-DR environment for use with gmos

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_gmos.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with gmos data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in 
#        a directory structure similar to that used at UKIRT.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, "/ukirtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/gmos` If ORAC_CAL_ROOT is not
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_gmos
#        Will set the variables assuming the current UT date.
#     oracdr_gmos 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/gmos`data/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Paul Hirst <p.hirst@jach.hawaii.edu>
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.3  2006/11/15 20:00:37  bradc
#     change ukirt_sw and/or jcmt_sw to jac_sw
#
#     Revision 1.2  2002/09/14 00:55:54  phirst
#     add pre-alpha warning
#
#     Revision 1.1  2002/06/05 21:18:50  phirst
#     Initial GMOS support
#
#     Revision 1.4  2002/04/02 03:04:52  mjc
#     Use \date command to override aliases.
#
#     Revision 1.3  2000/08/05 07:38:29  frossie
#     ORAC style
#
#     Revision 1.2  2000/02/03 03:43:38  timj
#     Correct doc typo
#
#     Revision 1.1  2000/02/03 02:50:45  timj
#     Starlink startup scripts
#
#     02 Jun 1999 (frossie)
#        Original Version

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /ukirtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jac_sw/oracdr_cal
endif

if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif

if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif


if ($1 != "") then
    set oracut = $1
else
    set oracut = `\date -u +%Y%m%d`
endif

set oracdr_args = "-ut $oracut"

# The file naming convention changed on 2002 March 1 to accommodate
# more than 1000 frames! 
if ( $oracut < 20020301 ) then
   setenv ORAC_INSTRUMENT GMOS2
else
   setenv ORAC_INSTRUMENT GMOS
endif

setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/gmos/$oracut/
setenv ORAC_DATA_OUT  $ORAC_DATA_ROOT/reduced/gmos/$oracut/
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/gmos

# screen things
setenv ORAC_PERSON p.hirst
setenv ORAC_LOOP flag
setenv ORAC_SUN  XXX

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

echo "Warning: GMOS suport in oracdr is pre-alpha / highly experimental."
echo "Although it basically works, it has not been refined or verified to be"
echo "scientifically valid. GMOS support was added to oracdr basically as a"
echo "demonstration of the ease of adding support for a new telescope and"
echo "instrumentation suite."
echo "Contact Paul Hirst <p.hirst@jach.hawaii.edu> for more info."
echo ""



# Tidy up
unset oracut
unset oracdr_args
