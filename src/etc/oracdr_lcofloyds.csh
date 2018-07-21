
#+
#  Name:
#     oracdr_lcofloyds

#  Purpose:
#     Initialise ORAC-DR environment for use with LCO FLOYDS 2.0M spectrograph

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_lcofloyds.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with LCO SBIG data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a LCOGT
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
#        If no value is set, "/mnt/images/daydirs" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/lcofloyds` If ORAC_CAL_ROOT is not
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_lcofloyds
#        Will set the variables assuming the current UT date.
#     oracdr_lcofloyds 20120314 en05
#        Use UT data 20120314 for camera en05

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
#     Tim Lister (tlister@lcogt.net)
#     Paul Hirst <p.hirst@jach.hawaii.edu>
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     10 Nov 2009 (tlister)
#        Original Version based on oracdr_lcospectral.csh
#     25 Feb 2013 (tlister)
#        Modified to read and pass camera code from cmdline.

#  Copyright:
#     Copyright (C) 2011-2013 Las Cumbres Observatory Global Telescope Inc.  All
#     Rights Reserved.

#-

if ( $#argv != 2 ) then
  echo "Wrong number of command line arguments"
  exit (-1)
endif

setenv ORAC_INSTRUMENT LCOFLOYDS-$argv[2]

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
