# Do NOT requre a match on filter

# CNFINDEX must match, unconditionally (PH,THK)
CNFINDEX eq $Hdr{CNFINDEX}

# I suppose it should match readout areas (historic)
RDOUT_X1 == $Hdr{RDOUT_X1}
RDOUT_X2 == $Hdr{RDOUT_X2}
RDOUT_Y1 == $Hdr{RDOUT_Y1}
RDOUT_Y2 == $Hdr{RDOUT_Y2}

# The arc sampling must be AS_OBJECT (PH)
SAMPLING eq $Hdr{SAMPLING}

# Ensure ORACTIME goes into the rules file
ORACTIME
