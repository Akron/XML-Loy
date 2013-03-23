#!/usr/bin/perl
$|++;

package Atom;
use lib '../lib';

use XML::Loy with => (
  prefix => 'atom',
  namespace => 'http://www.w3.org/2005/Atom',
  mime => 'application/atom+xml'
);

# Add id
sub add_id {
  my $self = shift;
  my $id   = shift;
  return unless $id;
  my $element = $self->add('id', $id);
  $element->parent->attrs('xml:id' => $id);
  return $element;
};

package Fun;
use lib '../lib';

use XML::Loy with => (
  namespace => 'http://sojolicio.us/ns/fun',
  prefix => 'fun'
);

sub add_happy {
  my $self = shift;
  my $word = shift;

  my $cool = $self->add('-Cool');

  $cool->add('Happy',
	     {foo => 'bar'},
	     uc($word) . '!!! \o/ ' );
};


package Animal;
use lib '../lib';

use XML::Loy with => (
  namespace => 'http://sojolicio.us/ns/animal',
  prefix => 'anim'
);

package main;
use lib '../lib';

use Test::More;
use Test::Warn;

my $fun_ns  = 'http://sojolicio.us/ns/fun';
my $atom_ns = 'http://www.w3.org/2005/Atom';

ok(my $node = Fun->new('Fun'), 'Constructor');
ok(my $text = $node->add('Text', 'Hello World!'), 'Add element');

is($text->mime, 'application/xml', 'Mime type');
is($node->mime, 'application/xml', 'Mime type');

is(Fun->mime, 'application/xml', 'Mime class method');


is($node->at(':root')->namespace, $fun_ns, 'Namespace');
is($text->namespace, $fun_ns, 'Namespace');

ok(my $yeah = $node->add_happy('Yeah!'), 'Add yeah');

is($yeah->namespace, $fun_ns, 'Namespace');
is($node->at('Cool')->namespace, $fun_ns, 'Namespace');

ok($node = XML::Loy->new('object'), 'Constructor');

ok(!$node->at(':root')->namespace, 'Namespace');

warning_is { $node->add_happy('yeah') }
q{Can't locate "add_happy" in "XML::Loy"},
  'Warning';

ok($node->extension('Fun'), 'Add extension');
ok($yeah = $node->add_happy('Yeah!'), 'Add another yeah');

warning_is { $node->add_puppy('yeah') }
q{Can't locate "add_puppy" in "XML::Loy" with extension "Fun"},
  'Warning';

ok($node->extension('Animal'), 'Add extension');

warning_is { $node->add_puppy('yeah') }
q{Can't locate "add_puppy" in "XML::Loy" with extensions "Fun", "Animal"},
  'Warning';

is($yeah->namespace, $fun_ns, 'Namespace');
is($yeah->mime, 'application/xml', 'Mime type');
is($node->mime, 'application/xml', 'Mime type');

ok($text = $node->add('Text', 'Hello World!'), 'Add hello world');

ok(!$text->namespace, 'Namespace');

is(join(',', $text->extension), 'Fun,Animal', 'Extensions');
ok($text->extension('Atom'), 'Add Atom');
is(join(',', $text->extension), 'Fun,Animal,Atom', 'Extensions');

is($text->mime, 'application/xml', 'Mime type');

ok(my $id = $node->add_id('1138'), 'Add id');

is($id->namespace, $atom_ns, 'Namespace');

ok(!$node->at('Cool')->namespace, 'Namespace');

ok($node = Fun->new('Fun'), 'Get node');

ok($node->extension('Atom'), 'Add Atom 1');
ok(!$node->extension('Atom'), 'Add Atom 2');
ok(!$node->extension('Atom'), 'Add Atom 3');
is(join(',', $node->extension), 'Atom', 'Extensions');

$yeah = $node->add_happy('Yeah!');

ok($id = $node->add_id('1138'), 'Add id');

is($yeah->namespace, $fun_ns, 'Namespace');
is($node->at('Cool')->namespace, $fun_ns, 'Namespace');

is($id->namespace, $atom_ns, 'Namespace');

is($id->text, '1138', 'Content');


# New test
ok(my $xml = XML::Loy->new('entry'), 'Constructor');
is($xml->extension('Fun', 'Atom'), 2, 'Add 2 extensions');
is($xml->extension('Fun', 'Atom'), 0, 'Add  extensions');

ok($xml = Atom->new('entry'), 'Constructor');
ok($xml->add_id(45), 'Add id');

is($xml->mime, 'application/atom+xml', 'Check mime');


done_testing;

__END__

# Delegate:
$node = XML::Loy->new('object');
$node->extension('Stupid', 'Atom');

$yeah = $node->add_happy('Yeah!');

$id = $node->add_id('1138');

is($yeah->namespace, $fun_ns, 'Namespace');
is($node->at('Cool')->namespace, $fun_ns, 'Namespace');
is($id->namespace, $atom_ns, 'Namespace');
is($id->text, '1138', 'Content');
