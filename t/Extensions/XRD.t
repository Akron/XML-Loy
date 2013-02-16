#!/usr/bin/env perl
use strict;
use warnings;

use lib '../lib', '../../lib';

use Test::More;

use Mojo::JSON;

use_ok('MojoX::XML::XRD');

# Synopsis

ok(my $xrd = MojoX::XML::XRD->new, 'Empty Constructor');
ok($xrd->add(Subject => 'http://sojolicio.us/'), 'Add subject');
ok($xrd->add(Alias => 'https://sojolicio.us/'), 'Add alias');

ok($xrd->add_link('lrdd' => { template => '/.well-known/webfinger?resource={uri}'}),
     'Add link');
ok($xrd->add_property('describedby' => '/me.foaf'), 'Add property');
ok($xrd->add_property('private'), 'Add property');

is($xrd->to_pretty_xml, << 'XRD', 'Pretty Print');
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Subject>http://sojolicio.us/</Subject>
  <Alias>https://sojolicio.us/</Alias>
  <Link rel="lrdd"
        template="/.well-known/webfinger?resource={uri}" />
  <Property type="describedby">/me.foaf</Property>
  <Property type="private"
            xsi:nil="true" />
</XRD>
XRD


my $json = Mojo::JSON->new;

my $jrd = $json->decode($xrd->to_json);

is($jrd->{subject}, 'http://sojolicio.us/', 'JRD Subject');
is($jrd->{aliases}->[0], 'https://sojolicio.us/', 'JRD Alias');
ok(!$jrd->{aliases}->[1], 'JRD Alias');
is($jrd->{links}->[0]->{rel}, 'lrdd', 'JRD link 1');
is($jrd->{links}->[0]->{template}, '/.well-known/webfinger?resource={uri}', 'JRD link 1');
ok(!$jrd->{properties}->{private}, 'JRD property 1');
is($jrd->{properties}->{describedby}, '/me.foaf', 'JRD property 2');



ok(my $element = $xrd->add_property(profile => '/akron.html'), 'Add property');

is($element->text, '/akron.html', 'Return property');

is($xrd->at('Property[type=profile]')->text, '/akron.html', 'Get Property');

ok(!$xrd->get_property, 'Get Property without type');

is($xrd->get_property('profile')->text, '/akron.html', 'Get Property');

ok($element = $xrd->add_link(hcard => '/me.hcard'), 'Add link');

ok($element->attrs('href'), 'Return link');

ok($element->add(Title => 'My hcard'), 'Add title');

is($xrd->at('Link[rel=hcard] Title')->text, 'My hcard', 'Get title');

ok($element = $xrd->add_link(lrdd2 => {template => '/wf?resource={uri}'}), 'Add link');

ok($element->add(Title => 'My Webfinger'), 'Add title');

is($xrd->at('Link[rel=lrdd2] Title')->text, 'My Webfinger', 'Get title');

is($xrd->get_link('hcard')->at('Title')->text, 'My hcard', 'Get title');

is($xrd->at('Link[rel=lrdd2] Title')->text, 'My Webfinger', 'Get title');
is($xrd->at('Link[rel=lrdd2]')->at('Title')->text, 'My Webfinger', 'Get title');
is($xrd->get_link('lrdd2')->all_text, 'My Webfinger', 'Get title');


$xrd = MojoX::XML::XRD->new(<<XRD);
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Subject>http://sojolicio.us/</Subject>
  <Alias>https://sojolicio.us/</Alias>
  <Link rel="lrdd"
        template="/.well-known/webfinger?resource={uri}" />
  <Property type="describedby">/me.foaf</Property>
  <Property type="private"
            xsi:nil="true" />
</XRD>
XRD

is($xrd->get_link('lrdd')->attrs('template'), '/.well-known/webfinger?resource={uri}', 'Get link');


$xrd = MojoX::XML::XRD->new(<<'JRD');
  {"subject":"http:\/\/sojolicio.us\/",
"aliases":["https:\/\/sojolicio.us\/"],
"links":[{"rel":"lrdd",
"template":"\/.well-known\/webfinger?resource={uri}"}],
"properties":{"private":null,"describedby":"\/me.foaf"}}
JRD

is($xrd->at('Alias')->text, 'https://sojolicio.us/', 'Get Alias');



##################################
# Old tests

ok($xrd = MojoX::XML::XRD->new, 'Constructor');

my $xrd_string = $xrd->to_pretty_xml;
$xrd_string =~ s/\s//g;

is ($xrd_string, '<?xmlversion="1.0"encoding="UTF-8"'.
                 'standalone="yes"?><XRDxmlns="http:'.
                 '//docs.oasis-open.org/ns/xri/xrd-1'.
                 '.0"xmlns:xsi="http://www.w3.org/20'.
                 '01/XMLSchema-instance"/>',
                 'Initial XRD');


my $subnode_1 = $xrd->add('Link',{ rel => 'foo' }, 'bar');

is(ref($subnode_1), 'MojoX::XML::XRD',
   'Subnode added');

is($xrd->at('Link')->attrs('rel'), 'foo', 'Attribute');
is($xrd->at('Link[rel="foo"]')->text, 'bar', 'Text');

my $subnode_2 = $subnode_1->comment("Foobar Link!");

is($subnode_1, $subnode_2, "Comment added");

$xrd = MojoX::XML::XRD->new(<<'XRD');
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <!-- Foobar Link! -->
  <Link rel="foo">bar</Link>
</XRD>
XRD

ok($xrd, 'XRD loaded');

is($xrd->at('Link[rel="foo"]')->text, 'bar', "DOM access Link");
is($xrd->get_link('foo')->text, 'bar', "DOM access Link");

$xrd->add('Property', { type => 'bar' }, 'foo');

is($xrd->at('Property[type="bar"]')->text, 'foo', 'DOM access Property');
is($xrd->get_property('bar')->text, 'foo', 'DOM access Property');

is_deeply(
    Mojo::JSON->new->decode($xrd->to_json),
    { links =>
	[ { rel => 'foo' } ] =>
	  properties =>
	    { bar  => 'foo' } },
    'Correct JRD');

# From https://tools.ietf.org/html/draft-hammer-hostmeta-17#appendix-A
my $jrd_doc = <<'JRD';
{
  "subject":"http://blog.example.com/article/id/314",
  "expires":"2010-01-30T09:30:00Z",
  "aliases":[
    "http://blog.example.com/cool_new_thing",
    "http://blog.example.com/steve/article/7"],

  "properties":{
    "http://blgx.example.net/ns/version":"1.3",
    "http://blgx.example.net/ns/ext":null
  },
  "links":[
    {
      "rel":"author",
      "type":"text/html",
      "href":"http://blog.example.com/author/steve",
      "titles":{
        "default":"About the Author",
        "en-us":"Author Information"
      },
      "properties":{
        "http://example.com/role":"editor"
      }
    },
    {
      "rel":"author",
      "href":"http://example.com/author/john",
      "titles":{
        "default":"The other author"
      }
    },
    {
      "rel":"copyright",
      "template":"http://example.com/copyright?id={uri}"
    }
  ]
}
JRD

my $xrd_doc = <<'XRD';
<?xml version='1.0' encoding='UTF-8'?>
<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'
     xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
  <Subject>http://blog.example.com/article/id/314</Subject>
  <Expires>2010-01-30T09:30:00Z</Expires>
  <Alias>http://blog.example.com/cool_new_thing</Alias>
  <Alias>http://blog.example.com/steve/article/7</Alias>
  <Property type='http://blgx.example.net/ns/version'>1.2</Property>
  <Property type='http://blgx.example.net/ns/version'>1.3</Property>
  <Property type='http://blgx.example.net/ns/ext' xsi:nil='true' />
  <Link rel='author' type='text/html'
        href='http://blog.example.com/author/steve'>
    <Title>About the Author</Title>
    <Title xml:lang='en-us'>Author Information</Title>
    <Property type='http://example.com/role'>editor</Property>
  </Link>
  <Link rel='author' href='http://example.com/author/john'>
    <Title>The other guy</Title>
    <Title>The other author</Title>
  </Link>
  <Link rel='copyright'
        template='http://example.com/copyright?id={uri}' />
</XRD>
XRD

$xrd = MojoX::XML::XRD->new($xrd_doc);

is_deeply(
  $json->decode($xrd->to_json),
  $json->decode($jrd_doc), 'JRD'
);

$xrd = MojoX::XML::XRD->new($jrd_doc);

is_deeply(
  $json->decode($xrd->to_json),
  $json->decode($jrd_doc), 'JRD'
);

done_testing;

exit;

__END__
