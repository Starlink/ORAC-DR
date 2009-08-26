#+

# Check to see if we're at JCMT. If we are, then create the
# ORAC_DATA_OUT directory.
set jcmt = ''
if ($?SITE) then
  if ($SITE == 'jcmt') then
     set jcmt = $SITE
  endif
endif
if ( $jcmt != '' ) then
  if ( ! -d $ORAC_DATA_OUT ) then

    umask 002

    echo "CREATING OUTPUT DIRECTORY: $ORAC_DATA_OUT"

    mkdir $ORAC_DATA_OUT
   # Set the sticky bit for group write
   # Need to rsh to the NFS server of the partition of it is not local

    # check if ORAC_DATA_OUT is an NFS-mounted partition -

    set df_out = `df -t nfs $ORAC_DATA_OUT | wc -l`

    # if it is 1 that's just the df header, so we're local
    # if it is 3 we're NFS
    # if it is anything else, the df format is not what we thought it was

    if ($df_out == 1) then

      chmod g+rws $ORAC_DATA_OUT

    else if ($df_out > 1) then

      # get the name of the NFS host
      set nfs_host  = `df -t nfs $ORAC_DATA_OUT | head -2 | tail -1 | awk -F: '{print $1}'`
      # do the deed
      rsh $nfs_host chmod g+rws $ORAC_DATA_OUT
      # whinge to user
      echo '***************************************************'
      echo '* Your ORAC_DATA_OUT is not local to your machine  '
      echo '* If you intend to run ORAC-DR you should be       '
      echo "* using $nfs_host instead, which is where          "
      echo "* $ORAC_DATA_OUT is located *"
      echo '***************************************************'
    else

      echo Unable to establish whether $ORAC_DATA_OUT is local or remote
      echo Please report this error to the JAC software group

    endif
  endif
endif
