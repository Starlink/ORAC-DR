package ORAC::Constants;

=head1 NAME

ORAC::Constants - Constants available to the ORAC system

=head1 SYNOPSIS

  use ORAC::Constants;
  use ORAC::Constants qw/ORAC__OK/;
  use ORAC::Constants qw/:status/;

=head1 DESCRIPTION

Provide access to ORAC constants.

=cut

use vars qw/ $VERSION /;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

require Exporter;

@ISA = qw/Exporter/;

@EXPORT_OK = qw/ORAC__OK ORAC__ERROR/;

%EXPORT_TAGS = (
		'status'=>[qw/ ORAC__OK ORAC__ERROR/]
	       );

Exporter::export_tags('status');

=head1 CONSTANTS

The following constants are available from this module:

=over 4

=item B<ORAC__OK>

This constant contains the definition of good ORAC status.

=cut

use constant ORAC__OK => 0;


=item B<ORAC__ERROR>

This constant containst the definition of bad ORAC status.

=cut

use constant ORAC__ERROR => -1;

# Did want to try implementing constants like this but
# is easier to use the constant module.
# *ORAC__OK = \0;


=back

=head1 TAGS

Individual sets of constants can be imported by 
including the module with tags. For example:

  use ORAC::Constants qw/:status/;

will import all constants associated with ORAC status checking.

The available tags are:

=over 4

=item :status

Constants associated with ORAC status checking: ORAC__OK and ORAC__ERROR.

=back

=head1 USAGE

The constants can be used as if they are subroutines.
For example, if I want to print the value of ORAC__ERROR I can

  use ORAC::Constants;
  print ORAC_ERROR;

or

  use ORAC::Constants ();
  print ORAC::Constants::ORAC__ERROR;

=head1 SEE ALSO

L<constants>

=head1 REVISION

$Id$

=head1 AUTHOR

Tim Jenness (t.jenness@jach.hawaii.edu) and
Frossie Economou (frossie@jach.hawaii.edu)

=head1 REQUIREMENTS

The C<constants> package must be available. This is a standard
perl package.

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut



1;
