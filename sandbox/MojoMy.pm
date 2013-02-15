package MojoMy;
use Mojo::Base 'Mojo::DOM';

use strict;
use warnings;
use utf8;
use feature ();

# "Bender: Bite my shiny metal ass!"
use File::Basename qw(basename dirname);
use File::Spec::Functions 'catdir';
use Mojo::Util 'monkey_patch';

*AUTOLOAD = \&MojoMy::AUTOLOAD;

sub import {
  my $class = shift;

  return unless my $flag = shift;

  if ($flag eq '-base') {
    no strict 'refs';
    no warnings 'once';

    my $caller = caller;
    push @{"${caller}::ISA"}, __PACKAGE__;

    foreach (qw/namespace prefix/) {
      my $sub = 'sub ($) { $'. $caller . '::'.(uc $_).' = shift };';
      monkey_patch $caller, 'with_'.lc($_), eval($sub);
    };
  };

  strict->import;
  warnings->import;
  utf8->import;
  feature->import(':5.10');
};

1;
