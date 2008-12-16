use strict;
use warnings;


use FindBin;
use File::Fetch;
use Data::Dumper;
use CPANPLUS::Backend;
use CPANPLUS::Shell             qw[Default];
use LWP::Simple                 qw[get];

$File::Fetch::DEBUG     = 1;
$Data::Dumper::Indent   = 1;

### RT uri
my $ListUri = 'http://rt.cpan.org/NoAuth/bugs.tsv?Dist=';

### include dev-dirs in @INC;
my @Inc = grep { -d $_ } 
          map  { chomp; "$FindBin::Bin/../$_/lib" } `ls -1 $FindBin::Bin/..`;
my $U   = 'CPANPLUS::Internals::Utils';
my $sh  = CPANPLUS::Shell->new;
my $cb  = $sh->backend;

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
{   for my $obj ( sort { $a->module cmp $b->module } values %seen ) {

        ### header
        printf "\n\n================ %s ===============\n\n", $obj->module;

        ### version info
        {   my $have = do {
                local @INC = @Inc;
                local $Module::Load::Conditional::CHECK_INC_HASH = 0;
                $obj->installed_version
            };
            
            my $core = do {
                local @INC = qw[/Users/kane/sources/perl-dev/perl-current/lib];
                local $Module::Load::Conditional::CHECK_INC_HASH = 0;
                $obj->installed_version
            };
            
            my @to_update;
            {   no warnings 'numeric';
                push @to_update, 'CPAN' if $obj->version and $obj->version != $have;
                push @to_update, 'CORE' if( $core 
                                            and $have !~ /_/
                                            and $have != $core 
                                         );
            }
            
            my $update = @to_update 
                            ? '*** UPDATE ' . join(' & ', @to_update) . ' ***'
                            : '';

    
            printf  "%-12s %-14s %-14s %-14s %-20s\n\n",
                    'VERSIONS',
                    "[HAVE: " . $have           .'] ',
                    "[CORE: " . $core           .'] ',
                    "[CPAN: " . $obj->version   .'] ',
                    $update;
        }
        
        ### outstanding issues in RT
        {   ### don't care about the diagnostics from this module
            no warnings 'redefine';
            local *CPANPLUS::Shell::Default::Plugins::RT::msg   = sub {};
            local *CPANPLUS::Shell::Default::Plugins::RT::msg   = sub {};
            local *CPANPLUS::Shell::Default::Plugins::RT::error = sub {};
            local *CPANPLUS::Shell::Default::Plugins::RT::error = sub {};

            print   "Outstanding issues in RT:\n";
            $sh->dispatch_on_input( input => '/rt ' . $obj->module );        
        }
        
        ### same version, BUT there may be patches applied, check svk log
        {   local @INC = @Inc;
            unless( $U->_vcmp( $obj->installed_version, $obj->version ) ) {

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
    
                printf  "%-42s (%s outstanding patches)\n%s", $obj->module, $i, $msg;
                
            }
        }
    }
}
