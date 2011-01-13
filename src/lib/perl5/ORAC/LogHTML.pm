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
  # open the file and write a header
  open(my $fh, ">", $file ) || croak "Unable to open file $file: $!";
  # Define the style sheet elements for the ANSI color codes. The elements
  # will be defined by the name used by Term::ANSIColor
  print $fh qq|<HTML>
<style TYPE="text/css">
<!--
.red {
  color: red
}
.green {
  color: green
}
.black {
  color: black
}
.yellow {
  color: yellow
}
.blue {
  color: blue
}
.magenta {
  color: magenta
}
.cyan {
  color: cyan
}
.white {
  color: white
}
.on_red {
  background: red
}
.on_green {
  background: green
}
.on_black {
  background: black
}
.on_yellow {
  background: yellow
}
.on_blue {
  background: blue
}
.on_magenta {
  background: magenta
}
.on_cyan {
  background: cyan
}
.on_white {
  background: white
}
.bold {
  font-weight: bold
}
.underline {
  text-decoration: underline
}

-->
</style>
<code>
|;
  return bless \$fh, $class;
}

sub PRINT {
  my $self = shift;
  for my $line (@_) {
    my $l = _fixup_line( $line );
    print { $$self } "$l";
  }
}

sub CLOSE {
  my $self = shift;
  return unless defined $$self; # prevent double close
  print { $$self } "\n</code></html>\n";
  close $$self;
  $$self = undef;
}

sub DESTROY {
  my $self = shift;
  $self->CLOSE(); # just to make sure
}


# Create a hash of control codes

my %ANSILUT = (
               color("clear") => "</span>",
               color("bold") => "<span CLASS=\"bold\">",
               color("underline") => "<span CLASS=\"underline\">",
              );
my @colors = qw/black red green yellow blue magenta cyan white/;
for (@colors) {
  $ANSILUT{color($_)} = "<span CLASS=\"$_\">";
  $ANSILUT{color("on_$_")} = "<span CLASS=\"on_$_\">";
}

sub _fixup_line {
  my $line = shift;

  # convert spaces to non-breakable spaces and newlines to <BR>
  my $nbsp = "&nbsp;";
  my $tab = $nbsp x 8;
  $line =~ s/\t/$tab/;
  $line =~ s/\n/<BR>\n/;
  $line =~ s/ /$nbsp/g;

  # look for escape codes (see Tk::TextANSIColor)
  # Split into chunks
  my @split = split /(\e\[(?:\d{1,2};?)+m)/, $line;

  # and go through the bits one at a time to rebuild the strng
  my @output;
  for my $part (@split) {
    if ($part !~ /^\e/) {
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
          push(@output, $ANSILUT{$esc});
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
