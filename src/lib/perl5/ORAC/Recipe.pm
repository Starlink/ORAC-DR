package ORAC::Recipe;

=head1 NAME

ORAC::Recipe - Recipe parsing and execution

=head1 SYNOPSIS

  use ORAC::Recipe;

  $r = new ORAC::Recipe( $recipe, $instrument );

  $r->instrument( $instrument );
  $r->read_recipe(RECIPE => $recipe,
                  INSTRUMENT => $instrument);
  $r->parse;
  $r->post_process;
  $r->execute( $Frm, $Grp, $Cal, \%Mon);

=head1 DESCRIPTION

Class for reading, parsing and executing ORAC-DR recipes.


=cut

use strict;
use Carp;
use File::Spec;  # For pedants everywhere
use IO::File;    # until perl5.6 is guaranteed

use ORAC::Constants qw/ :status /;

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

The constructor instantiates a new object and, if the recipe name and
instrument are given, reads the recipe from disk.

  $r = new ORAC::Recipe;
  $r = new ORAC::Recipe( NAME => $name, INSTRUMENT => $instrument );

The instrument name is required in order to configure the recipe
search path.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Init the data structure
  my $rec = {
	     Instrument => undef,
	     RecipeName => undef,
	     ParsedRecipe => [],
	     HaveParsed => 0, # indicate it is ready for execution
	    };

  # bless into the correct class
  bless( $rec, $class);

  # Check for arguments
  if ( @_ == 2) {
    my %args = @_;
    if (exists $args{NAME} && exists $args{INSTRUMENT}) {
      $rec->read_recipe(%args);
    }
  }

  return $rec;
}

=back

=head2 Accessor Methods

=over 4

=item B<instrument>

Set or return the instrument name. This is required to configure
search paths to determine recipe and primitive location.

  $inst = $rec->instrument;

=cut

sub instrument {
  my $self = shift;
  if (@_) { $self->{Instrument} = shift };
  return $self->{Instrument};
}

=item B<recipe_name>

Return (or set) the name of the recipe to be processed.

  $name = $rec->recipe_name;
  $rec->recipe_name("REDUCE_DARK");

=cut

sub recipe_name {
  my $self = shift;
  if (@_) { $self->{RecipeName} = shift };
  return $self->{RecipeName};
}


# Internal access to parsed recipe
# Returns the array reference.

sub _recipe {
  return $self->{ParsedRecipe};
}

# Flag to indicate the recipe has been parsed and the
# primitives expanded.

sub have_parsed {
  my $self = shift;
  if (@_) { $self->{HaveParsed} = shift };
  return $self->{HaveParsed};
}


=back

=head2 General Methods

=over 4

=item B<read_recipe>

Read the recipe from disk. The recipe must then be parsed
to insert the primitive code.

  $rec->read_recipe( NAME => "REDUCE_DARK",
                     INSTRUMENT => "IRCAM" );

The arguments are optional if the C<instrument> or C<recipe_name>
methods have been set previously and override previous values.

The search path is set from the instrument name and from the
C<ORAC_RECIPE_DIR> environment variable.

Croaks if the recipe could not be found or opened. Returns ORAC__OK
on success.

=cut

sub read_recipe {
  my $self = shift;
  my %args;
  %args = @_ if @_;

  # Read instrument and recipe name from args or object
  my ($name, $inst);
  if ( exists $args{NAME} ) {
    $name = $args{NAME};
    $self->recipe_name($name); # update object
  } elsif (defined $self->recipe_name) {
    $name = $self->recipe_name;
  } else {
    croak "read_recipe: No recipe NAME supplied. Aborting";
  }
  if ( exists $args{INSTRUMENT} ) {
    $inst = $args{INSTRUMENT};
    $self->instrument($name); # update object
  } elsif (defined $self->recipe_name) {
    $inst = $self->recipe_name;
  } else {
    croak "read_recipe: No recipe INSTRUMENT supplied. Aborting";
  }

  # Arguments are okay. Now need to determine search path.
  my @path;

  # ORAC_RECIPE_DIR should be at start of path
  push( @path, $ENV{ORAC_RECIPE_DIR}) 
    if (exists $ENV{ORAC_RECIPE_DIR} && -d $ENV{ORAC_RECIPE_DIR});

  # Instrument specific search path
  push(@path, orac_determine_recipe_search_path( $instrument ));

  # If the path array is empty add cwd (should not happen in oracdr
  @path = ( File::Spec->curdir ) unless @path;

  # Now search the directory structure for NAME
  my $fh = $self->_search_path( \@path, $name);

  if (defined $fh) {

    my @contents = <$fh>;

    # Store the contents in the object
    @{ $self->_recipe } = <$fh>;

  } else {
    my $str = join("\n", @path);
    croak "Could not find and open recipe $name in any of\n$str\n";
  }

  return ORAC__OK;
}


=item B<parse>

Parses the recipe read via C<read_recipe>, reading in the
necessary primitives.

  $rec->parse();


=back

=begin __PRIVATE_METHODS__

=head2 Private methods

These methods are for internal use only.

=over 4

=item B<_search_path>

Search for file in search path and open it for read. Return
the file handle or C<undef> on error.

  my $fh = _search_path( \@path, $name );

The search path is specified as a reference to an array of directories.

=cut

sub _search_path {
  my $self = shift;

  for my $dir ( @{ $_[0] } ) {
    my $file = File::Spec->catfile($dir, $_[1]);
    if (-e $file) {
      my $fh = new IO::File( "< $file");
      return $fh if defined $fh;
    }
  }
  return undef;
}


=end __PRIVATE_METHODS__

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>


=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut



1;
