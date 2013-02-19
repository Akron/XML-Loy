#!/usr/bin/env perl
use 5.010001;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION_FROM => 'lib/MojoX/XML.pm',
  NAME         => 'MojoX::XML',
  AUTHOR       => 'Nils Diewald',
  PREREQ_PM => {
    'Mojolicious' => 3.43
  },
  LICENSE      => 'perl',
  META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
      repository  => 'https://github.com/Akron/MojoX-XML'
    }
  },
  test => {TESTS => 't/*.t t/Extensions/*.t' }
);
