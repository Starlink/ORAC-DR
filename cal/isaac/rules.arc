# Must be an ARC observation for CGS4
# Note that this isnt necessarily true for Michelle
# Leave this in for UIST for now.
DPRTYPE eq 'ARC'

# Do not force a match on readout mode (PH,THK)
# but it's nice to have it in the index file
DETMODE

# Do NOT requre a match on filter

# CNFINDEX must match, unconditionally (PH,THK)
# Not for UIST
#GRATENC eq $Hdr{GRATENC}

# Basic optical parameters must match
SLIT eq $Hdr{SLIT}
CAMLENS eq $Hdr{CAMLENS}

# I suppose it should match readout areas (historic)
STARTX == $Hdr{STARTX}
STARTY == $Hdr{STARTY}
WINNX == $Hdr{WINNX}
WINNY == $Hdr{WINNY}

# Ensure ORACTIME goes into the rules file
ORACTIME
