use warnings;
use strict;
use Test::More;
use utf8;

plan tests => 25;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils');
use_ok('Thruk::Utils::Status');
use_ok('Monitoring::Livestatus::Class::Lite');

my $query = "name = 'test'";
_test_filter($query, 'Filter: name = test');
is($query, "name = 'test'", "original string unchanged");
_test_filter('name ~~ "test"', 'Filter: name ~~ test');
_test_filter('groups >= "test"', 'Filter: groups >= test');
_test_filter('check_interval != 5', 'Filter: check_interval != 5');
_test_filter('host = "a" AND host = "b"', "Filter: host = a\nFilter: host = b\nAnd: 2");
_test_filter('host = "a" AND host = "b" AND host = "c"', "Filter: host = a\nFilter: host = b\nFilter: host = c\nAnd: 3");
_test_filter('host = "a" OR host = "b"', "Filter: host = a\nFilter: host = b\nOr: 2");
_test_filter('host = "a" OR host = "b" OR host = "c"', "Filter: host = a\nFilter: host = b\nFilter: host = c\nOr: 3");
_test_filter("(name = 'test')", 'Filter: name = test');
_test_filter('(host = "a" OR host = "b") AND host = "c"', "Filter: host = a\nFilter: host = b\nOr: 2\nFilter: host = c\nAnd: 2");
_test_filter("name = 'te\"st'", 'Filter: name = te"st');
_test_filter("name = 'te(st)'", 'Filter: name = te(st)');
_test_filter("host_name = \"test\" or host_name = \"localhost\" and status = 0", "Filter: host_name = test\nFilter: host_name = localhost\nOr: 2\nFilter: status = 0\nAnd: 2");
_test_filter(' name ~~  "test"  ', 'Filter: name ~~ test');
_test_filter('host = "localhost" AND time > 1 AND time < 10', "Filter: host = localhost\nFilter: time > 1\nFilter: time < 10\nAnd: 3");
_test_filter('host = "localhost" AND (time > 1 AND time < 10)', "Filter: host = localhost\nFilter: time > 1\nFilter: time < 10\nAnd: 2\nAnd: 2");
_test_filter('last_check <= "-7d"', 'Filter: last_check <= '.(time() - 86400*7));
_test_filter('last_check <= "now + 2h"', 'Filter: last_check <= '.(time() + 7200));
_test_filter('last_check <= "lastyear"', 'Filter: last_check <= '.Thruk::Utils::_expand_timestring("lastyear"));
_test_filter('(host_groups ~~ "g1" AND host_groups ~~ "g2")  OR (host_name = "h1" and display_name ~~ ".*dn.*")', "Filter: host_groups ~~ g1\nFilter: host_groups ~~ g2\nAnd: 2\nFilter: host_name = h1\nFilter: display_name ~~ .*dn.*\nAnd: 2\nOr: 2");

sub _test_filter {
    my($filter, $expect) = @_;
    my $f = Thruk::Utils::Status::parse_lexical_filter($filter);
    my $s = Monitoring::Livestatus::Class::Lite->new('test.sock')->table('hosts')->filter($f)->statement(1);
    $s    = join("\n", @{$s});
    $s      =~ s/(\d{10})/&_round_timestamps($1)/gemxs;
    $expect =~ s/(\d{10})/&_round_timestamps($1)/gemxs;
    is($s, $expect, 'got correct statement');
}

# round timestamp by 30 seconds to avoid test errors on slow machines
sub _round_timestamps {
    my($x) = @_;
    $x = int($x / 30) * 30;
    return($x);
}

################################################################################
{
    my $c = TestUtils::get_c();
    my $params = {
        'dfl_s0_hostprops' => '0',
        'dfl_s0_hoststatustypes' => '15',
        'dfl_s0_op' => [
                        '=',
                        '~'
                        ],
        'dfl_s0_serviceprops' => '0',
        'dfl_s0_servicestatustypes' => '31',
        'dfl_s0_type' => [
                            'host',
                            'service'
                        ],
        'dfl_s0_val_pre' => [
                            '',
                            ''
                            ],
        'dfl_s0_value' => [
                            'localhost',
                            'http'
                        ],
        'dfl_s1_hostprops' => '0',
        'dfl_s1_hoststatustypes' => '15',
        'dfl_s1_op' => '=',
        'dfl_s1_serviceprops' => '0',
        'dfl_s1_servicestatustypes' => '31',
        'dfl_s1_type' => 'host',
        'dfl_s1_val_pre' => '',
        'dfl_s1_value' => 'test'
    };
    my $exp = [{
            'host_prop_filtername'          => 'Any',
            'host_statustype_filtername'    => 'All',
            'hostprops'                     => 0,
            'hoststatustypes'               => 15,
            'service_prop_filtername'       => 'Any',
            'service_statustype_filtername' => 'All',
            'serviceprops'                  => 0,
            'servicestatustypes'            => 31,
            'text_filter'                   => [{
                    'op'        => '=',
                    'type'      => 'host',
                    'val_pre'   => '',
                    'value'     => 'localhost'
                },
                {
                    'op'        => '~',
                    'type'      => 'service',
                    'val_pre'   => '',
                    'value'     => 'http'
                }]
        }, {
            'host_prop_filtername' => 'Any',
            'host_statustype_filtername' => 'All',
            'hostprops' => 0,
            'hoststatustypes' => 15,
            'service_prop_filtername' => 'Any',
            'service_statustype_filtername' => 'All',
            'serviceprops' => 0,
            'servicestatustypes' => 31,
            'text_filter' => [{
                    'op'        => '=',
                    'type'      => 'host',
                    'val_pre'   => '',
                    'value'     => 'test'
                }],
    }];
    my $got = Thruk::Utils::Status::get_searches($c, '', $params);
    is_deeply($got, $exp, "parsed search items from params")
}
