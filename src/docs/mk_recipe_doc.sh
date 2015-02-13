#!/usr/bin/env bash

set -e

# starlink commands should raise an error.
ADAM_ERROR=1


# Simple script to convert the ORAC-DR recip 'pods' to 'SST' and then to sst-latex

#
rm -f tmp.sst tmp.tex

# Read in instrument name and sun name from command line
INSTRUMENT=$1
sun=$2

# Get the 'special' list of nonscience recipes.
if [ -e "nonscience_recipes" ]; then
    echo "nonscience_recipes exists"
    nonscience=`cat nonscience_recipes`
else
    nonscience=""
fi


# Function to print symlink stub: must include the name+path of the recipe
# as 1st parameter, and the name of the SUN it is in as the second parameter
function echo_sst_stub()
{
    echo "variables are" $1 $2 $3
    # First check if its a symlink.
    if [ -h $1 ]; then
	dest=$(readlink $1)
	namedest=$(basename $dest)
	name=$(basename $1)

	name_escaped="${name//_/\_}"
	dest_escaped="${namedest//_/\_}"
	result=$"\sstroutine{\n
$name_escaped\n
}{\n
alias for $dest_escaped\n
}{\n
\sstdescription{This recipe is an alias for
the recipe
\\xref{$dest_escaped}{$2}{$dest_escaped}.}\n
}\n"
	echo -e $result >> "$3".tex
    else
	pod2sst $1 > tmp.sst
	$STARLINK_DIR/bin/sst/prolat tmp.sst tmp.tex single=false page=false document=false
	echo "$3".tex
	cat tmp.tex >> "$3".tex
	rm -f tmp.sst tmp.tex
    fi
}

# Go through recipes.
RECIPEDIR="$ORAC_RECIPEDIR/$INSTRUMENT"
echo "recipdir is  $RECIPEDIR"
# OUTPUT files
# sstfiles
echo $RECIPEDIR

# Clean out old files
rm -f nonscience.tex fts.tex pol.tex summit.tex quicklook.tex obsolete.tex mainrecipes.tex

# Go through each file
for i in $RECIPEDIR/* ; do
    name=$(basename "$i")
    echo $name
    # Don't do anything for directories.
    if [ -d $i ]; then
	echo "$i is a directory"

    # Don't do anything if filename contains a ~
    elif [[ $name =~ "~" ]]; then
	echo $name
    # Non science recipes
    elif [[ $nonscience =~ $name ]]; then
	echo $name " NOT SCIENCE"
	echo_sst_stub $i $sun "nonscience"

    # FTS recipes
    elif [[ $INSTRUMENT == SCUBA2 ]] && [[ $name =~ REDUCE_FTS_ ]]; then
	    echo $name " FTS"
	    echo_sst_stub $i $sun "fts"


    # POL recipes
    elif [[ $INSTRUMENT == SCUBA2 ]] && [[ $name =~ REDUCE_POL_ ]] ; then
	    echo $name " POL"
	    echo_sst_stub $i $sun "pol"

    # SUMMIT recipes -- separate file. (end in _SUMMIT)
    elif [[ $name =~ _SUMMIT ]]; then
	echo $name " SUMMIT"
	echo_sst_stub $i $sun "summit"

    # QUICKLOOK recipes -- separate file (end in _QL)
    elif [[ $name =~ _QL ]]; then
	echo $name " QL"
	echo_sst_stub $i $sun "quicklook"

    # OBSOLETE recipes (start with obsolete)
    elif [[ $name =~ OBSOLETE_ ]]
	then
	echo $name " OBSOLETE"
	echo_sst_stub $i $sun "obsolete"

    else
	echo $name " MAIN"
	echo_sst_stub $i $sun "mainrecipes"
    fi
done;

# Now go through each subdirectory
for i in $(find $RECIPEDIR/* -type d); do
    echo "directory is $i";
    dirname=$(basename $i)
    rm -f $dirname.tex
    # Go through each recipe in subdirectory
    for j in $i/*; do
	echo_sst_stub $j $sun $dirname
    done
done


