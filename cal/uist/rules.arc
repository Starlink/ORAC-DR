# Must be an ARC observation for CGS4
# Note that this isnt necessarily true for Michelle
# Leave this in for UIST for now.
OBSTYPE eq 'ARC'

# Do not force a match on readout mode (PH,THK)
# but it's nice to have it in the index file
DET_MODE

# Do NOT requre a match on filter

# CNFINDEX must match, unconditionally (PH,THK)
# Not for UIST
#CNFINDEX eq $Hdr{CNFINDEX}

# I suppose it should match readout areas (historic)
RDOUT_X1 == $Hdr{RDOUT_X1}
RDOUT_X2 == $Hdr{RDOUT_X2}
RDOUT_Y1 == $Hdr{RDOUT_Y1}
RDOUT_Y2 == $Hdr{RDOUT_Y2}

# Ensure ORACTIME goes into the rules file
ORACTIME
