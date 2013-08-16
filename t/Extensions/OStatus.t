#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib', '../lib', '../../lib';

use Test::More;

use_ok('XML::Loy::Atom');

ok(my $atom = XML::Loy::Atom->new('entry'), 'New entry');

ok($atom->extension(-OStatus, -ActivityStreams), 'Add extension');

ok($atom->actor(name => 'Akron'), 'Add author');
ok($atom->verb_unfollow, 'Add verb');
is($atom->verb, 'http://ostatus.org/schema/1.0/unfollow', 'Get verb');
ok($atom->verb_unfavorite, 'Add verb');
is($atom->verb, 'http://ostatus.org/schema/1.0/unfavorite', 'Get verb');
ok($atom->verb_leave, 'Add verb');
is($atom->verb, 'http://ostatus.org/schema/1.0/leave', 'Get verb');

ok($atom->object(name => 'Peter'), 'Add object');

ok($atom->attention('http://sojolicio.us/user/peter'), 'Add new attention');
is($atom->link('ostatus:attention')->[0]->attr('href'), 'http://sojolicio.us/user/peter', 'Attention link');
is($atom->attention, 'http://sojolicio.us/user/peter', 'Attention link');

ok($atom->conversation('http://sojolicio.us/conv/34'), 'Add new conversation');
is($atom->link('ostatus:conversation')->[0]->attr('href'), 'http://sojolicio.us/conv/34', 'Conversation link');
is($atom->conversation, 'http://sojolicio.us/conv/34', 'Conversation link');

done_testing;
