# ORAC::Error --------------------------------------------------------------

package ORAC::Error;

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

