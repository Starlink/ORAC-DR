# Rules file for spectroscopic extraction of rows
# Nowadays, we store the actual row numbers in the header of the 
# group frame, along with the multipliers and nbeams.
ORACTIME
BEAM_NUMBER == $Hdr{'BEAM_NUMBER'}
STANDARD == 1
