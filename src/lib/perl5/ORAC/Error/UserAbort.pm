# ORAC::Error::UserAbort

package ORAC::Error::UserAbort;

# ---------------------------------------------------------------------------

use lib $ENV{"ORAC_PERL5LIB"};
@ORAC::Error::UserAbort::ISA = qw/ Error Exporter/;

use strict;

# ---------------------------------------------------------------------------

require Exporter;
use vars qw/$VERSION @EXPORT @ISA/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

@EXPORT = qw/ store flush /;

use overload (
	'""'	   =>	'stringify',
	'0+'	   =>	'value',
	'fallback' =>	1
);

# File globals
my ( @error_stack );

# M E T H O D S  -----------------------------------------------------------

sub new {

    my $self  = shift;
    my ( $text, $value ) = @_;
    $text = "" unless defined;
    
    my(@args) = ();

    local $Error::Depth = $Error::Depth + 1;

    @args = ( -file => $1, -line => $2)
	if($text =~ s/ at (\S+) line (\d+)(\.\n)?$//s);

    push(@args, '-value', 0 + $value)
	if defined($value);

    $self->Error::new(-text => $text, @args);
}

sub stringify {
    my $self = shift;
    my $text = $self->Error::stringify;
    $text .= sprintf(" at %s line %d.\n", $self->file, $self->line)
	unless($text =~ /\n$/s);
    $text;
}

sub store {
    my $self = shift;
    local $Error::Depth = $Error::Depth + 1;
    
    # if we are not rethrow-ing then create the object to throw
    $self = $self->new(@_) unless ref($self);    
    push ( @error_stack, $self );
}

sub flush {
   my $self = shift;

   # check to see whether we have anything in the queue
   my $queue = scalar(@error_stack);
   my $got_error = $queue == 0 ? undef : 1;
   
   # pop the last error off the top of the error stack and throw it
   my $Error = pop ( @error_stack ) if defined $got_error;
   $self->throw if defined $got_error;

}

# ---------------------------------------------------------------------------

1;
