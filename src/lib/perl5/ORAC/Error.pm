# ORAC::Error --------------------------------------------------------------

package ORAC::Error;

=head1 NAME

ORAC::Error - Exception handling in an object orientated manner.

=head1 SYNOPSIS

    use ORAC::Error qw /:try/;
    use ORAC::Constants qw /:status/;

    throw ORAC::Error::UserAbort( $message, ORAC__ABORT );
    throw ORAC::Error::FatalError( $message, ORAC__FATAL );

    sub do_stuff {
         .
	 .
	 .
	record ORAC::Error::FatalError( $message, ORAC__FATAL);
         .
	 .
	 .
    }
 
    my $Error = ORAC::Error->prior;
    ORAC::Error->flush if defined $Error;
    
    try {
       stuff();
    }
    catch ORAC::Error::UserAbort with 
    {
	# normally we just want to catch and then ignore UserAborts
        my $Error = shift;
	orac_exit_normally();
    }
    catch ORAC::Error::FatalError with 
    {
        # its a fatal error
        my $Error = shift;
	orac_exit_normally($Error);
    }
    otherwise 
    {
       # this block catches croaks and other 
      
    }; # Don't forget the trailing semi-colon to close the catch block

=head1 DESCRIPTION

C<ORAC::Error> is based on a modifed version of Graham Barr's C<Error>
package, and more documentation about the features present in the module
but currently unused by 
The C<Error> package provides two interfaces. Firstly C<Error> provides
a procedural interface to exception handling. Secondly C<Error> is a
base class for errors/exceptions that can either be thrown, for
subsequent catch, or can simply be recorded.

Errors in the class C<Error> should not be thrown directly, but the
user should throw errors from a sub-class of C<Error>.

=head1 PROCEDURAL INTERFACE

C<Error> exports subroutines to perform exception handling. These will
be exported if the C<:try> tag is used in the C<use> line.

=over 4

=item try BLOCK CLAUSES

C<try> is the main subroutine called by the user. All other subroutines
exported are clauses to the try subroutine.

The BLOCK will be evaluated and, if no error is throw, try will return
the result of the block.

C<CLAUSES> are the subroutines below, which describe what to do in the
event of an error being thrown within BLOCK.

=item catch CLASS with BLOCK

This clauses will cause all errors that satisfy C<$err-E<gt>isa(CLASS)>
to be caught and handled by evaluating C<BLOCK>.

C<BLOCK> will be passed two arguments. The first will be the error
being thrown. The second is a reference to a scalar variable. If this
variable is set by the catch block then, on return from the catch
block, try will continue processing as if the catch block was never
found.

To propagate the error the catch block may call C<$err-E<gt>throw>

If the scalar reference by the second argument is not set, and the
error is not thrown. Then the current try block will return with the
result from the catch block.

=item except BLOCK

When C<try> is looking for a handler, if an except clause is found
C<BLOCK> is evaluated. The return value from this block should be a
HASHREF or a list of key-value pairs, where the keys are class names
and the values are CODE references for the handler of errors of that
type.

=item otherwise BLOCK

Catch any error by executing the code in C<BLOCK>

When evaluated C<BLOCK> will be passed one argument, which will be the
error being processed.

Only one otherwise block may be specified per try block

=item finally BLOCK

Execute the code in C<BLOCK> either after the code in the try block has
successfully completed, or if the try block throws an error then
C<BLOCK> will be executed after the handler has completed.

If the handler throws an error then the error will be caught, the
finally block will be executed and the error will be re-thrown.

Only one finally block may be specified per try block

=back

=head1 CLASS INTERFACE

=head2 CONSTRUCTORS

The C<Error> object is implemented as a HASH. This HASH is initialized
with the arguments that are passed to it's constructor. The elements
that are used by, or are retrievable by the C<Error> class are listed
below, other classes may add to these.

	-file
	-line
	-text
	-value
	-object

If C<-file> or C<-line> are not specified in the constructor arguments
then these will be initialized with the file name and line number where
the constructor was called from.

If the error is associated with an object then the object should be
passed as the C<-object> argument. This will allow the C<Error> package
to associate the error with the object.

The C<Error> package remembers the last error created, and also the
last error associated with a package. This could either be the last
error created by a sub in that package, or the last error which passed
an object blessed into that package as the C<-object> argument.

=over 4

=item throw ( [ ARGS ] )

Create a new C<Error> object and throw an error, which will be caught
by a surrounding C<try> block, if there is one. Otherwise it will cause
the program to exit.

C<throw> may also be called on an existing error to re-throw it.

=item with ( [ ARGS ] )

Create a new C<Error> object and returns it. This is defined for
syntactic sugar, eg

    die with Some::Error ( ... );

=item record ( [ ARGS ] )

Create a new C<Error> object and returns it. This is defined for
syntactic sugar, eg

    record Some::Error ( ... )
	and return;

=back

=head2 STATIC METHODS

=over 4

=item prior ( [ PACKAGE ] )

Return the last error created, or the last error associated with
C<PACKAGE>

=back

=head2 OBJECT METHODS

=over 4

=item stacktrace

If the variable C<$Error::Debug> was non-zero when the error was
created, then C<stacktrace> returns a string created by calling
C<Carp::longmess>. If the variable was zero the C<stacktrace> returns
the text of the error appended with the filename and line number of
where the error was created, providing the text does not end with a
newline.

=item object

The object this error was associated with

=item file

The file where the constructor of this error was called from

=item line

The line where the constructor of this error was called from

=item text

The text of the error

=back

=head2 OVERLOAD METHODS

=over 4

=item stringify

A method that converts the object into a string. This method may simply
return the same as the C<text> method, or it may append more
information. For example the file name and line number.

By default this method returns the C<-text> argument that was passed to
the constructor, or the string C<"Died"> if none was given.

=item value

A method that will return a value that can be associated with the
error. For example if an error was created due to the failure of a
system call, then this may return the numeric value of C<$!> at the
time.

By default this method returns the C<-value> argument that was passed
to the constructor.

=back

=head1 PRE-DEFINED ERROR CLASSES

=over 4

=item Error::Simple

This class can be used to hold simple error strings and values. It's
constructor takes two arguments. The first is a text value, the second
is a numeric value. These values are what will be returned by the
overload methods.

If the text value ends with C<at file line 1> as $@ strings do, then
this infomation will be used to set the C<-file> and C<-line> arguments
of the error object.

This class is used internally if an eval'd block die's with an error
that is a plain string.

=back

=head1 KNOWN BUGS

None, but that does not mean there are not any.

=head1 AUTHORS

Graham Barr <gbarr@pobox.com>

The code that inspired me to write this was originally written by
Peter Seibel <peter@weblogic.com> and adapted by Jesse Glick
<jglick@sig.bsh.com>.

=cut

use Error qw/ :try /;
use strict;

use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use base qw/ Error::Simple /;


# ORAC::Error::UserAbort ---------------------------------------------------
 
package ORAC::Error::UserAbort;

use base qw/ ORAC::Error /;

# ORAC::Error::FatalError --------------------------------------------------

package ORAC::Error::FatalError;

use base qw/ ORAC::Error /;

# --------------------------------------------------------------------------

1;

