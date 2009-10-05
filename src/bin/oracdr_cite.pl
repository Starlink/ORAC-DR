#!perl

use Astro::ADS::Query;
use DateTime;

my @bibcodes = qw[
                  1998ASPC..145..196E
                  1999ASPC..172...11E
                  1999ASPC..172..171J
                  1999ASPC..172..175C
                  2001ASPC..238..137W
                  2001ASPC..238..299J
                  2001ASPC..238..314E
                  2002MNRAS.336...14J
                  2002ASPC..281..311A
                  2003ASPC..295..237C
                  2004ASPC..314..428J
                  2004ASPC..314..460C
                  2005ASPC..343...77C
                  2005ASPC..343...83L
                  2005ASPC..347..580C
                  2005ASPC..347..585G
                  2008AN....329..295C
                 ];

print "<html><head><title>Papers referencing ORAC-DR papers</title></head>\n";
print "<body><h3>Papers referencing ORAC-DR papers</h3>\n";
print "<em>Last updated: ";
my $updated = DateTime->now;
print $updated->month_name . " " . $updated->day . ", " . $updated->year;
print "</em><br><br>\n";

foreach my $bibcode ( @bibcodes ) {
  my $query = new Astro::ADS::Query( Bibcode => $bibcode );
  my $results = $query->querydb();

  my $paper = $results->poppaper;

  my @links = $paper->links;
  my $citations = 0;
  foreach my $link ( @links ) {
    if ( $link eq 'CITATIONS' ) {
      $citations = 1;
    }
  }
  next if $citations == 0;

  my $followup = $query->followup( $paper->bibcode, "CITATIONS" );

  print $followup->sizeof;
  print " paper";
  if( $followup->sizeof != 1 ) {
    print "s";
  }
  print " citing <a href=\"http://adsabs.harvard.edu/cgi-bin/bib_query?";
  print $paper->bibcode;
  print "\">";
  print $paper->title;
  print "</a>:<br>\n";
  print "<ul>\n";

  foreach my $citation_paper ( $followup->papers ) {

    print "<li><a href=\"http://adsabs.harvard.edu/cgi-bin/bib_query?";
    print $citation_paper->bibcode;
    print "\">";
    print $citation_paper->title;
    print "</a><br>\n";
    my @authors = $citation_paper->authors;
    my @authors2 = ();
    foreach my $author ( @authors ) {
      $author =~ s/^\s+//;
      $author =~ s/\s+$//;
      next if length( $author . "" ) == 0;
      push @authors2, $author;
    }
    print commify_series( @authors2 );
    print ". ";
    print $citation_paper->journal;
    print "</li>\n";
  }

  print "</ul>\n";
  print "<br>\n";

}

sub commify_series {
  ( @_ == 0 ) ? ''                                         :
  ( @_ == 1 ) ? $_[0]                                      :
  ( @_ == 2 ) ? join( " $amp; ", @_ )                      :
                join( ", ", @_[0..($#_-1)], "&amp; $_[-1]");
}
