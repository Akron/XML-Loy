#!/usr/bin/env perl
use 5.010001;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'XML::Loy',
  AUTHOR       => 'Nils Diewald',
  ABSTRACT     => 'Extensible XML Reader and Writer',
  VERSION_FROM => 'lib/XML/Loy.pm',
  BUILD_REQUIRES => {
    'Test::More' => 0,
    'Test::Warn' => '0.24'
  },
  PREREQ_PM => {
    'Mojolicious' => '3.89'
  },
  LICENSE      => 'perl',
  META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
      repository  => 'https://github.com/Akron/XML-Loy'
    }
  },
  test => {TESTS => 't/*.t t/Extensions/*.t' }
);
