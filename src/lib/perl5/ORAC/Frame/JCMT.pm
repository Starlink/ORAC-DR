package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::UKIRT;

  $Obs = new ORAC::Frame::JCMT("filename");
  $Obs->file("file")
  $Obs->readhdr;
  $Obs->configure;
  $value = $Obs->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to JCMT. It provides a class derived from ORAC::Frame.
All the methods available to ORAC::Frame objects are available
to ORAC::Frame::JCMT objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.004;
use ORAC::Frame;

# Let the object know that it is derived from ORAC::Frame;
@ORAC::Frame::JCMT::ISA = qw/ORAC::Frame/;


# standard error module and turn on strict
use Carp;
use strict;

use NDF; # For fits reading


=item readhdr

Reads the header from the observation file (the filename is stored
in the object). The reference to the header hash is returned.
This method does not set the header in the object (in general that
is done by configure() ).

    $hashref = $Grp->readhdr;

If there is an error during the read a reference to an empty hash is 
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

There are no input arguments.

=cut

sub readhdr {
 
  my $self = shift;
  
  # Just read the NDF fits header
  my ($ref, $status) = fits_read_header($self->file);
 
  # Return an empty hash if bad status
  $ref = {} if ($status != &NDF::SAI__OK);
 
  return $ref;
}


=item findgroup

Return the group associated with the Frame. This currently
returns a constant. Will in future query an INDEX file
to determine the group

=cut

# Supply a new method for finding a group

sub findgroup {

  my $self = shift;

  return '0025';

}


=head1 NEW METHODS FOR JCMT

This section describes methods that are available in addition
to the standard methods found in ORAC::Frame.

=cut

=item setsubinst

Forces the object to determine the names of all sub-instruments
associated with the data. The result can be retrieved via the
subinst() method.

=cut

sub setsubinst {
  my $self = shift;

  my $nsubs = $self->hdr('N_SUBS');

  my @subs = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'SUB_' . $i;

    push(@subs, $self->hdr($key));
  }

  # Should now set the value in the object!

  return @subs;
}



=item setlambda

Forces the object to determine the filters
of each sub-instrument. 
Need to think about how the object stores multiple sub-instruments.


=cut


sub setfilt {
  my $self = shift;

  my $nsubs = $self->hdr('N_SUBS');

  my @filter = ();
  for (my $i =1; $i <= $nsubs; $i++) {
    my $key = 'FILT_' . $i;

    push(@filter, $self->hdr($key));
  }

  return @filter;
}



=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=over 4

=item stripfname

Method to strip file extensions from the filename string. This method
is called by the file() method. For UKIRT we strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name.

=cut

sub stripfname {
 
  my $self = shift;
 
  my $name = shift;
 
  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//;
  
  return $name;
}
 

=back

=head1 REQUIREMENTS

This module requires the NDF module.

=head1 SEE ALSO

L<ORAC::Frame>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=cut




1;
