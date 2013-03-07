package XML::Loy::Atom;
use Carp qw/carp/;
use Mojo::ByteStream 'b';
use XML::Loy::Date::RFC3339;

our @CARP_NOT;

use XML::Loy with => (
  mime      => 'application/atom+xml',
  prefix    => 'atom',
  namespace => 'http://www.w3.org/2005/Atom'
);


# Namespace declaration
use constant XHTML_NS => 'http://www.w3.org/1999/xhtml';

# Todo:
#  - see http://search.cpan.org/dist/XML-Atom-SimpleFeed
#  - Do not use constant

# New date construct
sub new_date {
  return XML::Loy::Date::RFC3339->new( $_[1] || time );
};


# New person construct
sub new_person {
  my $self = shift;
  my $person = ref($self)->SUPER::new('person');

  my %hash = @_;
  $person->set($_ => $hash{$_}) foreach keys %hash;
  return $person;
};


# New text construct
sub new_text {
  my $self = shift;

  return unless $_[0];

  my $class = ref($self);

  # Expect empty html
  unless (defined $_[1]) {
    return $class->SUPER::new(
      text => {
	type  => 'text',
	-type => 'raw'
      } => shift);
  };

  my ($type, $content, %hash);

  # Only textual content
  if (!defined $_[2]) {
    $type = shift;
    $content = shift;
  }

  # Hash definition
  elsif ((@_ % 2) == 0) {
    %hash = @_;

    $type = delete $hash{type} || 'text';

    if (exists $hash{src}) {
      return $class->SUPER::new(
	text => { type => $type, %hash }
      );
    };

    $content = delete $hash{content} or return;
  };

  my $c_node;

  # xhtml
  if ($type eq 'xhtml') {

    # Create new by hash
    $c_node = $class->SUPER::new(
      text => {
	type => $type,
	%hash
      });

    # Content is raw and thus nonindented
    # But also escaped
    $c_node->add(
      -div => {
	xmlns => XHTML_NS,
	-type => 'raw'
      })->append_content($content);
  }

  # html or text
  elsif ($type eq 'html' || $type =~ /^text/i) {

    $c_node = $class->new(
      text => {
	'type'  => $type,
	'-type' => 'raw',
	'xml:space' => 'preserve',
	%hash
      } => $content . ''
    );
  }

  # xml media type
  elsif ($type =~ /[\/\+]xml(;.+)?$/i) {
    $c_node = $class->new(
      text => {
	type  => $type,
	-type => 'raw',
	%hash
      } => $content);
  }

  # all other media types
  else {
    $c_node = $class->new(
      text => {
	type => $type,
	-type => 'armour',
	%hash
      },
      $content);
  };

  return $c_node;
};


# Add author information
sub author {
  my $self = shift;

  # Add author
  return $self->_add_person(author => @_) if $_[0];

  # Get author information
  return $self->_get_information_array('author');
};


# Add category information
sub category {
  my $self = shift;

  # Set category
  if ($_[0]) {
    if (!defined $_[1]) {
      return $self->add(category => { term => shift });
    };

    return $self->add(category => { @_ } );
  };

  # Get category
  my $coll = $self->_get_information_array('category')
    or return;

  if ($coll->[0]) {
    $coll->map( sub { $_ = $_->{term} });
  };
};

# Add contributor information
sub contributor {
  my $self = shift;

  # Add contributor
  return $self->_add_person(contributor => @_) if $_[0];

  # Get contributor information
  return $self->_get_information_array('contributor');
};


# Add content information
sub content {
  my $self = shift;

  # Set content
  return $self->__text(set => content => @_) if $_[0];

  # Return content
  return $self->_get_information_single('content');
};


# Set or get entry
sub entry {
  my $self = shift;

  # Is object
  if (ref $_[0]) {
    return $self->add(@_);
  }

  # Get entry
  elsif ($_[0] && !$_[1]) {

    my $id = shift;

    # Get based on xml:id
    my $entry = $self->at(qq{entry[xml\:id="$id"]});
    return $entry if $entry;

    # Get based on <entry><id>id</id></entry>
    my $idc = $self->find('entry > id')->grep(sub { $_->text eq $id });

    return unless $idc && $idc->[0];

    return $idc->[0]->parent;
  };

  my %hash = @_;
  my $entry;

  # Set id additionally as xml:id
  if (exists $hash{id}) {
    $entry = $self->add(
      entry => {'xml:id' => $hash{id}}
    );
  }

  # No id given
  else {
    $entry = $self->add('entry');
  };

  # Add information
  foreach (keys %hash) {
    $entry->add($_, $hash{$_});
  };

  return $entry;
};


# Set or get generator information
sub generator {
  shift->_simple_feed_info(generator =>  @_);
};


# Set or get icon information
sub icon {
  shift->_simple_feed_info(icon =>  @_);
};


# Add id
sub id {
  my $self = shift;

  # Get id
  unless ($_[0]) {
    my $id_obj = $self->_get_information_single('id');
    return $id_obj->text if $id_obj;
    return;
  };

  my $id = shift;
  my $element = $self->set(id => $id);
  return unless $element;

  # Add xml:id also
  $element->parent->attrs('xml:id' => $id);
  return $self;
};


# Add link information
sub link {
  my $self = shift;

  if ($_[1]) {

    # rel => href
    if (@_ == 2) {
      return $self->add(link => {
	rel  => shift,
	href => shift
      });
    };

    # Parameter
    my %values = @_;
    # href, rel, type, hreflang, title, length
    my $rel = delete $values{rel} || 'related';
    return $self->add(link => {
      rel => $rel,
      %values
    });
  };

  my $rel = shift;
  return $self->find(qq{link[rel="$rel"]});
};


# Add logo
sub logo {
  shift->_simple_feed_info(logo =>  @_);
};


# Add publish time information
sub published {
  shift->_date(published => @_);
};

# Todo: content, rights, source are equal.

# Add rights information
sub rights {
  my $self = shift;

  # Set rights
  return $self->__text(set => rights => @_) if $_[0];

  # Return rights
  return $self->_get_information_single('rights');
};


# Add source information
# Todo: Not in feed
sub source {
  my $self = shift;

  return if $self->parent->type ne 'entry';

  # Set source
  return $self->__text(set => source => @_) if $_[0];

  # Return source
  return $self->_get_information_single('source');
};


# Add subtitle
sub add_subtitle {
  shift->__text(subtitle => @_);
};


# Add summary
sub add_summary {
  shift->__text(summary => @_);
};


# Add title
sub add_title {
  shift->__text('title', @_);
};


# Add update time information
sub add_updated {
  shift->_date(updated => @_);
};


# Add person information
sub _add_person {
  my $self = shift;
  my $type = shift;

  # Person is a defined node
  if (ref($_[0])) {
    my $person = shift;
    $person->root->at('*')->tree->[1] = $type;
    return $self->add($person);
  }

  # Person is a hash
  else {
    my $person = $self->add($type);
    my %data = @_;

    foreach (keys %data) {
      $person->add($_ => $data{$_} ) if $data{$_};
    };
    return $person;
  };
};


# Add date construct
sub _date {
  my $self = shift;
  my $type = shift;

  # Set date
  if ($_[0]) {
    my $date = shift;

    unless (ref($date)) {
      $date = $self->new_date($date);
    };

    return $self->set($type, $date->to_string);
  };

  # Get published information
  my $date = $self->_get_information_single($type);

  # Parse date
  return XML::Loy::Date::RFC3339->new($date->text) if $date;

  # No publish information found
  return;
};


# Add text information
sub __text {
  my $self   = shift;
  my $action = shift;

  return unless $action ~~ [qw/add set/];

  my $type   = shift;

  # Text is a defined node
  if (ref $_[0]) {

    my $text = shift;

    # Get root element
    my $root_elem = $text->root->at('*');

    $root_elem->tree->[1] = $type;
    my $root_att = $root_elem->attrs;

    # Delete type
    if (exists $root_att->{type} && $root_att->{type} eq 'text') {
      delete $root_elem->attrs->{'type'};
    };

    $text->root->at('*')->tree->[1] = $type;

    # warn $text->to_pretty_xml;

    return $self->$action($text);
  };

  my $text;
  # Text is no hash
  unless (defined $_[1]) {
    $text = $self->new_text(type => 'text',
			    content => shift );
  }

  # Text is a hash
  else {
    $text = $self->new_text(@_);
  };

  # Todo: Optimize!
  return $self->__text($action, $type, $text) if ref $text;

  return;
};


# Return information of entries or the feed
sub _get_information_array {
  my $self = shift;
  my $type = shift;

  # Get author objects
  my $children = $self->children($type);

  # Return information of object
  return $children if $children->[0];

  # Return feed information
  return $self->find('feed > ' . $type);
};


# Return information of entries or the feed
sub _get_information_single {
  my $self = shift;
  my $type = shift;

  # Get author objects
  my $children = $self->children($type);

  # Return information of object
  return $children->[0] if $children->[0];

  # Return feed information
  return $self->at('feed > ' . $type);
};


# Get or set simple feed information
# like generator or icon
sub _simple_feed_info {
  my $self = shift;
  my $type = shift;

  my $feed = $self->root->at('feed');
  return unless $feed;

  # Set
  if ($_[0]) {
    return $feed->set($type => @_);
  };

  # Get generator information
  my $gen = $feed->at($type);
  return $gen->all_text if $gen;
  return;
};


1;


__END__

=pod

=head1 NAME

XML::Loy::Atom - Atom Syndication Format Extension


=head1 SYNOPSIS

  # Mojolicious
  $app->plugin(XML => {
    new_atom => ['Atom']
  });

  # Mojolicious::Lite
  plugin XML => {
    new_atom => ['Atom']
  };

  # In Controllers
  my $feed = $self->new_atom( 'feed' );

  my $author = $feed->new_person( name => 'Fry' );
  $feed->add_author($author);
  $feed->add_title('This is a test feed.');
  my $entry = $self->new_atom('entry');

  for ($entry) {
    $_->add_title('First Test entry');
    $_->add_subtitle('This is a subtitle');
    my $content = $_->add_content(
	type    => 'xhtml',
	content => '<p id="para">' .
	           'This is a Test!' .
	           '</p>');
    $content->at('#para')
	->replace_content('This is a <strong>Test</strong>!');
  };

  $feed->add_entry($entry);
  $self->render_xml($feed);


=head1 DESCRIPTION

L<XML::Loy::Atom> is a base class or extension
for L<XML::Loy> and provides several functions
for the work with the Atom Syndication Format as described in
L<RFC4287|http://tools.ietf.org/html/rfc4287>.

=head1 METHODS

L<Mojolicious::Plugin::XML::Atom> inherits all methods
from L<XML::Loy> and implements the
following new ones.


=head2 new_date

  my $date = $atom->new_date(1312311456);
  my $date = $atom->new_date('1996-12-19T16:39:57-08:00');

Returns an L<XML::Loy::Date::RFC3339> object.
It accepts all parameters of
L<XML::Loy::Date::RFC3339::parse|XML::Loy::Date::RFC3339/parse>.
If no parameter is given, the current server time is returned.

B<This method is EXPERIMENTAL and may change without warning.>


=head2 new_person

  my $person = $atom->new_person(
    name => 'Bender',
    uri  => 'acct:bender@example.org'
  );

Returns a new person construction.


=head2 new_text

  my $text = $atom->new_text('This is a test');
  my $text = $atom->new_text( xhtml => 'This is a <strong>test</strong>!');
  my $text = $atom->new_text(
    type    => 'xhtml',
    content => 'This is a <strong>test</strong>!'
  );

Returns a new text construct. Accepts either a simple string
(of type 'text'), a tupel with the first argument being the media type and
the second argument being the content, or a hash with the parameters C<type>,
C<content> or C<src> (and others). There are three predefined
C<type> values:

=over 2

=item

C<text> for textual data

=item

C<html> for HTML data

=item

C<xhtml> for XHTML data

=back

C<xhtml> data is automatically wrapped in a
namespaced C<div> element (see
L<RFC4287, Section 3.1|http://tools.ietf.org/html/rfc4287.htm#section-3.1>
for further details).


=head2 author

  my $person = $atom->new_person(
    name => 'Bender',
    uri  => 'acct:bender@example.org'
  );
  my $author = $atom->author($person);

  print $atom->author->[0]->at('name')->text;

Add author information to the Atom object or get it.
Accepts a person construct (see L<new_person|/new_person>)
or the parameters accepted by L<new_person|/new_person>.

Returns a collection of author nodes.


=head2 category

  $atom->category('world');

  print $atom->category->[0];

Adds category information to the Atom object or get it.
Accepts either a hash for attributes
(with, e.g., term and label)
or one string representing the category's term.

Returns a collection of category terms.


=head2 content

  my $text = $atom->new_text(
    type    => 'xhtml',
    content => '<p>This is a <strong>test</strong>!</p>'
  );

  my $entry = $atom->entry(id => 'entry_1');

  $entry->content($text);
  $entry->content('This is a test!');

  print $atom->content->all_text;

Set content information to the Atom object or get it.
Accepts a text construct (see L<new_text|/new_text>) or the
parameters accepted by L<new_text|/new_text>.


=head2 contributor

  my $person = $atom->new_person(
    name => 'Bender',
    uri  => 'acct:bender@example.org'
  );
  my $contributor = $atom->contributor($person);

  print $atom->contributor->[0]->at('name')->text;

Add contributor information to the Atom object or get it.
Accepts a person construct (see L<new_person|/new_person>)
or the parameters accepted by L<new_person|/new_person>.

Returns a collection of contributor nodes.

=head2 entry

  # Add entry as a hash of attributes
  my $entry = $atom->entry(
    id      => 'entry_id_1',
    summary => 'My first entry'
  );

  # Get entry by id
  my $entry = $atom->entry('entry_id_1');

Add an entry to the Atom feed or get one.
Accepts a hash of simple entry information
for adding or an id for retrieval.


=head2 generator

  $atom->generator('XML-Loy-Atom');

  print $atom->generator;

Set generator information of the feed or returns it
as a text string.


=head2 icon

  $atom->generator('http://sojolicio.us/favicon.ico');

  print $atom->icon;

Set icon url of the feed or return it
as a text string.

The image should be suitable for small representation size
and have an aspect ratio of 1:1.


=head2 id

  $atom->id('http://sojolicio.us/#12345');

  print $atom->id;

Set or return the unique identifier of the Atom object.


=head2 link

  $atom->link(related => 'http://sojolicio.us/#12345');
  $atom->link(
    rel => 'self',
    href => 'http://sojolicio.us/#12345'
  );

  # Get link elements
  $atom->link('related');


Adds link information to the Atom object. If no relation
attribute is given, the default relation is 'related'.
Accepts either one scalar as a reference of a related link,
a pair of scalars for the relational type and the reference
or multiple hashes for the attributes of the link.


=head2 add_logo

  $atom->add_logo('http://sojolicio.us/sojolicious.png');

Adds a URI to a logo associated with the Atom object.
The image should have an aspect ratio of 2:1.


=head2 add_published

  my $date = $atom->new_date(1312311456);
  $atom->add_published($date);

Adds a publishing timestamp to the Atom object.
Accepts a date construct (see L<new_date>) or the
parameter accepted by L<new_date>.


=head2 add_rights

  $atom->add_rights('Public Domain');

Adds legal information to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.

=head2 add_source

  my $source = $atom->add_source('xml:base' =>
    'http://source.sojolicio.us/');
  $source->add_author(name => 'Zoidberg');

Adds source information of the Atom object.


=head2 add_subtitle

  my $text = $atom->new_text(type => 'text',
                             content => 'This is a subtitle!');

  $atom->add_subtitle($text);
  $atom->add_subtitle('This is a subtitle!');

Adds subtitle information to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.


=head2 add_summary

  my $text = $atom->new_text(type => 'text',
                             content => 'Test entry');

  $atom->add_summary($text);
  $atom->add_summary('Test entry');

Adds a summary of the content to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.


=head2 add_title

  my $text = $atom->new_text(type => 'text',
                             content => 'First Test entry');

  $atom->add_title($text);
  $atom->add_title('First Test entry');

Adds a title to the Atom object.
Accepts a text construct (see L<new_text>) or the
parameters accepted by L<new_text>.


=head2 add_updated

  my $date = $atom->new_date(1312311456);
  $atom->add_updated($date);

Adds a last update timestamp to the Atom object.
Accepts a date construct (see L<new_date>) or the
parameter accepted by L<new_date>.


=head1 MIME-TYPES

When loaded as a base class, L<XML::Loy::Atom>
establishes the following mime-types:

  'atom': 'application/atom+xml'

=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/XML-Loy


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
