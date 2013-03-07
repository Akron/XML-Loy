package XML::Loy::ActivityStreams;

our $NS;
BEGIN { $NS = 'http://activitystrea.ms/schema/1.0/' };

use XML::Loy with => (
  prefix    => 'activity',
  namespace => $NS
);

# Todo: support to_json
# Todo: verbs and object-types may need namespaces

use Carp qw/carp/;

# No constructor
sub new {
  carp 'Only use ' . __PACKAGE__ . ' as an extension to Atom';
  return;
};

# Add ActivityStreams actor
sub actor {
  my $self  = shift;

  # Set actor
  if ($_[0]) {
    my $actor = $self->author( @_ );

    # Maybe: $NS . 'person';
    $actor->set('object-type', 'person');
    return $actor;
  }

  # Get actor
  else {
    return $self->author->[0];
  };
};


# Add ActivityStreams verb
sub verb {
  my $self = shift;

  # Set verb
  if ($_[0]) {
    my $verb = shift;
    return $self->add('verb', $verb);
  }

  # Get verb
  else {
    my $verb = $self->children('activity:verb');

warn $verb;

    return unless $verb->[0];

    $verb = $verb->[0]->text;

warn '++++++++++++++++';

    # Add ns prefix if not given
    if (index($verb, '/') == -1) {
      $verb = $NS . lc $verb;
    };

    return $verb;
  }
};


# Add ActivityStreams object
sub object {
  my $self = shift;
  return $self->_target_object(object => @_ );
};


# Add ActivityStreams target
sub target {
  my $self = shift;
  return $self->_target_object(target => @_ );
};


sub _target_object {
  my $self = shift;
  my $type = shift;

  if ($_[0]) {
    my %params = @_;

    my $obj = $self->set($type);

    $obj->id( delete $params{id} ) if exists $params{id};

    if (exists $params{type}) {

      my $type = delete $params{type};

      $obj->set('object-type', $type);
    };

    foreach (keys %params) {
      $obj->add('-' . $_ => $params{$_});
    };

    return $obj;
  }

  else {
    my $obj = $self->children($type);
    return unless $obj->[0];

    my $object_type = $obj->at('object-type');

    if (index($object_type->text, '/') == -1) {
      $object_type->replace_content($NS . lc($object_type->text));
    };

    return $obj;
  };
};



1;

__END__

=pod

=head1 NAME

Mojolicious::Plugin::XML::ActivityStreams - ActivityStreams (Atom) Plugin

=head1 SYNOPSIS

  # Mojolicious
  $app->plugin('XML' => {
    new_activity => ['Atom','ActivityStreams']
  });

  # Mojolicious::Lite
  plugin 'XML' => {
    new_activity => ['Atom','ActivityStreams']
  };

  # In Controllers
  my $activity = $self->new_activity(<<'ACTIVITY');
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <entry xmlns="http://www.w3.org/2005/Atom"
         xmlns:activity="http://activitystrea.ms/schema/1.0/">
    <author>
      <name>Fry</name>
      <activity:object-type>person</activity:object-type>
    </author>
    <activity:verb>follow</activity:verb>
    <activity:object>
      <activity:object-type>person</activity:object-type>
      <displayName>Leela</displayName>
    </activity:object>
    <title type="xhtml">
      <div xmlns="http://www.w3.org/1999/xhtml"><p>Fry follows Leela</p></div>
    </title>
  </entry>
  ACTIVITY

  my $activity = $self->new_activity('entry');

  my $author = $activity->new_person(name => 'Fry');
  for ($activity) {
    $_->add_actor($author);
    $_->add_verb('follow');
    $_->add_object(type => 'person',
                   displayName => 'Leela');
    $_->add_title(xhtml => '<p>Fry follows Leela</p>');
  };

  $self->render_xml($activity);

=head1 DESCRIPTION

L<Mojolicious::Plugin::XML::ActivityStreams> is an extension
for L<Mojolicious::Plugin::XML::Atom> and provides several functions
for the work with the Atom ActivityStreams Format as described in
L<http://activitystrea.ms/|ActivityStrea.ms>.

=head1 HELPERS

=head1 METHODS

=head2 C<add_actor>

  my $person = $activity->new_person( name => 'Bender',
                                      uri  => 'acct:bender@example.org');
  my $actor = $atom->add_actor($person);

Adds actor information to the ActivityStreams object.
Accepts a person construct (see L<new_person> in
L<Mojolicious::Plugin::Atom::Document>) or the
parameters accepted by L<new_person>.

=head2 C<add_verb>

  $activity->add_verb('follow');

Adds verb information to the ActivityStreams object.
Accepts a verb string.

=head2 C<add_object>

  $activity->add_object( type => 'person',
                         displayName => 'Leela' );

Adds object information to the ActivityStreams object.
Accepts various parameters depending on the object's type.

=head2 C<add_target>

  $activity->add_target( type => 'person',
                         displayName => 'Fry' );

Adds target information to the ActivityStreams object.
Accepts various parameters depending on the object's type.

=head1 DEPENDENCIES

L<Mojolicious>,
L<Mojolicious::Plugin::XML>,
L<Mojolicious::Plugin::XML::Atom>.

=head1 AVAILABILITY

  https://github.com/Akron/Sojolicious

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012, Nils Diewald.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
