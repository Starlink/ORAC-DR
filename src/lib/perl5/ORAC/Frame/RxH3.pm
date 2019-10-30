package ORAC::Frame::RxH3;

=head1 NAME

ORAC::Frame::RxH3 - Frame class for RxH3

=cut

use strict;
use warnings;

use Carp;

use ORAC::Frame::NDF;

use base qw/ORAC::BaseFITSorNDF ORAC::Frame/;

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

1;

__END__

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
