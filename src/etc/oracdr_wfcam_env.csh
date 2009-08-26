#
if ( -e $ORAC_DATA_OUT/.. ) then
  setenv ORAC_RESPECT_RTD_REMOTE 1
  setenv RTD_REMOTE_DIR $ORAC_DATA_OUT/..
endif
