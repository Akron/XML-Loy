#!/usr/bin/perl
use strict;
use warnings;

use lib '../../lib';

use Test::More;

use_ok('MojoX::XML::HostMeta');
use_ok('MojoX::XML::XRD');

{
  local $SIG{'__WARN__'} = sub {};
  ok( !MojoX::XML::HostMeta->new, 'Only extension');
};

ok(my $xrd = MojoX::XML::XRD->new, 'Constructor');
ok($xrd->add_extension('MojoX::XML::HostMeta'), 'Extend with hostmeta');

ok($xrd->add(Subject => 'http://sojolicio.us/'), 'Add subject');
ok($xrd->add_host('sojolicio.us'), 'Add host');

is($xrd->get_host, 'sojolicio.us', 'Get host');

is($xrd->at('*')->namespace, 'http://docs.oasis-open.org/ns/xri/xrd-1.0', 'Namespace');

is($xrd->at('Host')->namespace, 'http://host-meta.net/xrd/1.0', 'Namespace');
is($xrd->at('Host')->text, 'sojolicio.us', 'Host');

done_testing;


__END__
