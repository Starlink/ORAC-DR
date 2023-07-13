package ORAC::Frame::RxH3;

=head1 NAME

ORAC::Frame::RxH3 - Frame class for RxH3

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Astro::FITS::Header::CFITSIO;
use Carp;
use File::Spec;
use IO::Dir;
use IO::File;

use ORAC::Frame::NDF;

use base qw/ORAC::BaseFITSorNDF ORAC::Frame/;

our %_flag_files = ();

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = $class->SUPER::new();

    # Set up for NDF format so that no conversion occurs -- we will do this
    # as the first step using makeholomap.
    $self->rawfixedpart('rxh3');
    $self->rawsuffix('.sdf');
    $self->rawformat('NDF');
    $self->format('NDF');

    $self->configure(@_) if @_;

    return $self;
}

# Avoid grouping because we don't always have the necessary headers.
sub framegroupkeys {
  return ('DATE');
}

sub erase {
    ORAC::Frame::NDF::erase(@_);
}

sub inout {
    my $self = shift;
    my $suffix = shift;

    my $num = 1;
    if (@_) {
        $num = shift;
    }

    my $infile = $self->file(defined $num ? $num : ());

    my ($parts, undef) = $self->_split_fname( $infile );

    pop @$parts if $#$parts > 0;
    push @$parts, $suffix;

    my $outfile = $self->_join_fname($parts, '');

    # Generate a warning if output file equals input file.
    orac_warn("inout: output filename equals input filename ($outfile)\n")
        if $outfile eq $infile;

    return ($infile, $outfile) if wantarray();
    return $outfile;
}

=item B<flag_from_bits>

Determine the name of the flag file given the prefix (UT date)
and observation number.

    $flag = $Frm->flag_from_bits($prefix, $obsnum);

For RxH3 the flag file is of the form .rxh3-YYYYMMDD-HHMMSS.ok
where YYYYMMDD is the date and HHMMSS the time.  Therefore we
need to check the OBSNUM headers to find the relevant flag file.
If no file is found, a dummy flag file name is returned.

=cut

sub flag_from_bits {
    my $self = shift;
    my $prefix = shift;
    my $obsnum = shift;

    $self->_scan_flag_obsnum();

    foreach my $flag (keys %_flag_files) {
        my $info = $_flag_files{$flag};
        return $flag
            if $info->{'prefix'} eq $prefix
            and $info->{'obsnum'} == $obsnum;
    }

    return sprintf '.rxh3-dummy-%s-%05d.ok', $prefix, $obsnum;
}

=item B<pattern_from_bits>

Determine the pattern for the flag file given the prefix (UT date)
and observation number.

    $pattern = $Frm->pattern_from_bits($prefix, $obsnum);

Returns a regular expression based on the output of C<flag_from_bits>.

=cut

sub pattern_from_bits {
    my $self = shift;
    my $prefix = shift;
    my $obsnum = shift;

    my $pattern = $self->flag_from_bits($prefix, $obsnum);

    return qr/$pattern$/;
}

# Check $ORAC_DATA_IN for new flag files and update the
# %_flag_files hash to record their prefix and obsnum.

sub _scan_flag_obsnum {
    my $self = shift;

    my $dir_path = $ENV{'ORAC_DATA_IN'};
    my $dir = IO::Dir->new($dir_path);
    return unless defined $dir;

    while (defined (my $file = $dir->read())) {
        next if exists $_flag_files{$file};
        next unless $file =~ '^\.rxh3-(\d*)-\d*\.ok$';
        my $prefix = $1;
        my $file_path = File::Spec->catfile($dir_path, $file);
        my $fh = IO::File->new($file_path, 'r');
        next unless defined $fh;
        my $raw = <$fh>;
        $fh->close();
        chomp $raw;
        next unless $raw;
        my $raw_path = File::Spec->catfile($dir_path, $raw);
        my $hdr = Astro::FITS::Header::CFITSIO->new(File => $raw_path, ReadOnly => 1);
        next unless defined $hdr;
        my $obsnum = $hdr->value('OBSNUM');
        next unless defined $obsnum;
        $_flag_files{$file} = {prefix => $prefix, obsnum => $obsnum};
    }

    $dir->close();
}

1;

__END__

=back

=head1 COPYRIGHT

Copyright (C) 2019 East Asian Observatory
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc.,51 Franklin
Street, Fifth Floor, Boston, MA  02110-1301, USA

=cut
