package ORAC::Recipe::Parameters;

=head1 NAME

ORAC::Recipe::Parameters - Handle recipe parameters

=head1 SYNOPSIS

  use ORAC::Recipe::Parameters;

  $par = ORAC::Recipe::Parameters->new( $file );
  %params = $par->for_recipe( $recipe );

=head1 DESCRIPTION

Handle the parsing and retrieval of recipe parameters for ORAC-DR
recipes.

=cut

use strict;
use warnings;
use vars qw/ $VERSION $DEBUG /;
use Carp;

use Data::Dumper;
use Config::IniFiles;
use File::Spec;

use ORAC::Print;

$DEBUG = 0;
$VERSION = '0.1';

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Create a new parameter object using the supplied file name as a source
of parameters. The file can be a fully specified path or else will assumed
to be found in the current directory, ORAC_DATA_OUT or ORAC_DATA_CAL.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $file = shift;

  my $obj = bless {
                   File => undef,
                   Parameters => {},
                   FixedParameters => undef,
                  }, $class;

  if (defined $file) {
    my $path = $obj->_locate_file( $file );
    print "PATH = ". (defined $path ? $path : "<undef>")."\n" if $DEBUG;
    return undef unless defined $path;

    # update filename and parse it
    $obj->filename( $path );
  }

  return $obj;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of the file containing the recipe parameters specification.

 $f = $par->filename();

The file will be parsed automatically and the object updated if
a value is set.

 $par->filename( $file );

=cut

sub filename {
  my $self = shift;
  if (@_) {
    $self->{File} = shift;
    $self->_parse_file;
  }
  return $self->{File};
}

=item B<fixed_parameters>

Set or return a hash reference of fixed parameters to be set for all
recipes.  Keys are converted to upper case.

=cut

sub fixed_parameters {
  my $self = shift;
  if (@_) {
    my $fixed = shift;
    my %clean = ();

    my ($key, $value);
    while (($key,$value) = each %$fixed) {
      $clean{uc($key)} = $value;
    }

    $self->{'FixedParameters'} = \%clean;
  }
  return $self->{'FixedParameters'};
}

=item B<recipe_name_from_params>

Given a translated header hash, see if the parameter
file contains an override for the recipe name.

  $recipe = $par->recipe_name_from_params( \%hdr );

Returns undef if no override is found.

The syntax for overriding a recipe name involves using the
ORAC_OBSERVATION_TYPE header, and optionally other filters in the section name.

Then the object (optionally with regexp in it is used to match.)

e.g., to set GRID observations of a specific transition to use
REDUCE_SCIENCE_BROADLINE for all sources except for OMC1 (where you
want to use REDUCE_SCIENCE_NARROWLINE), you would have a recipe
parameter file with:

  [RECIPES_GRID:#SPECIES=CS#TRANSITION=7 - 6]
  .*=REDUCE_SCIENCE_BROADLINE
  OMC1=REDUCE_SCIENCE_NARROWLINE

(A specific name will override a regexp, but if there are 2 regexps
that match than the first one that mathces will be used.)

If you wanted to match e.g. all sources beginnning with OMC, you would
do:

  OMC.*=REDUCE_SCIENCE_NARROWLINE

=cut

sub recipe_name_from_params {
  my $self = shift;
  my $hdr = shift;
  my $recname;


  if (exists $hdr->{ORAC_OBJECT} && defined $hdr->{ORAC_OBJECT}
      && exists $hdr->{ORAC_OBSERVATION_TYPE}
      && defined $hdr->{ORAC_OBSERVATION_TYPE} ) {


    my %allpars = $self->_parameters();

    my $key = "RECIPES_" . uc($hdr->{ORAC_OBSERVATION_TYPE});
    my %RecParsMatch = $self->_match_filters($key, $hdr);


    my %RecPars = ();
    foreach my $spec (sort {$a <=> $b} keys %RecParsMatch) {
        %RecPars = (%RecPars, %{$RecParsMatch{$spec}});

    }

    if (defined (keys %RecPars)) {


      my $object = uc($hdr->{ORAC_OBJECT});
      $object =~ s/\s//g;

      if (exists $RecPars{$object}) {
        # Shortcut the exact match
        $recname = $RecPars{$object};
      } else {
        # we have to go through item in the hash to
        # see if it matches the pattern of our object
        for my $cfgobj (keys %RecPars) {
          if ( $object =~ /^$cfgobj$/ ) {
            $recname = $RecPars{$cfgobj};
            last;
          }
        }
      }
    }
  }
  return $recname;
}

=item B<for_recipe>

Retrieves the parameters associated with a particular recipe.
Optionally a translated header hash can also be supplied to allow recipe/object
and other combinations.

 %params = $par->for_recipe( $recipe, \%hdr );

Will return an empty list if no parameters exist for the recipe
or if the recipe name is not defined.

RecipeObject parameters supercede Recipe parameters but
Recipe parameters will be included.

Whitespace is removed from the object name.

=cut


sub for_recipe {
  my $self = shift;
  my $rec = shift;
  my $hdr = shift || {};
  return () unless defined $rec;

  my %RecParsMatch = $self->_match_filters($rec, $hdr);

  # Apply recipe parameters in order of specificness.
  my %RecPars = ();
  foreach my $spec (sort {$a <=> $b} keys %RecParsMatch) {
    %RecPars = (%RecPars, %{$RecParsMatch{$spec}});
  }

  # Override with any fixed parameters.
  my $fixed = $self->fixed_parameters();
  %RecPars = (%RecPars, %$fixed) if defined $fixed;

  return %RecPars;
}

=item B<verify_parameters>

Check parameters retrieved by system against those that are allowed by
the recipe.

  verify_parameters( \%RECPARS, \@valid_params );

This function will print a warning if a parameter is in the parameter
ini file but not known to the recipe.

This function takes an array reference listing the valid parameters.

=cut

sub verify_parameters {
  my $recpars = shift;
  my $valid = shift;
  my %recpars_copy = %$recpars;
  foreach my $valid_par ( @$valid ) {
    if( defined( $recpars_copy{$valid_par} ) ) {
      delete $recpars_copy{$valid_par};
    }
  }
  foreach my $invalid ( sort keys %recpars_copy ) {
    orac_warn "Ignoring unsupported recipe parameter $invalid\n";
  }
}

=back

=begin __INTERNALS__

=head2 Internal Methods

=over 4

=item B<_parameters>

Parameters read from file, indexed by recipe name. Internal
routine to hide implementation.

  $par->_parameters( %config );
  %config = $par->_parameter();

Use C<for_recipe> method to retrieve the parameters for a particular
recipe.

=cut

sub _parameters {
  my $self = shift;
  if (@_) {
    %{$self->{Parameters}} = @_;
  }
  return %{$self->{Parameters}};
}


=item B<_locate_file>

Find the specified file and return the full path.  Looks in cwd,
ORAC_DATA_OUT, ORAC_DATA_CAL, and ORAC_DATA_CAL/recpars, in that
order, unless it's a fully-specified path.

 $path = $self->_locate_file( $file );

Returns undef if the file does not exist.

=cut

sub _locate_file {
  my $self = shift;
  my $file = shift;

  return undef unless defined $file;

  # fully specified path and file exists. Great.
  if (File::Spec->file_name_is_absolute($file)) {
    print "ABSOLUTE FILENAME: $file\n" if $DEBUG;
    return (-e $file ? $file : undef);
  }

  # Start looking around
  for my $dir ( File::Spec->curdir,
                $ENV{ORAC_DATA_OUT},
                $ENV{ORAC_DATA_CAL},
                File::Spec->catfile( $ENV{'ORAC_DATA_CAL'}, 'recpars' ) ) {
    my $path = File::Spec->catfile( $dir, $file );
    # We try to open the file instead of -e as we have had cases
    # where -e fails over NFS despite the file existing.
    if (open my $fh, $path) {
      return File::Spec->rel2abs($path);
    }
  }

  return;
}

=item B<_parse_file>

Read the contents from the file and store it in the object.

=cut

sub _parse_file {
  my $self = shift;
  my $file = $self->filename;

  # Just get it straight into a hash
  my %data;
  tie %data, "Config::IniFiles", ( -file => $file, -nocase => 1 );
  print "Recipe parameters: ". Dumper(\%data) if $DEBUG;

  orac_warn "No recipe parameters found in recpars file $file\n"
    unless keys %data;

  # Now we want to loop through the contents converting
  # keys to a fixed case, expanding comma separated lists
  # into array references.
  my %cfg;
  for my $key ( keys %data ) {
    print "Trying primary key '$key'\n" if $DEBUG;
    if (exists $data{$key} && defined $data{$key}) {

      # Want to lower case all the keys and process arrays
      my %new;
      for my $oldkey (keys %{$data{$key}}) {
        my ($newkey, $newval) = $self->_clean_entry($oldkey, $data{$key}->{$oldkey});
        $new{$newkey} = $newval;
      }

      # Store the keys in the config, indexed by recipe
      $cfg{uc($key)} = \%new;
    }
  }

  print "Parsed parameters: ". Dumper(\%cfg) if $DEBUG;

  $self->_parameters( %cfg );

}

=item B<_match_filters>

$rec should either be a recipe name, or a a RECIPES_<ORAC_OBSERVATION_TYPE> value.


=cut

sub _match_filters {
    my $self = shift;
    my $rec = shift;
    my $hdr = shift || {};
    return () unless defined $rec;

    $rec = uc($rec);
    my $object = $hdr->{'ORAC_OBJECT'};
    $object = uc($object) if defined $object;

    # Hash to store recipe parameters by specificness.
    my %RecParsMatch = ();
    my %allpars = $self->_parameters();



    # Check each "section" of the recipe parameters definition in turn.
    SECTION: while (my ($key, $pars) = each %allpars) {
        my ($recipe_object, @filters) = split '#', $key;
        my ($recipe, $object_match) = split ':', $recipe_object, 2;

        next unless $recipe eq $rec;

        # Counter for number of filters (including object name) matched.
        my $spec = 0;

        if (defined $object_match) {
            next unless defined $object
                and ($object eq $object_match)
                || ($object =~ /^$object_match$/);
            $spec ++;
        }

        foreach my $filter (@filters) {
            # For now assume all filters are "=" operations (string-wise) but
            # we could add more operations here.  E.g date < X might be useful.
            # Note: we force the header value to upper case because _parse_file()
            # will already have forced the whole "key" (including filters)
            # to upper case.

            my ($filter_key, $filter_val) = split '=', $filter, 2;
            my $hdr_val = $hdr->{'ORAC_' . $filter_key};
            next SECTION unless defined $hdr_val;
            $hdr_val = $hdr_val->datetime() if UNIVERSAL::can($hdr_val, 'datetime');
            next SECTION unless uc($hdr_val) eq $filter_val;
            $spec ++;
        }

        unless (exists $RecParsMatch{$spec}) {
            $RecParsMatch{$spec} = $pars;
        }
        else {
            $RecParsMatch{$spec} = {%{$RecParsMatch{$spec}}, %$pars};
        }

    }

    return %RecParsMatch;
}

=item B<_clean_entry>

Clean up an entry in the config hash. Will upper case keys and convert
comma-separated entries into arrays references.

 ($newkey, $newval) = $cfg->_clean_entry( $oldkey, $oldval );

=cut

sub _clean_entry {
  my $self = shift;
  my $oldkey = shift;
  my $oldval = shift;

  my $newkey = uc($oldkey);
  my $newval = $oldval;

  if (!ref($newval) && $newval =~ /,/) {
    $newval = [ split(/\s*,\s*/,$newval)];
  } elsif (ref($newval) eq 'HASH') {
    # Nested. Need to recurse
    my %nest;
    for my $nestkey (keys %$newval) {
      my ($new_nestkey, $new_nestval) = $self->_clean_entry( $nestkey,
                                                              $newval->{$nestkey} );
      $nest{$new_nestkey} = $new_nestval;
    }
    $newval = \%nest;
  }

  return ($newkey, $newval);
}

=back

=end __INTERNALS__

=head1 FILE FORMAT

The recipe parameters file uses standard "INI" format comprising of sections
containing keyword=value pairs.

 [RECIPE_NAME]
 param1 = value1
 param2 = array1,array2,array3
 param3 = string

 [RECIPE2_NAME]
 param1 = value

 [RECIPE_NAME:OBJECT1]
 param1 = value

 [RECIPE_NAME:OBJECT2]

Comma-separated values are converted to perl arrays. Multiple recipes
can be specified in a single parameter file.

Object names (as found in the FITS header but converted to upper case
and with spaces removed) can be specified along with recipe names. If
a recipe is being processed with a particular object the parameters
for the recipe itself and the object variant of the recipe will be
merged with the object taking precedence.

Recipe name overrides can also be specified by using the object
name for a particular observation type

 [RECIPES_SCIENCE]
 OBJECT1=REDUCE_SCIENCE
 OBJECT2=REDUCE_FAINT_SOURCE

 [RECIPES_POINTING]

where object names are forced to upper case and have spaces removed.

In all cases where an OBJECT is specified above it can be replaced
by a perl pattern:

 [RECIPES_SCIENCE]
 .*=REDUCE_FAINT_SOURCE

here all objects of science observations would change to a new
recipe.

 [RECIPE_NAME:O.*]
 param1 = value

Here all objects starting with the letter "O" for that recipe
will use the override of param1.

You can also set the recipe choice specifically for various header values, e.g.

 [RECIPES_GRID:#SPECIES=CS#TRANSITION=7 - 6]
 .*=REDUCE_SCIENCE_BROADLINE
 OMC1=REDUCE_SCIENCE_NARROWLINE

Would use REDUCE_SCIENCE_BROADLINE for grid observations with molecule=CS
and transition=7 - 6, unless the name of the object was OMC1.

(A specific name will override a regexp, but if there are 2 regexps
that match, then the first one that matches will be used.)


Parameters for a given recipe can also be specified by other translated
headers, for example:

  [RECIPE_NAME#FILTER=850]
  param1 = value1

  [RECIPE_NAME:OBJECT_NAME#FILTER=450]
  param1 = value2

  [REDUCE_SCAN#FILTER=850#SCAN_PATTERN=CURVY_PONG]
  MAKEMAP_CONFIG = my_pong_850_dimmconfig.lis

  [REDUCE_SCAN#FILTER=450#SCAN_PATTERN=CV_DAISY]
  MAKEMAP_CONFIG = my_daisy_450_dimmconfig.lis

There can be multiple such general header specifiers but they must
follow any object names.  To see which translated headers are available,
you could try running the F<translatehdr> command, e.g.:

  $STARLINK_DIR/Perl/bin/translatehdr filename.sdf

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,

=head1 COPYRIGHT

Copyright (C) 2009, 2011 Science and Technology Facilities Council.
All Rights Reserved.

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
