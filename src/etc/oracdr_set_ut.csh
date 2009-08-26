#
if ($1 != "") then
    echo $1
else
    echo `\date -u +%Y%m%d`
endif
