use strict;
use warnings;

use FindBin;
use File::Fetch;
use Data::Dumper;
use CPANPLUS::Backend;

$File::Fetch::DEBUG     = 1;
$Data::Dumper::Indent   = 1;

### include dev-dirs in @INC;
my @Inc = grep { -d $_ } 
          map  { chomp; "$FindBin::Bin/../$_/lib" } `ls -1 $FindBin::Bin/..`;
my $U   = 'CPANPLUS::Internals::Utils';
my $cb  = CPANPLUS::Backend->new;

my %seen;
my %version;
my @mods =  map { 
                ### record the shortest module name
                ### available in a package
                $seen{ $_->package_name } = $_ 
                    if not $seen{ $_->package_name } 
                       or length $seen{ $_->package_name }->module > length $_->module;

                ### save all objects
                $_;
            }
            ### sort them by version, only let the first one pass
            grep { not $version{$_->package_name}++ }
            sort { $U->_vcmp( $b->package_version, $a->package_version ) }
            $cb->author_tree('KANE')->distributions;

### check our local stuff only
{   local @INC = @Inc;
    for my $obj ( sort { $a->module cmp $b->module } values %seen ) {
        
        ### version out of date
        if( $U->_vcmp( $obj->installed_version, $obj->version ) ) {
            
            print   "\n\n================================\n\n";
            printf  "%-42s %-18s %-18s\n",
                    $obj->module,
                    "[HAVE: " . $obj->installed_version   .'] ',
                    "[CPAN: " . $obj->version             .'] ';   

        ### same version, BUT there may be patches applied, check svk log
        } else {

            my $log_dir = $obj->installed_dir . '/..';
            my @out = grep { length } split /---+/, join '', `svk log $log_dir`;

            my $ver = $obj->version;

            my $msg;
            my $i;
            for( @out ) {
                last if /this\s+(?:be|is)\s+$ver/i;         # release
                last if /\ncopy\n/;                         # copy only
                next if /^\s*?r\d+:\s*?kane[^\n]+\n\s*$/;   # empty commit
                $i++;
                $msg .= $_;
            }
            
            ### nothing to see, move along
            next unless $i;

            print   "\n\n================================\n\n";
            printf  "%-42s (%s outstanding patches)\n%s", $obj->module, $i, $msg;
            
        }
    }
}
