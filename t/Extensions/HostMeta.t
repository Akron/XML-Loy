#!/usr/bin/perl
use strict;
use warnings;

use lib '../../lib';

use Test::More;

use_ok('XML::Loy::HostMeta');
use_ok('XML::Loy::XRD');

{
  local $SIG{'__WARN__'} = sub {};
  ok( !XML::Loy::HostMeta->new, 'Only extension');
};

ok(my $xrd = XML::Loy::XRD->new, 'Constructor');


__END__

ok($xrd->extension('XML::Loy::HostMeta'), 'Extend with hostmeta');

ok($xrd->subject('http://sojolicio.us/'), 'Add subject');
ok($xrd->host('sojolicio.us'), 'Add host');

is($xrd->host, 'sojolicio.us', 'Get host');

is($xrd->at('*')->namespace, 'http://docs.oasis-open.org/ns/xri/xrd-1.0', 'Namespace');

is($xrd->at('Host')->namespace, 'http://host-meta.net/xrd/1.0', 'Namespace');
is($xrd->at('Host')->text, 'sojolicio.us', 'Host');

done_testing;


__END__
