# Rules file for CGS4 extraction rows
# Nowadays, we store the actual row numbers in the header of the group frame, along with the multipliers and nbeams.

ORACTIME
BEAM_NUMBER == $Hdr{'BEAM_NUMBER'}
CNFINDEX == $Hdr{'CNFINDEX'}
DRRECIPE eq 'STANDARD_STAR'


