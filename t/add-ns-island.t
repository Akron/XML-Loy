#!/usr/bin/perl
use strict;
use warnings;

use lib '../lib';
use lib '../../lib';

use Test::More;

use_ok('MojoX::XML');

my $i = 1;

my $x = MojoX::XML->new;

ok($x->namespace('html' => 'urn:w3-org-ns:HTML'), 'Add prefix for namespace');

ok($x->parse(<<'XML'), 'New MojoX::XML doc');
<?xml version="1.0"?>
<!-- initially, the default namespace is "books" -->
<book xmlns='urn:loc.gov:books' xmlns:isbn='urn:ISBN:0-395-36341-6'>
  <title>Cheaper by the Dozen</title>
  <isbn:number>1568491379</isbn:number>
  <notes>
    <!-- make HTML the default namespace for some commentary -->
    <p xmlns='urn:w3-org-ns:HTML'>This is a <i>funny</i> book!</p>
  </notes>
</book>
XML

my $target = <<'TARGET';
<?xml version="1.0"?>
<!-- initially, the default namespace is "books" -->
<book xmlns="urn:loc.gov:books" xmlns:isbn="urn:ISBN:0-395-36341-6" xmlns:html="urn:w3-org-ns:HTML">
  <title>Cheaper by the Dozen</title>
  <isbn:number>1568491379</isbn:number>
  <notes>
    <!-- make HTML the default namespace for some commentary -->
    <html:p>This is a <html:i>funny</html:i> book!</html:p>
  </notes>
</book>
TARGET

my $string = $x->to_pretty_xml;



done_testing;
