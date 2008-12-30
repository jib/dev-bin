### includes all libs under this directory

package inc_all;

use strict;
use warnings;
use File::Basename qw[dirname];
require lib;

my $dir = dirname( __FILE__ );

for my $lib ( map { "$_/lib" } <$dir/../*> ) {
    next unless -d $lib;
    lib->import( $lib );
}

1;
