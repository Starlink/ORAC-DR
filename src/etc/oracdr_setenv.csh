#

# Set ORAC_LOGDIR if it is not already set and if we have a /jac_logs
# directory.
if( ! $?ORAC_LOGDIR ) then
    if ( -e /jac_logs/oracdr ) then
        setenv ORAC_LOGDIR /jac_logs/oracdr
    endif
endif

