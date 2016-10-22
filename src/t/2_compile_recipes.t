use strict;

use File::Spec;
use IO::Dir;

use ORAC::Recipe;
use ORAC::Inst::Defn qw/orac_determine_inst_classes/;

my (@instruments, $n_recipe);
my $VERBOSE = 0;

# Use begin block to find and count recipes before setting up Test::More.
BEGIN {
    @instruments = (
        {
            name => 'ACSIS',
            dir => 'heterodyne',
            skip => {
                'REDUCE_DAS' => 1,            # Requires PDL
                'REDUCE_PLANET_SAMPLE' => 1,  # Requires Astro::Constants
            },
        },
        {
            name => 'SCUBA',
            dir => 'SCUBA',
            skip => {
                'SCUBA_EM2SCAN_ITERATE' => 1,  # Variable from recipe scope
            }
        },
        {
            name => 'SCUBA2_850',
            dir => 'SCUBA2',
        },
        {
            name => 'PICARD_SCUBA2_850',
            dir => 'PICARD',
            override => {
                CREATE_MOMENTS_MAP => 'PICARD_ACSIS',
            },
        },
    );

    sub find_recipes {
        my $instrument_dir = shift;

        my @recipes = ();

        my $dir_path = File::Spec->catfile(qw/recipes/, $instrument_dir);
        my $dir = new IO::Dir($dir_path);

        while (defined (my $recipe = $dir->read())) {
            # Exclude backup and hidden files.
            next if $recipe =~ /~$/
                 or $recipe =~ /^\./;

            # Exclude non-files and symlinked copies of other recipes.
            my $file_path = File::Spec->catfile($dir_path, $recipe);
            push @recipes, $recipe if -f $file_path and not -l $file_path;
        }

        return \@recipes;
    }

    $n_recipe = 0;

    foreach my $instrument (@instruments) {
        my $recipes = find_recipes($instrument->{'dir'});
        $instrument->{'recipes'} = $recipes;
        $n_recipe += scalar @$recipes;
    }

}

use Test::More tests => $n_recipe;

# Iterate over instruments and try to load each recipe.
foreach my $instrument (@instruments) {
    my $name = $instrument->{'name'};

    print STDERR "Checking instrument: $name\n" if $VERBOSE;

    my $override = $instrument->{'override'} // {};
    my $skip = $instrument->{'skip'} // {};

    foreach my $recipe (@{$instrument->{'recipes'}}) {
        SKIP: {
            skip "Recipe $name $recipe being skipped", 1 if $skip->{$recipe};

            eval {
                check_recipe($override->{$recipe} // $name, $recipe);
            };

            if ($@) {
                print STDERR "\n$name $recipe\n" unless $VERBOSE;
                print STDERR "      $_\n" foreach split "\n", $@;
                fail("$name $recipe");
            }
            else {
                pass("$name $recipe");
            }
        }
    }
}

sub check_recipe {
    my $instrument = shift;
    my $recipe = shift;

    print STDERR "  Checking recipe: $recipe\n" if $VERBOSE;

    my ($frameclass, $groupclass, $calclass, $instclass) =
        orac_determine_inst_classes($instrument);

    my $r = new ORAC::Recipe(NAME       => $recipe,
                             INSTRUMENT => $instrument,
                             FRAME      => $frameclass->new());

    $r->recipe()->code();
    my @p = $r->primitives();

    foreach my $p (@p) {
        print STDERR "    Primitive: $p\n" if $VERBOSE;
        $r->parser()->find($p)->code();
    }
}
