package Mojolicious::Plugin::XML::Template;
use Mojo::Base 'Mojolicious::Plugin::XML::Base';

our $PREFIX    = 'template';
our $NAMESPACE = 'http://sojolicio.us/ns/template';

sub add_foreach {
  my $self = shift;
  my %hash = ( over => shift );
  $hash{with} = shift if $_[0];
  return $self->add('foreach', \%hash);
};

sub add_if {
  return shift->add('if', { condition => shift });
};

sub to_template {
  my $self = shift;
  my $template = $self->to_pretty_xml;
  foreach (split(/\n/,$template)) {
    
  };
};

1;


__END__

Variables have to be declared in a mustache-like style, to be
xml compatible in every way.


better:
$feed->ep('print $variable');
my $in = $feed->ep_block('foreach (@array) {', '}');
$in->add(p => 'Hallo <%= $_ %>');

# Results in:
<ep:line>print $variable</ep:line>
<ep:block>foreach (@array) {<ep:inside>
<p>Hallo &lt;%= $_ %&gt;</p>
</ep:inside>}</ep:block>

# compiled:
% print $variable;
% foreach (@array) {
<p>Hallo <%= $_ %></p>
% };


my $foreach = $feed->foreach('@array' => '$test')
                   ->add('b' => 'Hallo {{$test}}!');

<template:foreach over="@array" with="$test">
  <b>Hallo {{$test}}!/b>
</template:foreach>

% foreach my $test (@array) {
  <b>Hallo <%= $test %></b>
% };
