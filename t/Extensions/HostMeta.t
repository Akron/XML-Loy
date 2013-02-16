#!/usr/bin/perl
use strict;
use warnings;

use lib '../lib';

use Test::More tests => 8;

use_ok('MojoX::XML::HostMeta');
use_ok('MojoX::XML::XRD');

$SIG{'__WARN__'} = sub {};
ok( !MojoX::XML::HostMeta->new, 'Only extension');
$SIG{'__WARN__'} = undef;

my $xrd = MojoX::XML::XRD->new;

ok($xrd, 'XRD');

ok($xrd->add_extension('MojoX::XML::HostMeta'), 'HostMeta');

ok($xrd->add_host('sojolicio.us'), 'Add host');

is($xrd->at('Host')->namespace, 'http://host-meta.net/xrd/1.0', 'Namespace');
is($xrd->at('Host')->text, 'sojolicio.us', 'Host');

