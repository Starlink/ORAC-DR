# Must be an ARC observation for CGS4
# Note that this isnt necessarily true for Michelle
# Leave this in for UIST for now.
HIERARCH.ESO.DPR.TYPE eq 'ARC'

# Do not force a match on readout mode (PH,THK)
# but it's nice to have it in the index file
HIERARCH.ESO.DPR.TECH

# Do NOT requre a match on filter

# CNFINDEX must match, unconditionally (PH,THK)
# Not for UIST
#HIERARCH.ESO.INS.GRAT.ENC eq $Hdr{HIERARCH.ESO.INS.GRAT.ENC}

# Basic optical parameters must match
HIERARCH.ESO.INS.SLIT eq $Hdr{HIERARCH.ESO.INS.SLIT}
#CAMLENS eq $Hdr{CAMLENS}

# I suppose it should match readout areas (historic)
HIERARCH.ESO.DET.WIN.STARTX == $Hdr{HIERARCH.ESO.DET.WIN.STARTX}
HIERARCH.ESO.DET.WIN.STARTY == $Hdr{HIERARCH.ESO.DET.WIN.STARTY}
HIERARCH.ESO.DET.WIN.NX == $Hdr{HIERARCH.ESO.DET.WIN.NX}
HIERARCH.ESO.DET.WIN.NY == $Hdr{HIERARCH.ESO.DET.WIN.NY}

# Ensure ORACTIME goes into the rules file
ORACTIME
