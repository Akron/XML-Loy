package MojoX::XML;
use Mojo::ByteStream 'b';
use Mojo::Loader;
use Carp qw/carp croak/;
use Mojo::Base 'Mojo::DOM';

# Todo:
#   Support "once" method (aka set), that can only be set, not added.
#   - Can be done by introducing serial:once="id" (if already set)
#
#   All attributes are getter and setter! No more add_ things
#
#   Maybe necessary: *AUTOLOAD = \&MojoX::XML::AUTOLOAD;
#
#   sub try_further { };
#   # usage:
#   sub get_author {
#     return $autor or $self->try_further;
#   };

our $VERSION = '0.02';

our @CARP_NOT;

# Import routine, run when calling the class properly
sub import {
  my $class = shift;

  return unless my $flag = shift;

  if ($flag =~ /^-?(?i:with|base)$/) {

    # Get class variables
    my %param = @_;

    # Allow for manipulating the symbol table
    no strict 'refs';
    no warnings 'once';

    # The caller is the calling (inheriting) class
    my $caller = caller;
    push @{"${caller}::ISA"}, __PACKAGE__;

    # Set class variables
    foreach (qw/namespace prefix mime/) {
      ${ "${caller}::" . uc $_} = $param{$_} if exists $param{$_};
    };
  };

  # Make inheriting classes strict and modern
  strict->import;
  warnings->import;
  utf8->import;
  feature->import(':5.10');
};


use constant {
  I  => '  ',
  NS => 'http://sojolicio.us/ns/xml-serial',
  PI => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
};


# Return class variables
{
  no strict 'refs';
  sub _namespace { ${"${_[0]}::NAMESPACE"}  || '' };
  sub _prefix    { ${"${_[0]}::PREFIX"}     || '' };
  sub mime       { ${ref($_[0]) . '::MIME'} || 'application/xml' };
};


# Construct new MojoX::XML object
sub new {
  my $class = shift;

  # Create from parent class
  if ( ref $class                  # MojoX::XML object
       || !$_[0]                   # Empty constructor
       || (index($_[0],'<') >= 0)  # XML string
     ) {
    return $class->SUPER::new(@_);
  }

  # Create a new node
  else {
    my $name = shift;
    my $att  = shift if ref( $_[0] ) eq 'HASH';
    my ($text, $comment) = @_;

    # Node content
    my $element = qq(<$name xmlns:serial=") . NS . '"';

    # Text is given
    $element .= $text ? ">$text</$name>" : ' />';

    # Create root element by parent class
    my $root = $class->SUPER::new( PI . $element );

    # Root is xml document
    $root->xml(1);

    # Transform special attributes
    _special_attributes($att) if $att;

    # Add attributes to node
    my $root_e = $root->at(':root');
    $root_e->attrs($att) if $att;

    # Add comment
    $root_e->comment($comment) if $comment;

    # The class is derived
    if ($class ne __PACKAGE__) {

      # Set namespace if given
      if (my $ns = $class->_namespace) {
	$root_e->attrs(xmlns => $ns);
      };
    };

    # Return root node
    return $root;
  };
};


# Append a new child node to the XML Node
sub add {
  my $self = shift;

  # Store tag
  my $tag = $_[0];

  # If node is root, use first element
  if (!$self->parent && $self->tree->[1]->[0] eq 'pi') {
    $self = $self->at('*');
  };

  # Add element
  my $element = $self->_add_clean(@_);

  my $tree = $element->tree;

  # Prepend with no prefix
  if (index($tag, '-') == 0) {
    $tree->[1] = substr($tag, 1);
    return $element;
  };

  # Element is no tag
  return $element unless $tree->[0] eq 'tag';

  # Prepend prefix if necessary
  my $caller = caller;
  my $class  = ref $self;

  # Caller and class are not the same
  if ($caller ne $class && $caller->can('_prefix')) {
    if ((my $prefix = $caller->_prefix) && $caller->_namespace) {
      $element->tree->[1] = "${prefix}:$tag";
    };
  };

  # Return element
  return $element;
};


# Append a child only once to the XML node.
sub set {
  my $self = shift;

  # If node is root, use first element
  if (!$self->parent && $self->tree->[1]->[0] eq 'pi') {
    $self = $self->at('*');
  };

  # Document objects are not allowed
  return if ref $_[0];

  # Store tag
  my $tag = shift;

  # No prefix
  if (index($tag, '-') == 0) {
    $tag = substr($tag, 1);
  }

  # Maybe prefix
  else {
    # Prepend prefix if necessary
    my $caller = caller;
    my $class  = ref $self;

    # Caller and class are not the same
    if ($caller ne $class && $caller->can('_prefix')) {
      if ((my $prefix = $caller->_prefix) && $caller->_namespace) {
	$tag = "${prefix}:$tag";
      };
    };
  };

  my $att = $self->tree->[2];

  # Introduce attribute 'once'
  $att->{'serial:once'} //= '';

  # Check if set to once
  if (index($att->{'serial:once'}, "($tag)") >= 0) {

    # Todo: Maybe escaping - check in extensions
    $self->children("$tag")->pluck('remove');
  }

  # Set if not already set
  else {
    $att->{'serial:once'} .= "($tag)";
  };

  # Add element (Maybe prefixed)
  return $self->_add_clean($tag, @_);
};


# Append a new child node to the XML Node
sub _add_clean {
  my $self = shift;

  # Node is a node object
  if (ref $_[0]) {

    # Serialize node
    my $node = $self->SUPER::new( shift->to_xml );

    # Get root attributes
    my $root_attr = $node->_root_element->[2];

    # Push namespaces to new root
    foreach ( grep( index($_, 'xmlns:') == 0, keys %$root_attr ) ) {

      # Strip xmlns prefix
      $_ = substr($_, 6);

      # Add namespace
      $self->namespace( $_ => delete $root_attr->{ "xmlns:$_" } );
    };

    # Delete namespace information, if already set
    if (exists $root_attr->{xmlns}) {

      # Namespace information can be deleted
      if (my $ns = $self->namespace) {
	delete $root_attr->{xmlns} unless $root_attr->{xmlns} eq $ns;
      };
    };

    # Get root of parent node
    my $base_root_attr = $self->_root_element->[2];

    # Copy extensions
    if (exists $root_attr->{'serial:ext'}) {
      my $ext = $base_root_attr->{'serial:ext'};

      $base_root_attr->{'serial:ext'} =
	join('; ', $ext, split(/;\s/, $root_attr->{'serial:ext'}));
    };


    # Delete pi from node
    my $sec = $node->tree->[1];
    if (ref $sec eq 'ARRAY' && $sec->[0] eq 'pi') {
      splice( @{ $node->tree }, 1,1 );
    };

    # Append new node
    $self->append_content($node);

    # Return first child
    return $self->children->[-1];
  }

  # Node is a string
  else {
    my $name = shift;
    my $att  = shift if ref( $_[0] ) eq 'HASH';
    my ($text, $comment) = @_;

    # Node content with text
    my $string = "<$name";

    if (defined $text) {
      $string .= '>' . b($text)->trim->xml_escape . "</$name>";
    }

    # Empty element
    else {
      $string .= ' />';
    };

    # Append new node
    $self->append_content( $string );

    # Get first child
    my $node = $self->children->[-1];

    # Attributes were given
    if ($att) {

      # Transform special attributes
      _special_attributes($att);

      # Add attributes to node
      $node->attrs($att);
    };

    # Add comment
    $node->comment($comment) if $comment;

    return $node;
  };
};


# Transform special attributes
sub _special_attributes {
  my $att = shift;

  foreach ( grep { index($_, '-') == 0 } keys %$att ) {

    # Set special attribute
    $att->{'serial:' . substr($_, 1) } = lc(delete $att->{$_});
  };
};


# Prepend a comment to the XML node
sub comment {
  my $self = shift;

  my $parent;

  # If node is root, use first element
  return $self unless $parent = $self->parent;

  # Find previous sibling
  my $previous;

  # Find previous node
  for my $e (@{$parent->tree}) {
    last if $e eq $self->tree;
    $previous = $e;
  };

  # Trim and encode comment text
  my $comment_text = b( shift )->trim->xml_escape;

  # Add to previous comment
  if ($previous && $previous->[0] eq 'comment') {
    $previous->[1] .= '; ' . $comment_text;
  }

  # Create new comment node
  else {
    $self->prepend("<!--$comment_text-->");
  };

  # Return node
  return $self;
};


# Add extension to document
sub extension {
  my $self = shift;

  # Get root element
  my $root = $self->_root_element or return;

  # Get ext string
  my @ext = split(/;\s/, $root->[2]->{'serial:ext'} || '');

  return @ext unless $_[0];

  # New Loader
  my $loader = Mojo::Loader->new;

  my $loaded = 0;

  # Try all given extension names
  while (my $ext = shift( @_ )) {

    next if $ext ~~ \@ext;

    # Todo: Support default 'MojoX::XML::' prefix

    # Unable to load extension
    if (my $e = $loader->load($ext)) {
      carp "Exception: $e"  if ref $e;
      carp qq{Unable to load extension "$ext"};
      next;
    };

    # Add extension to extensions list
    push(@ext, $ext);
    $loaded++;

    if ((my $n_ns = $ext->_namespace) &&
	  (my $n_pref = $ext->_prefix)) {
      $root->[2]->{"xmlns:$n_pref"} = $n_ns;
    };
  };

  # Save extension list as attribute
  $root->[2]->{'serial:ext'} = join('; ', @ext);

  return $loaded;
};


# Get or add namespace to root
sub namespace {
  my $self = shift;

  # Get namespace
  return $self->SUPER::namespace unless $_[0];

  my $ns = pop;
  my $prefix = shift;

  # Get root element
  my $root = $self->_root_element or return;

  # Save namespace as attribute
  $root->[2]->{'xmlns' . ($prefix ? ":$prefix" : '')} = $ns;
  return $prefix;
};


# Render as pretty xml
sub to_pretty_xml {
  my $self = shift;
  return _render_pretty( shift // 0, $self->tree);
};


# Render subtrees with pretty printing
sub _render_pretty {
  my $i    = shift; # Indentation
  my $tree = shift;

  my $e = $tree->[0];

  # No element
  croak('No element') and return unless $e;

  # Element is tag
  if ($e eq 'tag') {
    my $subtree =
      [
	@{ $tree }[ 0 .. 2 ],
	[
	  @{ $tree }[ 4 .. $#$tree ]
	]
      ];

    return _element($i, $subtree);
  }

  # Element is text
  elsif ($e eq 'text') {

    my $escaped = $tree->[1];

    for ($escaped) {
      next unless $_;

      # Escape and trim whitespaces from both ends
      $_ = b($_)->xml_escape->trim;
    };

    return $escaped;
  }

  # Element is comment
  elsif ($e eq 'comment') {

    # Padding for every line
    my $p = I x $i;
    my $comment = join "\n$p     ", split(/;\s+/, $tree->[1]);

    return "\n" . (I x $i) . "<!-- $comment -->\n";

  }

  # Element is processing instruction
  elsif ($e eq 'pi') {
    return (I x $i) . '<?' . $tree->[1] . "?>\n";

  }

  # Element is root
  elsif ($e eq 'root') {

    my $content;

    # Pretty print the content
    $content .= _render_pretty( $i, $tree->[ $_ ] ) for 1 .. $#$tree;

    return $content;
  };
};


# Render element with pretty printing
sub _element {
  my $i = shift;
  my ($type, $qname, $attr, $child) = @{ shift() };

  # Is the qname valid?
  croak "$qname is no valid QName"
    unless $qname =~ /^(?:[a-zA-Z_]+:)?[^\s]+$/;

  # Start start tag
  my $content = (I x $i) . "<$qname";

  # Add attributes
  $content .= _attr((I x $i). (' ' x ( length($qname) + 2)), $attr);

  # Has the element a child?
  if ($child->[0]) {

    # Close start tag
    $content .= '>';

    # There is only a textual child - no indentation
    if (!$child->[1] && ($child->[0] && $child->[0]->[0] eq 'text')) {

      # Special content treatment
      if (exists $attr->{'serial:type'}) {

	# With base64 indentation
	if ($attr->{'serial:type'} =~ /^armour(?::(\d+))?$/i) {
	  my $n = $1 || 60;

	  my $string = $child->[0]->[1];

	  # Delete whitespace
	  $string =~ tr{\t-\x0d }{}d;

	  # Introduce newlines after n characters
	  $content .= "\n" . (I x ($i + 1));
	  $content .= join  "\n" . ( I x ($i + 1) ), (unpack "(A$n)*", $string );
	  $content .= "\n" . (I x $i);
	}

	# No special treatment
	else {

	  # Escape
	  $content .= b($child->[0]->[1])->trim->xml_escape;
	};
      }

      # No special content treatment indentation
      else {

	# Escape
	$content .= b($child->[0]->[1])->trim->xml_escape;
      };
    }

    # Treat children special
    elsif (exists $attr->{'serial:type'}) {

      # Raw
      if ($attr->{'serial:type'} eq 'raw') {

	foreach (@$child) {

	  # Create new dom object
	  my $dom = __PACKAGE__->new;
	  $dom->xml(1);

	  # Print without prettifying
	  $content .= $dom->tree($_)->to_xml;
	};
      }

      # Todo:
      elsif ($attr->{'serial:type'} eq 'escape') {
	$content .= "\n";

	foreach (@$child) {

	  # Create new dom object
	  my $dom = __PACKAGE__->new;
	  $dom->xml(1);

	  # Pretty print
	  my $string = $dom->tree($_)->to_pretty_xml($i + 1);

	  # Encode
	  $content .= b($string)->xml_escape;
	};

	# Correct Indent
	$content .= (I x $i);

      };
    }

    # There are a couple of children
    else {

      my $offset = 0;

      # First element is unformatted textual
      if (!exists $attr->{'serial:type'} &&
	    $child->[0] &&
	      $child->[0]->[0] eq 'text') {

	# Append directly to the last tag
	$content .= b($child->[0]->[1])->trim->xml_escape;
	$offset = 1;
      };

      # Start on a new line
      $content .= "\n";

      # Loop through all child elements
      foreach (@{$child}[ $offset .. $#$child ]) {

	# Render next element
	$content .= _render_pretty( $i + 1, $_ );
      };

      # Correct Indent
      $content .= (I x $i);
    };

    # End Tag
    $content .= "</$qname>\n";
  }

  # No child - close start element as empty tag
  else {
    $content .= " />\n";
  };

  # Return content
  return $content;
};


# Render attributes with pretty printing
sub _attr {
  my $indent_space = shift;
  my %attr = %{$_[0]};

  # Delete special and namespace attributes
  my @special = grep {
    $_ eq 'xmlns:serial' || index($_, 'serial:') == 0
  } keys %attr;

  # Delete special attributes
  delete $attr{$_} foreach @special;

  # Prepare attribute values
  $_ = b($_)->xml_escape->quote foreach values %attr;

  # Return indented attribute string
  if (keys %attr) {
    return ' ' .
      join "\n$indent_space", map { "$_=" . $attr{$_} } sort keys %attr;
  };

  # Return nothing
  return '';
};


# Get root element (not as an object)
sub _root_element {
  my $self = shift;

  # Todo: Optimize! Often called!

  # Find root (Based on Mojo::DOM::root)
  my $root = $self->tree;
  my $tag;

  # Root is root node
  if ($root->[0] eq 'root') {
    my $i = 1;

    # Search for the first tag
    $i++ while $root->[$i] && $root->[$i]->[0] ne 'tag';

    # Tag found
    $tag = $root->[$i];
  }

  # Root is a tag
  else {

    # Tag found
    while ($root->[0] eq 'tag') {
      $tag = $root;

      last unless my $parent = $root->[3];

      $root = $parent;
    };
  };

  # Return root element
  return $tag;
};


# Autoload for extensions
sub AUTOLOAD {
  my $self = shift;
  my @param = @_;

  # Split parameter
  my ($package, $method) = our $AUTOLOAD =~ /^([\w\:]+)\:\:(\w+)$/;

  # Choose root element
  my $root = $self->_root_element;

  # Get extension array
  my @ext = $self->extension;

  {
    no strict 'refs';

    foreach (@ext) {

      # Method does not exist in extension
      next unless $_->can($method);

      # Release method
      return *{ "${_}::$method" }->($self, @param);
    };
  };

  my $errstr = qq{Can't locate "${method}()" in "$package"};
  $errstr .= ' with ' . join(', ', @ext) . ' extensions' if @ext;

  carp $errstr and return;
};


1;


__END__

=pod

=head1 NAME

MojoX::XML - XML generator based on Mojo::DOM


=head1 SYNOPSIS

  use MojoX::XML;

  # Create new dcument with root node
  my $xml = MojoX::XML->new('env');

  # Add elements to the document
  my $header = $xml->add('header');

  # Nest elements
  $header->add('greetings')->add(title => 'Hello!');

  # Append elements
  $xml->add('body' => { date => 'today' })->add(p => "That's all!");

  # Use CSS3 selectors for element traversal
  $xml->at('title')->attrs(style => 'color: red');

  # Attach comments to elements
  $xml->at('greetings')->comment('My Greeting');

  # Print with pretty indentation
  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <env>
  #   <header>
  #
  #       <!-- My Greeting -->
  #       <greetings>
  #         <title style="color: red">Hello!</title>
  #       </greetings>
  #     </header>
  #     <body date="today">
  #       <p>That&#39;s all!</p>
  #     </body>
  #   </env>


=head1 DESCRIPTION

L<MojoX::XML> allows for the simple creation
of serialized XML documents with multiple namespaces and
pretty printing, while giving you the full power of L<Mojo::DOM>
element traversal.


=head1 METHODS

L<MojoX::XML> inherits all methods from
L<Mojo::DOM> and implements the following new ones.


=head2 new

  my $xml = MojoX::XML->new(<<'EOF');
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <entry>
    <fun>Yeah!</fun>
  <entry>
  EOF

  $xml = MojoX::XML->new('Document');
  $xml = MojoX::XML->new(Document => { foo => 'bar' });
  my $xml_new = $xml->new(Document => {id => 'new'} => 'My Content');

Construct a new L<MojoX::XML> document.
Accepts either all parameters supported by L<Mojo::DOM> or
all parameters supported by L<add|/add>.


=head2 add

  my $xml = MojoX::XML->new('Document');
  $xml->add('Element');

  my $elem = $xml->add(Element => { type => 'text/plain' });
  $elem->add(Child => 'I\'m a child element');

  $xml->add(Text => { type => 'text/plain' }, 'Hello World!');
  $xml->add(Text => 'Hello World!', 'This is a comment!');
  $xml->add(EmptyElement => undef, 'This is an empty element!');
  $xml->add(Data => { -type => 'armour' }, 'PdGzjvj..');

  $elem = $xml->new(Element => 'Hello World!');
  $xml->add($elem);

Add a new element to a L<MojoX::XML> document, either
as another L<MojoX::XML> object or newly defined.
Returns the root node of the added L<MojoX::XML>
document.

Parameters to define elements are a tag name,
followed by an optional hash reference
including all attributes of the XML element,
an optional text content,
and an optional comment on the element.
If the comment should be introduced without text content,
text content has to be C<undef>.

For rendering element content, special C<-type> attributes
can be defined:

=over 2

=item C<escape>

XML escape the content of the node.

  my $xml = MojoX::XML->new('feed');
  my $html = $xml->add('html' => { -type => 'escape' });
  $html->add(h1 => { style => 'color: red' } => 'I start blogging!');
  $html->add(p => 'What a great idea!')->comment('First post');

  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <feed>
  #   <html>
  #     &lt;h1 style=&quot;color: red&quot;&gt;I start blogging!&lt;/h1&gt;
  #
  #     &lt;!-- First post --&gt;
  #     &lt;p&gt;What a great idea!&lt;/p&gt;
  #   </html>
  # </feed>

=item C<raw>

Treat children as raw data (no pretty printing).

  my $plain = MojoX::XML->new(<<'PLAIN');
  <entry>There is <b>no</b> pretty printing</entry>
  PLAIN

  my $xml = MojoX::XML->new('entry');
  my $text = $xml->add('text' => { -type => 'raw' });
  $text->add($plain);

  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <entry>
  #   <text><entry>There is <b>no</b> pretty printing</entry>
  # </text>
  # </entry>


=item C<armour:n>

Indent the content and automatically
introduce linebreaks after every
C<n>th character.
Intended for base64 encoded data.
Defaults to 60 characters linewidth after indentation.

  my $xml = MojoX::XML->new('entry');
  my $data =
     $xml->add(
       data => {
	 type  => 'text/plain',
	 -type => 'armour:30'
       } => <<'B64');
    VGhpcyBpcyBqdXN0IGEgdGVzdCBzdHJpbmcgZm
    9yIHRoZSBhcm1vdXIgdHlwZS4gSXQncyBwcmV0
    dHkgbG9uZyBmb3IgZXhhbXBsZSBpc3N1ZXMu
  B64

  $data->comment('This is base64 data!');

  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <entry>
  #
  #   <!-- This is base64 data! -->
  #   <data type="text/plain">
  #     VGhpcyBpcyBqdXN0IGEgdGVzdCBzdH
  #     JpbmcgZm9yIHRoZSBhcm1vdXIgdHlw
  #     ZS4gSXQncyBwcmV0dHkgbG9uZyBmb3
  #     IgZXhhbXBsZSBpc3N1ZXMu
  #   </data>
  # </entry>

=back


=head2 comment

  $node = $node->comment('Resource Descriptor');

Prepend a comment to the current node.
If a node already has a comment, comments will be merged.


=head2 set

  my $xml = MojoX::XML->new('Document');
  $xml->set('Element' => { id => 5 });
  $xml->set('Element' => { id => 6 });

Adds a new element to the document - only once.
Accepts all parameters as defined in L<add|/add>,
without accepting L<MojoX::XML> objects.

If one or more elements with the same tag name are
already children of the requesting node,
the old elements will be overwritten.
Comments will be merged.


=head2 to_pretty_xml

  print $xml->to_pretty_xml;
  print $xml->to_pretty_xml(2);

Returns a stringified, pretty printed XML document.
Optionally accepts a numerical parameter,
defining the start of indentation (defaults to 0).


=head1 ATTRIBUTES

=head2 extension

  my $nr = $xml->extension('Fun', 'MojoX::XML::Atom');
  my @extensions = $xml->extension;

Add or get an array of extensions.
When adding, returns the number of successfully added extensions.
When getting, returns the array of associated extensions.
See L<Extensions|/Extensions> for further information.


=head2 namespace

  my $xml = MojoX::XML->new('doc');
  $xml->namespace('http://sojolicio.us/ns/global');
  $xml->namespace(fun => 'http://sojolicio.us/ns/fun');
  $xml->add('fun:test' => { foo => 'bar' }, 'Works!');
  print $xml->namespace;

  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <doc xmlns="http://sojolicio.us/global"
  #      xmlns:fun="http://sojolicio.us/fun">
  #   <fun:test foo="bar">Works!</fun:test>
  # </doc>

Get the namespace of the node or
add namespace information to the node's root.
On adding, the first parameter gives the prefix, the second one
the namespace. The prefix parameter is optional.
Namespaces are always added to the document's root,
that means,
they have to be unique in the scope of the whole document.


=head2 mime

  print $xml->mime;

The mime type associated with the object class.
See L<Extensions|/Extensions> for further information.


=head1 EXTENSIONS

  package Fun;
  use MojoX::XML with => (
    prefix => 'fun',
    namespace => 'http://sojolicio.us/ns/fun',
    mime => 'application/fun+xml'
  );

  # Add new methods to the object
  sub add_happy {
    my $self = shift;
    my $word = shift;

    my $cool = $self->add('-Cool');
    my $cry  = uc($word) . '!!! \o/ ';
    $cool->add(Happy => {foo => 'bar'}, $cry);
  };

L<MojoX::XML> allows for inheritance
and thus provides two ways of extending the functionality:
By using a derived class as a base class or by extending a
base class with the L<extension|/extension> attribute.

For this purpose three attributes can be set when
L<MojoX::XML> is used (introduced with the keyword C<with>).

=over 2

=item C<namespace>

Namespace of the extension.

=item C<prefix>

Preferred prefix to associate with the namespace.

=item C<mime>

Mime type of the base document.

=back

You can use derived objects in your application as you
would do with any other object class.

  package main;
  use Fun;
  my $obj = Fun->new('Fun');
  $obj->add_happy('Yeah!');
  print $obj->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <Fun xmlns="http://sojolicio.us/ns/fun">
  #   <Cool>
  #     <Happy foo="bar">YEAH!!!! \o/ </Happy>
  #   </Cool>
  # </Fun>

The defined namespace is introduced as the document's
namespace. The prefix is not in use for derived classes.

Without any changes to the class, you can use this module as an
extension to another L<MojoX::XML> based document as well.

  use MojoX::XML;

  my $obj = MojoX::XML->new('object');

  # Use MojoX::XML based class 'Fun'
  $obj->extension('Fun');

  # Use methods provided by the base class or any extension
  $obj->add_happy('Yeah!');

  # Print with pretty indentation
  print $obj->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <object xmlns:fun="http://sojolicio.us/ns/fun">
  #   <Cool>
  #     <fun:Happy foo="bar">YEAH!!!! \o/ </fun:Happy>
  #   </Cool>
  # </object>

The defined namespace of C<Fun> is introduced with the
prefix C<fun>. The prefix is prepended to all elements
added by the C<add> method in the extension class.
To prevent this prefixing, prepend the element name with
a C<-> (like with C<Cool>).


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/MojoX-XML


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
