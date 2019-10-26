package ORAC::BaseFITSorNDF;

=head1 NAME

ORAC::BaseFITSorNDF - Base class for Frame/Group using FITS or NDF files

=head1 DESCRIPTION

This class is intended for instruments where a mixture of FITS and NDF
files are used.  For example, raw RxH3 data are FITS binary tables
but subsequent processing uses cubes and maps in NDF format.

=cut

use strict;
use warnings;

use ORAC::BaseFITS;

use base qw/ORAC::BaseNDF/;

sub readhdr {
    my $self = shift;
    my @files = @_ ? @_ : $self->files();
    return ORAC::BaseFITS::readhdr($self, @_) if @files and $files[0] =~ /\.fits$/;
    return $self->SUPER::readhdr($self, @_);
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
