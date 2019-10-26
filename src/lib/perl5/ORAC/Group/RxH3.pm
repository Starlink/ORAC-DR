package ORAC::Group::RxH3;

=head1 NAME

ORAC::Group::RxH3 - Group class for RxH3

=cut

use strict;
use warnings;

use Carp;

use base qw/ORAC::BaseFITSorNDF ORAC::Group/;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(@_);

  $self->fixedpart('grxh3');
  $self->filesuffix('.sdf');

  return $self;
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
