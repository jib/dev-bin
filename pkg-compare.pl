use strict;
use warnings;

use FindBin;
use File::Fetch;
use Data::Dumper;
use CPANPLUS::Backend;


$File::Fetch::DEBUG =1 ;
$Data::Dumper::Indent = 1;

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
        next unless $U->_vcmp( $obj->installed_version, $obj->version ) == 1;
        printf  "%-42s %-18s %-18s\n",
                $obj->module,
                "[HAVE: " . $obj->installed_version   .'] ',
                "[CPAN: " . $obj->version             .'] ';   
    }
}

#print join $/, map { $_->module } @mods;

#print Dumper \%seen;
