#+

# Check to see if we're on a WFCAM data reduction machine. If so, and
# the output directory doesn't exist, create it.
set hostname=`/bin/hostname`
if( $hostname == "wfdr1" || $hostname == "wfdr2" || $hostname == "wfdr3" || $hostname == "wfdr4" ) then
    if( ! -d ${ORAC_DATA_OUT} ) then
        mkdir $ORAC_DATA_OUT
    endif
endif

