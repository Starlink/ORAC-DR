#+
#  Name:
#     oracdr_uist

#  Purpose:
#     Initialise ORAC-DR environment for use with UIST

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_uist.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with UIST data.
#     An optional argument is the UT date.  This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        The UT date of interest.  This should be in YYYYMMDD format.
#        It is used to set the location of the input and output data
#        directories.  This assumes that the data are located in a
#        directory structure similar to that used at UKIRT.  The UT date
#        also sets an appropriate alias for ORAC-DR itself.  If no value
#        is specified, the current UT date is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given & Returned)
#        The root location of the data input and output directories.
#        If no value is set, $ORAC_DATA_ROOT is set to "/ukirtdata".
#     $ORAC_CAL_ROOT = Environment Variable (Given & Returned)
#        The root location of the calibration files.  $ORAC_DATA_CAL is
#        derived from this variable by adding the appropriate value of
#        $ORAC_INSTRUMENT.  In this case $ORAC_DATA_CAL is set to
#        $ORAC_CAL_ROOT/uist.  If ORAC_CAL_ROOT is not defined
#        defined it defaults to "/ukirt_sw/oracdr_cal".

#  Examples:
#     oracdr_uist
#        Will set the variables assuming the current UT date.
#     oracdr_uist 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables ORAC_RECIPE_DIR and ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be:
#     $ORAC_DATA_ROOT/raw/uist/<UT> for the "raw" data, and
#     $ORAC_DATA_ROOT/reduced/uist/<UT> for the "reduced" data.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     MJC: Malcolm J. Currie (mjc@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2006/09/06 02:30:24  bradc
#     initial addition
#
#     Revision 1.4  2003/07/23 16:41:26  mjc
#     Supplied the SUN numbers.
#
#     Revision 1.3  2002/04/02 03:04:52  mjc
#     Use \date command to override aliases.
#
#     Revision 1.2  2001/12/01 02:13:46  timj
#     - s/Michelle/UIST/g
#     - Quote ???
#
#     Revision 1.1  2001/07/04 02:07:55  timj
#     Add UIST
#
#     2001 March 3 (MJC):
#        Original version based upon CGS4 equivalent.

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# orac things
if !("$ORAC_DATA_ROOT" != ""); then
    export ORAC_DATA_ROOT=/ukirtdata
fi

if !("$ORAC_CAL_ROOT" != ""); then
    export ORAC_CAL_ROOT=/ukirt_sw/oracdr_cal
fi

if ("$ORAC_RECIPE_DIR" != ""); then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
fi

if ("$ORAC_PRIMITIVE_DIR" != ""); then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
fi


if ($1 != ""); then
    set oracut = $1
else
    set oracut = `\date -u +%Y%m%d`
fi

set oracdr_args = "-ut $oracut"

export ORAC_INSTRUMENT=UIST
export ORAC_DATA_IN=$ORAC_DATA_ROOT/raw/uist/$oracut
export ORAC_DATA_OUT=$ORAC_DATA_ROOT/reduced/uist/$oracut
export ORAC_DATA_CAL=$ORAC_CAL_ROOT/uist

# screen things
export ORAC_PERSON=ATC
export ORAC_LOOP=flag
export ORAC_SUN='232,236,246'

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset oracdr_args
