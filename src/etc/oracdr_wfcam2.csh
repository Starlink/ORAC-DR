#  Name: oracdr_wfcam2.csh
#
#  Invocation: source ${ORAC_DIR}/etc/oracdr_wfcam2.csh [UTDATE]
#
#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with WFCAM data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.
#
#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Jim Lewis (jrl@ast.cam.ac.uk)
#     Paul Hirst (p.hirst@jach.hawaii.edu)
#     {enter_new_authors_here}
#
#  Revision:
#     $Id$
#
#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.


# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /ukirtdata
endif

if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /ukirt_sw/oracdr_cal
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

setenv ORAC_INSTRUMENT WFCAM1
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/wfcam2/$oracut
setenv ORAC_DATA_OUT  $ORAC_DATA_ROOT/reduced/wfcam2/$oracut
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/wfcam
setenv ORAC_DATA_CASU $ORAC_DATA_OUT/casu

# screen things
setenv ORAC_PERSON jrl
setenv ORAC_LOOP flag
setenv ORAC_SUN

# CASU CIRDR paths
setenv PERL5LIB /ukirt_sw/cirdr/perlinstall:/ukirt_sw/cirdr/perllib

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset oracdr_args
