#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;
use File::Temp qw/:POSIX/;

use lib (
  't',
  'lib',
  '../lib',
  '../../lib',
  '../../../lib'
);

use_ok('XML::Loy');
use_ok('XML::Loy::File');

warning_is {
  XML::Loy::File->new;
} 'Only use XML::Loy::File as an extension', 'Only extension';


ok(my $xml = XML::Loy->new, 'XML::Loy');

ok($xml->extension(-File), 'Extend with file');

ok($xml = $xml->add('myroot'), 'New root');

ok($xml->add(p => 'My first paragraph'), 'Add Paragraph 1');
ok($xml->add(p => 'My second paragraph'), 'Add Paragraph 2');



my $file_name = tmpnam();

ok($xml->save($file_name), 'Save temporarily');

is($xml->file, $file_name, 'Load file name');

ok(my $xml_2 = XML::Loy->new, 'New document');

warning_is {
  $xml_2->file;
} q{Can't locate "file" in "XML::Loy"}, 'Only extension';

ok($xml_2->extension(-File), 'Add extension');

diag $xml_2->to_xml;

ok($xml_2 = $xml_2->load($file_name), 'Load file name');

is($xml_2->file, $file_name, 'File name correct');

is($xml_2->find('p')->[0]->text, 'My first paragraph', 'First para');

is($xml_2->find('p')->[1]->text, 'My second paragraph', 'Second para');

diag $xml_2->to_xml;

exit;

1;
