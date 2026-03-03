package ORAC::LogHTML;

=head1 NAME

ORAC::LogHTML - Provide ORAC-DR log file in HTML format

=head1 SYNOPSIS

  use ORAC::LogHTML;

  my $fh = ORAC::LogHTML->new( $filename );

  print $fh colored( "Some text", "red" );
  close($fh);

=head1 DESCRIPTION

ORAC-DR log files contain terminal ANSI color codes created
by the Term::ANSIColor module. This class can intercept prints
to the file handle and convert the content to HTML. Spaces,
tabs and newlines will also be converted to HTML. This
class can be added to the standard array of logging file handles.

Can only be used for writing to the file using PRINT.

=cut

use strict;
use warnings;
use Carp;
our $VERSION = '0.01';
use Symbol;
use base qw/ Tie::Handle /;
use Term::ANSIColor;
use ORAC::Version;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $filename = shift;
  # we need to tie this to a glob but passing in our initial filename
  my $tie = gensym;
  tie *$tie, $class, $filename;
  return $tie;
}

sub TIEHANDLE {
  my $class = shift;
  my $file = shift;
  croak "Must supply a filename!" unless defined $file;

  my $app = ORAC::Version->getApp();

  # open the file and write a header
  open(my $fh, ">", $file ) || croak "Unable to open file $file: $!";
  # Define the style sheet elements for the ANSI color codes. The elements
  # will be defined by the name used by Term::ANSIColor
  print $fh qq|<html>
<head>
<title>$app Log</title>
<style>
body {
  background: #aaaaaa;
}
code {
  white-space: nowrap;
}
.red {
  color: red;
}
.green {
  color: green;
}
.black {
  color: black;
}
.yellow {
  color: yellow;
}
.blue {
  color: blue;
}
.magenta {
  color: magenta;
}
.cyan {
  color: lightcyan;
}
.white {
  color: white;
}
.on_red {
  background: red;
}
.on_green {
  background: green;
}
.on_black {
  background: black;
}
.on_yellow {
  background: yellow;
}
.on_blue {
  background: blue;
}
.on_magenta {
  background: magenta;
}
.on_cyan {
  background: cyan;
}
.on_white {
  background: white;
}
.bold {
  font-weight: bold;
}
.underline {
  text-decoration: underline;
}
</style>
</head>
<body>
<code>
|;
  return bless {
    fh => $fh,
    n_span => 0,
  }, $class;
}

sub PRINT {
  my $self = shift;
  for my $line (@_) {
    print { $self->{'fh'} } $self->_fixup_line( $line );
  }
}

sub CLOSE {
  my $self = shift;
  return unless defined $self->{'fh'}; # prevent double close
  print { $self->{'fh'} } "\n</code></body></html>\n";
  close $self->{'fh'};
  $self->{'fh'} = undef;
}

sub DESTROY {
  my $self = shift;
  $self->CLOSE(); # just to make sure
}


# Create a hash of control codes

my %ANSILUT = (
               color('clear') => '</span>',
               color('bold') => '<span class="bold">',
               color('underline') => '<span class="underline">',
              );
foreach (qw/black red green yellow blue magenta cyan white/) {
  $ANSILUT{color($_)} = "<span class=\"$_\">";
  $ANSILUT{color("on_$_")} = "<span class=\"on_$_\">";
}

my @ENTS = (
    ['&' => '&amp;'],
    ['>' => '&gt;'],
    ['<' => '&lt;'],
    ['"' => '&quot;'],
    ['~' => '&#x7E;'],
);

my $TAB = '&nbsp;' x 8;

sub _fixup_line {
  my $self = shift;
  my $line = shift;

  # Sort out protected characters and spaces
  foreach (@ENTS) {
    my ($ent, $rep) = @$_;
    $line =~ s/$ent/$rep/g;
  }

  # convert tabs to non-breakable spaces
  $line =~ s/\t/$TAB/g;

  # Newlines to <br> has to happen after entity replacement
  $line =~ s/\n/<br \/>\n/g;

  # look for escape codes (see Tk::TextANSIColor)
  # Split into chunks
  my @split = split /(\e\[(?:\d{1,2};?)+m)/, $line;

  # and go through the bits one at a time to rebuild the strng
  my @output;
  for my $part (@split) {
    if ($part !~ /^\e/) {
      # Retain spaces at start and end (used by primitives to make "passed"
      # and "failed" banners) and multiples (sometimes used for alignment).
      $part =~ s/^( +)/'&nbsp;' x length($1)/e;
      $part =~ s/( +)$/'&nbsp;' x length($1)/e;
      $part =~ s/(  +)/'&nbsp;' x length($1)/eg;
      push(@output, $part );
    } else {

      # The escape sequence can have semi-colon separated bits
      # in it. Need to strip off the \e[ and the m. Split on
      # semi-colon and then reconstruct before comparing
      # We know it matches \e[....m so use substr

      # Only bother if we have a semi-colon

      my @escs = ($part);
      if ($part =~ /;/) {
        my $strip = substr($part, 2, length($part) - 3);

        # Split on ; (overwriting @escs)
        @escs = split(/;/,$strip);

        # Now attach the correct escape sequence
        foreach (@escs) { $_ = "\e[${_}m" }
      }

      # Loop over all the escape sequences
      for my $esc (@escs) {
        if (exists $ANSILUT{$esc}) {
          my $rep = $ANSILUT{$esc};
          # All of our replacements open a span except clear which should close
          # them all.  Therefore increase span counter unless this is a close.
          unless ($rep =~ /^<\/span/) {
            push @output, $rep;
            $self->{'n_span'} ++;
          } else {
            while ($self->{'n_span'} > 0) {
              push @output, $rep;
              $self->{'n_span'} --;
            }
          }
        } else {
          print STDERR "Unrecognised control code - ignoring\n";
          for (split //, $esc) {
            print STDERR ord($_). " : $_\n";
          }
        }
      }
    }
  }

  return join("", @output);
}

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2011 Science and Technology Facilities Council.
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
