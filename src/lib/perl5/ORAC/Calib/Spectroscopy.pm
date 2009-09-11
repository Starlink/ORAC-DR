package ORAC::Calib::Spectroscopy;

=head1 NAME

ORAC::Calib::Imaging - OIR Spectroscopy Calibration

=head1 SYNOPSIS

  use ORAC::Calib::Spectroscopy;

  $Cal = new ORAC::Calib::Spectroscopy;

=head1 DESCRIPTION

Spectroscopy specific calibration methods.

=cut


# Calibration object for the ORAC pipeline

use strict;
use warnings;
use Carp;
use vars qw/$VERSION/;
use ORAC::Index;
use ORAC::Print;
use File::Spec;

use base qw/ ORAC::Calib::OIR /;

$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors( arc => {},
                                   arlines => { staticindex => 1, },
                                   calibratedarc => { staticindex => 1, },
                                   iar => {},
                                   profile => {},
                                   row => {},
                                   standard => {},
                                 );

=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Accessor Methods

=over 4

=cut

# Methods to access the data.
# ---------------------------

=item B<arc>

Return (or set) the name of the current arc.

  $arc = $Cal->arc;

Uses the nearest suitable calibration in time and croaks
if a calibration can not be found.

=cut

sub arc {
  my $self = shift;
  return $self->GenericIndexAccessor( "arc", 0, 0, 0, 1, @_ );
}

=item B<arlines>

Returns the name of a suitable arlines file.

Uses the closest previous observation and croaks if no suitable
file can be found.

=cut

sub arlines {
  my $self = shift;

  return $self->GenericIndexAccessor( "arlines", -1, 0, 0, 1, @_ );
}

=item B<calibratedarc>

Returns the name of a suitable calibrated arc file. If no suitable calibrated
arc file can be found, this method returns <undef> rather than croaking as
other calibration options do. This is so this calibration can be skipped if
no calibration arc can be found.

Uses the closest previous observation.

=cut

sub calibratedarc {
  my $self = shift;
  return $self->GenericIndexAccessor( "calibratedarc", -1, 1, 0, 1, @_ );
}

=item B<iar>

Returns the name of a suitable Iarc file.

Uses the closest relevant calibration and croaks if none can be found.

=cut

sub iar {
  my $self = shift;
  return $self->GenericIndexAccessor( "iar", 0, 0, 0, 1, @_ );
}

=item B<profile>

Return (or set) the name of the current profile

   $profile = $Cal->profile;

Uses the closest relevant calibration and croaks if none can be found.

=cut

sub profile {
  my $self = shift;
  return $self->GenericIndexAccessor( "profile", 0, 0, 0, 1, @_ );
}

=item B<rows>

Returns the relevant extraction rows to the caller by comparing
the index entries with the current frame. Suitable
values will be found or the method will abort.

Returns two numbers, the maximum number of beams expected
and a an array of hashes describing the beams that were detected.

  my ($nbeams, @beams) = $Cal->rows;

Returns undef and an empty list and prints a warning if the row can
not be determined from the index file.

Can not be used to set the name of the index key. Use the C<rowname>
method for that.

=cut

sub rows {
  my $self = shift;

  # Compare the current value with the index entry
  my $rowname = $self->rowname;
  my $ok = $self->rowindex->verify( $rowname, $self->thing );

  # If this was not okay we need to search the index
  unless ($ok) {

    $rowname = $self->rowindex->choosebydt('ORACTIME', $self->thing);

    if (defined $rowname) {
      # Store it
      $self->rowname( $rowname );
    } else {
      orac_warn "No suitable row could be found in index file\n";
    }

  }

  # Retrieve the NBEAMS and BEAMS from the index
   my ($nbeams, @beams);
   if (defined $rowname) {

     my $entry = $self->rowindex->indexentry($rowname);
     # Sanity check
     croak "BEAMS could not be found in index entry $rowname\n" 
       unless (exists $entry->{BEAMS});
     croak "NBEAMS could not be found in index entry $rowname\n" 
       unless (exists $entry->{NBEAMS});
     $nbeams = $entry->{NBEAMS};
     @beams = @{$entry->{BEAMS}};
   } else {
     # Could not find it
     $nbeams = undef;
     @beams = ();
   }
   return ( $nbeams, @beams );
}

=item B<standard>

Return (or set) the name of the current standard.

  $standard = $Cal->standard;

Returns the closest standard and croaks if none can be found.

=cut

sub standard {
  my $self = shift;
  return $self->GenericIndexAccessor( "standard", 0, 0, 0, 1, @_ );
}

=back

=head2 Support Methods

Each of the methods above has a support implementation to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

rowname() returns the name of the key to use in the index file to retrieve
the currently accepted positions of the positive and negative row.
The value should be compared with the current frame header in order
to guarantee its suitability. The name is usually the name of the
observation frame used to calculate the row positions.

=head1 SEE ALSO

L<ORAC::Calib::Imaging>, L<ORAC::Calib::OIR> and
L<ORAC::Calib>.

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>,
Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>, and
Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council.
Copyright (C) 1998-2004 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
