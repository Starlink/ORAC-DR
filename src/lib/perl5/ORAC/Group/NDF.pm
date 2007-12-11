package ORAC::Group::NDF;

=head1 NAME

ORAC::Group::NDF - Class for dealing with groups based on NDF files

=head1 SYNOPSIS

  use ORAC::Group::NDF

  $Grp = new ORAC::Group::NDF;

=head1 DESCRIPTION

This class rovides implementations of the methods that require
knowledge of the NDF file format rather than generic methods or
methods that require knowledge of a specific instrument.  In general,
the specific instrument sub-classes will inherit from the file type
(which inherits from ORAC::Group) rather than directly from
ORAC::Group. For JCMT and UKIRT the group files are based on NDFs and
inherit from this class.

The format specific sub-classes do not contain constructors; they 
should be defined in either the base class or the instrument specific
sub-class.

=cut

use 5.006;
use warnings;
use ORAC::Group;

# Inherit from ORAC::Group
# BaseNDF is ahead of ORAC::Group because we need to use readhdr
# from the NDF base rather than the file Base.
use base qw/ORAC::BaseNDF ORAC::Group /;

use strict;
use Carp;
use ORAC::Constants qw/:status/;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# We need to read NDF files
use NDF;

=head1 PUBLIC METHODS

The following methods are modified from the base class versions.

=head2 General Methods

=over 4

=item B<coaddsread>

Method to read the COADDS information from the group file. If the
Group file exists, the file is opened and the L<.ORAC> extension is
located. The .COADDS component (ie groupfile.MORE.ORAC.COADDS) is then
opened as _INTEGER and the contents are stored in the group using the
coadds() method. If a .MORE.ORAC.COADDS component can not be found (e.g.
because the file or component do not exist), the routine returns
ORAC__ERROR, else returns ORAC__OK.

  $Grp->coaddsread;

There are no arguments.

=cut

sub coaddsread {
  my $self = shift;

  # Check to see if the file is there
  if ($self->file_exists) {

    # Flag to indicate whether we have successfully read a .COADDS
    my $read_coadds = 0;

    # Get a Starlink status
    my $status = &NDF::SAI__OK;

    # Attempt to open the file
    ndf_begin();
    ndf_find(&NDF::DAT__ROOT(), $self->file, my $indf, $status);

    # Is there a .ORAC extension?
    ndf_xstat($indf, 'ORAC', my $orac_there, $status);

    if ($orac_there) {

      # Find the .ORAC extension
      ndf_xloc($indf, 'ORAC', 'READ', my $xloc, $status);

      # Is there a .COADDS
      dat_there($xloc, 'COADDS', my $coadds_there, $status);

      if ($coadds_there) {

	# Read the .COADDS array
	my (@coadds, $el);
	cmp_getvi($xloc, 'COADDS', 10000, @coadds, $el, $status);

	# Store the coadds if good status
	if ($status == &NDF::SAI__OK) {
	  $self->coadds(@coadds);
	  $read_coadds = 1;
	}
      }

      dat_annul($xloc, $status);
    }

    ndf_annul($indf, $status);
    ndf_end($status);

    # If we managed to read something, return good
    return ORAC__OK if $read_coadds;

  }
  return ORAC__ERROR;
}


=item B<coaddswrite>

Writes the current contents of coadds() into the current group file().
Returns ORAC__OK if the coadds information was written successfully,
else returns ORAC__ERROR.

  $Grp->coaddswrite;

There are no arguments. The information is written to a .ORAC.COADDS
component in the Group file.  If coadds() contains no entries, all
coadds information is removed from the group file if present (and good
status is returned). A .ORAC extension is always made if one does not
exist and the file is present.

=cut

sub coaddswrite {
  my $self = shift;

  my $write_coadds = 0;
  # Check to see if the file is there
  if ($self->file_exists) {

    # Status
    my $status = &NDF::SAI__OK;

    # First we need to open the file for write access
    my ($indf, $place, $xloc);
    ndf_begin();
    ndf_open(&NDF::DAT__ROOT(), $self->file, 'UPDATE','OLD', $indf, $place,
	     $status);

    # Look for an ORAC extension
    ndf_xstat($indf, 'ORAC', my $orac_there, $status);

    # Create one if necessary, else get a locator
    if ($orac_there) {
      ndf_xloc($indf, 'ORAC', 'UPDATE', $xloc, $status);
    } else {
      my @null;
      ndf_xnew($indf, 'ORAC', 'ORAC_EXT', 0, @null, $xloc, $status);
    }

    # Look for the .COADDS component
    dat_there($xloc, 'COADDS', my $coadds_there, $status);

    # If it is there remove it
    dat_erase($xloc, 'COADDS', $status) if ($coadds_there);

    # Read the contents of coadds()
    my @coadds = $self->coadds;

    # Only write something there if we actually have some numbers to write
    if ($#coadds > -1) {
      my @ubnd = (scalar(@coadds));
      cmp_mod($xloc, 'COADDS', '_INTEGER', 1, @ubnd, $status);
      cmp_putvi($xloc, 'COADDS', scalar(@coadds), @coadds, $status);
    }

    # If we have got this far with good status we can set the write
    # flag to true
    $write_coadds = 1 if $status == &NDF::SAI__OK;

    # Annul the extension locator
    dat_annul($xloc, $status);

    # Close down NDF
    ndf_annul($indf, $status);
    ndf_end($status);

    # If we managed to write something, return good
    return ORAC__OK if $write_coadds;

  }
  return ORAC__ERROR;
}


=item B<erase>

Erases the current group file. Assumes a C<.sdf> extension.
Returns ORAC__OK if successful, ORAC__ERROR otherwise.

=cut

sub erase {
  my $self = shift;

  my $file = $self->file() . ".sdf";
  my $status = unlink $file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}

=item B<file_exists>

Checks for the existence of the Group file(). Assumes a C<.sdf>
extension.

=cut

sub file_exists {
  my $self = shift;
  my $file = $self->file;

  # Strip anything after the first dot, in case extension is present.
  $file =~ s/\..*$//;

  if (-e "$file.sdf") {
    return 1;
  } else {
    return 0;
  }
}

=back

=head1 REQUIREMENTS

This module requires the L<NDF> module.

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::BaseNDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2002 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
