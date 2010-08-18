package ORAC::Group::MEF;

=head1 NAME

ORAC::Group::MEF - Class for dealing with groups based on MEF files

=head1 SYNOPSIS

  use ORAC::Group::MEF

  $Grp = new ORAC::Group::MEF;

=head1 DESCRIPTION

This class rovides implementations of the methods that require
knowledge of the MEF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Group) rather than directly from
ORAC::Group.

The format specific sub-classes do not contain constructors; they
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use warnings;
use ORAC::Group;

# Inherit from ORAC::Group
# BaseFITS is ahead of ORAC::Group because we need to use readhdr
# from the MEF base rather than the file Base.
use base qw/ORAC::BaseFITS ORAC::Group /;

use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<erase>

Erases the current group file container file.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

=cut

sub erase {
  my $self = shift;

  my $file;
  ($file = $self->file) =~ s/^(.*?)\[\d+\]$/$1/;
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}

=item B<file_exists>

Checks for the existence of the Group file. This doesn't check for the
existence of a FITS extension, but for the existence of the container file.

=cut

sub file_exists {
  my $self = shift;
  my $file;
  ($file = $self->file) =~ s/^(.*?)\[\d+\]$/$1/;
  if (-e $file) {
    return 1;
  } else {
    return 0;
  }
}

=back

=head1 REQUIREMENTS

None

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::BaseFITS>

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis E<lt>jrl@ast.cam.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2002-2006 Cambridge Astronomy Survey Unit
All Rights Reserved.


=cut

1;
