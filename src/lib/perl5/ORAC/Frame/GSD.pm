package ORAC::Frame::GSD;

=head1 NAME

ORAC::Frame::GSD - Class for dealing with frames based on GSD files

=head1 SYNOPSIS

  use ORAC::Frame::GSD;

  $Frm = new ORAC::Frame::GSD;

=head1 DESCRIPTION

This class provides implementations of the methods that require
knowledge of the GSD file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Frame) rather than directly from
ORAC::Frame.

The format specific sub-classes do not contain constructors; they
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use ORAC::Frame;
use ORAC::Error qw/ :try /;

# Inherit from ORAC::BaseGSD and ORAC::Frame
use base qw/ ORAC::BaseGSD ORAC::Frame /;

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

  # First check to see if the file exists. If it does,
  # unlink it. If not, try appending a '.dat' and unlinking
  # that.
  my $status;
  if( -e $file ) {
    $status = unlink $file;
  } elsif ( $file !~ /\./) {
    $file .= ".dat";
    $status = unlink $file;
  }

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;

}

=item B<file_exists>

Checks for the existence of the frame file(). Assumes a C<.dat>
extension.

  $exists = $Frm->exists( $i );

The optional argument specifies the file number to be used.

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file(@_);

  # Strip anything after the first dot (in case extensions already
  # exist).
  $file =~ s/\..*$//;

  # Check for file existence.
  if ( -e "$file.dat" ) {
    return 1;
  } else {
    return 0;
  }
}

=back

=head1 SEE ALSO

L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
