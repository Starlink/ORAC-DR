#!perl

use strict;
use warnings;

use Test::More tests => 4;
use File::Temp qw/tempfile/;
use Term::ANSIColor qw/color/;

use ORAC::LogHTML;
use ORAC::Print;

delete local @ENV{qw/ANSI_COLORS_DISABLED NO_COLOR/};

my ($tmpfh, $tmpfile) = tempfile(SUFFIX => '.html', UNLINK => 1);
close $tmpfh;

my $fh = ORAC::LogHTML->new($tmpfile);
ok($fh, 'created tied log handle');

my $tied = tied(*$fh);
isa_ok($tied, 'ORAC::LogHTML');

my $prt = ORAC::Print->new;
isa_ok($prt, 'ORAC::Print');
$prt->outhdl($fh);

$prt->say('escape < & >');
$prt->say('color', 'red');
$prt->say('background', 'white on_blue');
$prt->say('three', 'yellow on_blue bold');
$prt->say('underline', 'underline');

close($fh);

my $html = read_html($tmpfile);
my $expect = join '', <DATA>;

is($html, $expect, 'output matches expected');

# Read just the <code> section of the given HTML file.
sub read_html {
    my $path = shift;
    my $fh = IO::File->new($path, 'r');
    die "Unable to read $path: $!" unless defined $fh;
    my @content;
    my $code = 0;
    while (my $line = <$fh>) {
        $code &&= $line !~ /<\/code>/;
        push @content, $line if $code;
        $code ||= $line =~ /<code>/;
    }
    $fh->close;
    return join '', @content;
}

__DATA__
<span class="magenta">escape &lt; &amp; &gt;<br />
</span><span class="red">color<br />
</span><span class="white"><span class="on_blue">background<br />
</span></span><span class="yellow"><span class="on_blue"><span class="bold">three<br />
</span></span></span><span class="underline">underline<br />
</span>
