package ORAC::Frame::NDF;

=head1 NAME

ORAC::Frame::NDF - Class for dealing with frames based on NDF files

=head1 SYNOPSIS

  use ORAC::Frame::NDF

  $Frm = new ORAC::Frame::NDF;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the NDF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Frame) rather than directly from
ORAC::Frame. For JCMT and UKIRT the group files are based on NDFs and
inherit from this class.

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use ORAC::Frame;
use ORAC::Error qw/ :try /;

# Inherit from ORAC::Frame
# BaseNDF is ahead of ORAC::Frame because we need to use readhdr
# from the NDF base rather than the file Base.
use base qw/ORAC::BaseNDF ORAC::Frame /;

use warnings;
use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<erase>

Erase the current file from disk.

  $Frm->erase($i);

The optional argument specifies the file number to be erased.
The argument is identical to that given to the file() method.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

Note that the file() method is not modified to reflect the
fact the the file associated with it has been removed from disk.

This method is usually called automatically when the file()
method is used to update the current filename and the nokeep()
flag is set to true. In this way, temporary files can be removed
without explicit use of the erase() method. (Just need to
use the nokeep() method after the file() method has been used
to update the current filename).

=cut

sub erase {
  my $self = shift;

  # Retrieve the necessary frame name
  my $file = $self->file(@_);

  # Append the .sdf if required
  $file .= '.sdf' unless $file =~ /\.sdf$/;
 
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

}


=item B<file_exists>

Checks for the existence of the frame file(). Assumes a C<.sdf>
extension.

  $exists = $Frm->exists($i)

The optional argument specifies the file number to be used.
All extension are removed from the file name before adding the
C<.sdf> so that HDS containers can be supported (and files
that already have the extension)  -- but note that
this version of the method does not look inside HDS containers
looking for NDFs.

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file(@_);

  # Strip anything after the first dot (in case extensions already
  # present)
  $file =~ s/\..*$//;

  # Check for file existence
  if (-e "$file.sdf") {
    return 1;
  } else {
    return 0;
  }
}

=back

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::BaseNDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
