#!/local/perl/bin/perl

use strict;

my $file;
if( @ARGV ) {
  $file = shift @ARGV;
} else {
  die "Supply ORAC-DR log file on command-line: oracdr_log_analyzer.pl <filename>";
}

if( ! -e $file ) {
  die "Could not find file $file";
}

open my $fh, "<", $file or die "Could not open file $file: $!";

my %rec_time;
my %task_time;
my $current_recipe = '';
my $current_primitive = '';
my $current_task = '';
my $current_observation = 0;
my $instrument = '';
while ( <$fh> ) {

  # Strip out the colour codes.
  s/\e\[\d+m\e\[\d+m//g;

  # Check for different timing lines.
  if( /REDUCING: [a-z]\d{8}_(\d{5})/ ) {
    $current_observation = int( $1 );
  }
  if( /Using recipe (\w+) / ) {
    $current_recipe = $1;
  }
  if( /Recipe took ([\d\.]+) seconds/ ) {
    $rec_time{$current_recipe}{$current_observation} = $1;
  }
  if( /Calling ([\w]+) in [a-z_]+ took ([\d\.]+) seconds/ ) {
    if( defined( $task_time{$1} ) ) {
      push @{$task_time{$1}}, $2;
    } else {
      ${$task_time{$1}}[0] = $2;
    }
  }
}

close $fh;

foreach my $recipe ( sort keys %rec_time ) {
  my $sum = 0;
  my $max = 0;
  my $maxobs = 0;
  my $min = 1000000;
  my $minobs = 0;
  foreach my $obsnum ( keys %{$rec_time{$recipe}} ) {
    $sum += $rec_time{$recipe}{$obsnum};
    if( $rec_time{$recipe}{$obsnum} > $max ) {
      $max = $rec_time{$recipe}{$obsnum};
      $maxobs = $obsnum;
    }
    if( $rec_time{$recipe}{$obsnum} < $min ) {
      $min = $rec_time{$recipe}{$obsnum};
      $minobs = $obsnum;
    }
  }
  my $nobs = scalar keys %{$rec_time{$recipe}};
  my $avg = $sum / $nobs;

  print sprintf( "\nAverage runtime for %s: %.3f seconds\n",
                 $recipe,
                 $avg );
  print "Range: $min ($minobs) to $max ($maxobs) seconds\n";
  print "$nobs observations\n";

}

my $totaltime = 0;
my %total;
my %calls;
my %average;
foreach my $task ( sort keys %task_time ) {
  my $tasksum = 0;
  my $taskmax = 0;
  my $taskmin = 100000000;
  foreach my $time ( @{$task_time{$task}} ) {
    $tasksum += $time;
    if( $time > $taskmax ) {
      $taskmax = $time;
    }
    if( $time < $taskmin ) {
      $taskmin = $time;
    }
  }
  my $ncalls = scalar @{$task_time{$task}};
  my $taskavg = $tasksum / $ncalls;
  print sprintf( "\nAverage runtime for %s: %.3f seconds\n",
                 $task,
                 $taskavg );
  print sprintf( "Total runtime for %s: %.3f seconds\n",
                 $task,
                 $tasksum );
  print "Range: $taskmin to $taskmax seconds\n";
  print "$ncalls call" . ( $ncalls == 1 ? '' : 's' ) . " to $task\n";

  $total{$task} = $tasksum;
  $calls{$task} = $ncalls;
  $average{$task} = $taskavg;
  $totaltime += $tasksum;

}

my $limit = 10;

print sprintf( "\nTotal runtime: %.3f seconds\n",
               $totaltime );
print "\nTop $limit tasks by total time:\n";
my %reverse = reverse %total;
my $i = 0;
foreach my $key ( reverse sort { $a <=> $b } keys %reverse ) {
  $i++;
  print sprintf( "%2d: %12s: %7.2f seconds (%5.2f%% of total)\n", $i, $reverse{$key}, $key, $key / $totaltime * 100 );
  last if $i >= $limit;
}

print "\nTop $limit tasks by average time:\n";
%reverse = reverse %average;
$i = 0;
foreach my $key ( reverse sort { $a <=> $b } keys %reverse ) {
  $i++;
  print sprintf( "%2d: %12s: %7.2f seconds (%3d calls)\n", $i, $reverse{$key}, $key, $calls{$reverse{$key}} );
  last if $i >= $limit;
}



