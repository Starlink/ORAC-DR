package ORAC::Recipe::Primitive;

=head1 NAME

ORAC::Recipe::Primitive - Object associated with specific primitive

=head1 SYNOPSIS

  use ORAC::Recipe::Primitive;

  $prim = ORAC::Recipe::Primitive->new( name => $name,
                                        path => $path,
                                        content => \@lines,
                                        code => $coderef,
                                        mtime => $modtime );

=head1 DESCRIPTION

Store all information about a specific primitive.

=cut

use strict;
use warnings;
use Carp;

use File::Basename;

our $VERSION = '1.0';

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Construct a C<ORAC::Recipe::Primitive>. Takes a hash list where keys
correspond to attribute accessor methods (case insensitive).

  $prim = ORAC::Recipe::Primitive->new( %arguments );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $prim = bless {
                    Name => undef,
                    Path => undef,
                    Code => undef,
                    Content => [],
                    OriginalContent => [],
                    Children => [],
                    ModificationTime => undef,
                   }, $class;

  my %args = @_;
  for my $key (keys %args) {
    my $method = lc( $key );
    $prim->$method( $args{$key} ) if $prim->can($method);
  }

  return $prim;
}

=back

=head2 Accessor Methods

=over 4

=item B<code>

Set or return the coderef containing the full code of the recipe.

  $code = $prim->code;
  $prim->code( sub { ... } );

Returns a coderef. Returns undef if the content has not yet been
compiled.

=cut

sub code {
  my $self = shift;
  if( @_ ) { 
    my $c = shift;
    croak "Not a coderef" unless ref($c) eq "CODE";
    $self->{Code} = $c;
  };
  return $self->{Code};
}

=item B<path>

Set or return full path to the primitive (including the primitive name).

  $prim->path( $path );
  $path = $prim->path;

If C<name> is not set, it will be determined from the path.

=cut

sub path {
  my $self = shift;
  if (@_) {
    my $path = shift;
    $self->{Path} = $path;
    if (defined $path && !defined $self->name) {
      $self->name( basename( $path ) );
    }
  }
  return $self->{Path};
}


=item B<content>

Set or retrieve the content of the primitive. Stored as a reference
to an array of text (one entry per line in the primitive). The code
should be directly comparable to the compiled coderef (and so should
include any expanded macros inserted by the parser).

  $prim->content( \@lines );
  $prim->content( @lines );
  @lines = $prim->content;

=cut

sub content {
  my $self = shift;
  if (@_) { 
    my @lines;
    if (ref($_[0]) && ref($_[0]) eq 'ARRAY') {
      @lines = @{$_[0]};
    } else {
      @lines = @_;
    }
    chomp(@lines);
    $self->{Content} = \@lines;
  }
  return @{$self->{Content}};
}

=item B<original>

The original content of the primitive. No code has been added. This
allows for simpler primitive dumping and line number checking.

Interface is identical to C<content>

=cut

sub original {
  my $self = shift;
  if (@_) { 
    my @lines;
    if (ref($_[0]) && ref($_[0]) eq 'ARRAY') {
      @lines = @{$_[0]};
    } else {
      @lines = @_;
    }
    chomp(@lines);
    $self->{OriginalContent} = \@lines;
  }
  return @{$self->{OriginalContent}};
}

=item B<children>

List of child primitives called by this primitive.

  @childprims = $prim->children();
  $prim->children( @childprims );

These are the primitive names not primitive objects (since the choice
of primitive is determined at run time).

=cut

sub children {
  my $self = shift;
  if (@_) {
    @{$self->{Children}} = @_;
  }
  return @{ $self->{Children} };
}

=item B<mtime>

Set or return the modification time of the primitive. Can be used to
check if a primitive has changed on disk since it was last parsed.

  my $modtime = $prim->mtime;
  $prim->mtime(  );

=cut

sub mtime {
  my $self = shift;
  if( @_ ) { $self->{ModificationTime} = shift; }
  return $self->{ModificationTime};
}

=item B<name>

Return (or set) the name of the primitive (not including path information)

  $name = $prim->name;
  $prim->name("_PRIMITIVE_NAME_");

=cut

sub name {
  my $self = shift;
  if (@_) { $self->{Name} = shift };
  return $self->{Name};
}

=back

=head2 General Methods

=over 4



=back

=head1 SEE ALSO

L<ORAC::Recipe::PrimitiveParser>, L<ORAC::Recipe>

=head1 REVISION

$Id: BaseFile.pm 7256 2007-11-28 02:39:22Z timj $

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
