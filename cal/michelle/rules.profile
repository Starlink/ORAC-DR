# Rules file for Michelle extraction rows

# Nowadays, we store the actual row numbers in the header of the group
# frame, along with the multipliers and nbeams.
ORACTIME
BEAM_NUMBER == $Hdr{'BEAM_NUMBER'}
CNFINDEX == $Hdr{'CNFINDEX'}
RECIPE eq 'STANDARD_STAR'


