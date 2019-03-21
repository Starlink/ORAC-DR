use strict;

use File::Spec;
use IO::Dir;

use ORAC::Recipe;
use ORAC::Inst::Defn qw/
    orac_determine_inst_classes
    orac_determine_recipe_search_path
/;

my (@instruments, $n_recipe);
my $VERBOSE = 0;

# Use begin block to find and count recipes before setting up Test::More.
BEGIN {
    # Set up ORAC-DR environment variables.
    $ENV{'ORAC_DIR'} = File::Spec->rel2abs('.');
    $ENV{'ORAC_CAL_ROOT'} = File::Spec->catdir(
        File::Spec->rel2abs(File::Spec->updir()), 'cal');

    @instruments = (
        {
            name => 'ACSIS',
            skip => [
                'REDUCE_DAS',                 # Requires PDL
                'REDUCE_PLANET_SAMPLE',       # Requires Astro::Constants
            ],
        },
        {
            name => 'SCUBA',
            skip => [
                'SCUBA_EM2SCAN_ITERATE',       # Variable from recipe scope
            ]
        },
        {
            name => 'SCUBA2_850',
        },
        {
            name => 'PICARD_SCUBA2_850',
            override => {
                CREATE_MOMENTS_MAP => 'PICARD_ACSIS',
                CALIBRATE_SIDEBAND_RATIO => 'PICARD_ACSIS',
            },
        },
        {
            name => 'WFCAM1',
            skip => [
                'POL_ANGLE_JITTER',            # _DEFINE_POL_REGIONS_ not found
                'POL_ANGLE_JITTER_NO_FLAT',    # _DEFINE_POL_REGIONS_ not found
                'POL_EXTENDED',                # _DEFINE_POL_REGIONS_ not found
                'POL_EXTENDED_NO_FLAT',        # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER',                  # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER_CORON',            # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER_NO_FLAT',          # _DEFINE_POL_REGIONS_ not found
                'SKY_FLAT',                    # _SKY_FLAT_STEER_ $waveplate_flat not declared
                'SKY_FLAT_MASKED',             # _SKY_FLAT_STEER_ $waveplate_flat not declared
                'SKY_FLAT_POL',                # _SKY_FLAT_STEER_ $waveplate_flat not declared
                'SKY_FLAT_POL_ANGLE',          # _SKY_FLAT_STEER_ $waveplate_flat not declared
                'USTEP_JITTER',                # _USTEP_JITTER_HELLO_ not found
                'USTEP_JITTER_SELF_FLAT',      # _USTEP_JITTER_HELLO_ not found
            ],
        },
        {
            name => 'CGS4',
        },
        {
            name => 'UFTI',
        },
        {
            name => 'UIST',
        },
        {
            name => 'MICHELLE',
            skip => [
                'POL_ANGLE_JITTER',            # _DEFINE_POL_REGIONS_ not found
                'POL_ANGLE_JITTER_NO_FLAT',    # _DEFINE_POL_REGIONS_ not found
                'POL_EXTENDED',                # _DEFINE_POL_REGIONS_ not found
                'POL_EXTENDED_NO_FLAT',        # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER',                  # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER_CORON',            # _DEFINE_POL_REGIONS_ not found
                'POL_JITTER_NO_FLAT',          # _DEFINE_POL_REGIONS_ not found
            ],
        },
    );

    sub find_recipes {
        my $name = shift;

        my %recipes = ();

        foreach my $dir_path (orac_determine_recipe_search_path($name)) {
            $dir_path = File::Spec->abs2rel($dir_path);

            my $dir = new IO::Dir($dir_path);
            next unless defined $dir;

            # Do same check for mode-specific directory path as
            # ORAC::Inst::Defn::orac_list_generic_observing_modes.
            my @dirs = File::Spec->splitdir($dir_path);
            my $observation_mode = ($dirs[1] =~ /^[a-z]+$/)
                ? $dirs[1] : undef;

            while (defined (my $recipe = $dir->read())) {
                # Exclude backup and hidden files.
                next if $recipe =~ /~$/
                     or $recipe =~ /^\./;

                # Exclude non-files and symlinked copies of other recipes.
                my $file_path = File::Spec->catfile($dir_path, $recipe);
                next unless (-f $file_path and not -l $file_path);

                $recipes{$recipe} = {
                    observation_mode => $observation_mode,
                } unless exists $recipes{$recipe};
            }
        }

        return \%recipes;
    }

    $n_recipe = 0;

    foreach my $instrument (@instruments) {
        my $name = $instrument->{'name'};
        my @path = orac_determine_recipe_search_path($name);
        my $recipes = find_recipes($name);
        $instrument->{'recipes'} = $recipes;
        $n_recipe += scalar keys %$recipes;
    }

}

use Test::More tests => $n_recipe;

# Iterate over instruments and try to load each recipe.
foreach my $instrument (@instruments) {
    my $name = $instrument->{'name'};

    print STDERR "Checking instrument: $name\n" if $VERBOSE;

    $ENV{'ORAC_INSTRUMENT'} = $instrument unless $instrument =~ /^PICARD/;
    my $override = $instrument->{'override'} // {};
    my $skip = $instrument->{'skip'} // [];
    my %skip = map {$_ => 1} @$skip;

    while (my ($recipe, $recipe_info) = each %{$instrument->{'recipes'}}) {
        SKIP: {
            my $observation_mode = $recipe_info->{'observation_mode'};
            my $description = "$name $recipe";
            $description .= " ($observation_mode)"
                if defined $observation_mode;

            skip "Recipe $description being skipped", 1 if $skip{$recipe};

            eval {
                check_recipe(
                    $override->{$recipe} // $name,
                    $recipe, $observation_mode);
            };

            if ($@) {
                print STDERR "\n$description\n" unless $VERBOSE;
                print STDERR "      $_\n" foreach split "\n", $@;
                fail($description);
            }
            else {
                pass($description);
            }
        }
    }

    delete $ENV{'ORAC_INSTRUMENT'};
}

sub check_recipe {
    my $instrument = shift;
    my $recipe = shift;
    my $observation_mode = shift;

    print STDERR "  Checking recipe: $recipe\n" if $VERBOSE;

    my ($frameclass, $groupclass, $calclass, $instclass) =
        orac_determine_inst_classes($instrument);

    my $frame = $frameclass->new();
    $frame->uhdr('ORAC_OBSERVATION_MODE', $observation_mode)
        if defined $observation_mode;

    my $r = new ORAC::Recipe(NAME       => $recipe,
                             INSTRUMENT => $instrument,
                             FRAME      => $frame);

    $r->recipe()->code();
    my @p = $r->primitives();

    foreach my $p (@p) {
        print STDERR "    Primitive: $p\n" if $VERBOSE;
        $r->parser()->find($p)->code();
    }
}
