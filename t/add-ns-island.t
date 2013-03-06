#!/usr/bin/perl
package MyTestXML;
use strict;
use warnings;
use lib '../lib';
use lib '../../lib';

use XML::Loy with => {
  namespace => 'http://test',
  prefix => 'test'
};

package main;
use strict;
use warnings;

use Test::More;
use Test::Warn;

my $x = MyTestXML->new;


use Data::Dumper;

diag Dumper $x;

__END__

warning_is {
  $x->namespace(html => 'urn:w3-org-ns:HTML')
} 'Unable to set namespace without root element', 'Unable to set namespace';

warning_is {
  $x->extension('Peter')
} 'Unable to set namespace without root element', 'Unable to set namespace';


ok($x->parse(<<'XML'), 'New XML::Loy doc');
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

ok($x->namespace(html => 'urn:w3-org-ns:HTML'), 'Set namespace');



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
