use ExtUtils::MakeMaker;

use 5.006;

# This will scan the lib directory looking for .pm files

WriteMakefile(
	      'NAME' => 'ORACDR',
	      VERSION => '2.1',
	      'EXE_FILES' => [qw( bin/oracdr bin/oracdr_monitor 
				  bin/Xoracdr bin/oracdr_nuke
				  bin/oracdisp bin/oracdr_monitor
				  bin/oracdr_parse_recipe
				)],
	      'PMLIBDIRS' => [ 'lib/perl5' ],
              'dist'      => { COMPRESS => "gzip -9f"},
	      ABSTRACT   => 'ORAC Data Reduction Pipeline',
              AUTHOR     => 'ORAC-DR project team',

);


# We don't want to install anything
sub MY::install { "install ::\n"  }


# Fix up libscan - MakeMaker gets confused by the lib/perl5/ 
# in the path so we have to handle that. Additionally there is
# a lot of extra junk that seems to get through by default 
# (including ~ files)
sub MY::libscan {
  my $self = shift;
  my $pm = shift;

  # Check that we have a pm file
  return undef unless ($pm =~ /\.pm$/);

  # Remore the perl5/ from the path
  $pm =~ s|perl5/||;

  return $pm;
}
