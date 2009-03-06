
git branch | grep '^\*' | sed 's,\* ,,' ; \
git rev-parse --verify HEAD
git log -n 1 HEAD --pretty=format:%cd --date=iso
