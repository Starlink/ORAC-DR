# Must be an ARC observation for CGS4
# Note that this isnt necessarily true for Michelle
OBSTYPE eq 'ARC'

# Do not force a match on readout mode (PH,THK)
# but it's nice to have it in the index file
METHOD

# Do NOT requre a match on filter

# I suppose it should match readout areas (historic)
DETECXS <= $Hdr{DETECXS}
DETECXE >= $Hdr{DETECXE}
DETECYS <= $Hdr{DETECYS}
DETECYE >= $Hdr{DETECYE}

# Ensure ORACTIME goes into the rules file
ORACTIME
