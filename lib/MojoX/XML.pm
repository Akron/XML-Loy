package MojoX::XML;
use Mojo::ByteStream 'b';
use Mojo::Loader;
use Carp qw/carp croak/;
use Mojo::Base 'Mojo::DOM';
use Mojo::Util 'monkey_patch';

# Todo: Support "once" attributes, that can only be set, not added.
# Mybe necessary: *AUTOLOAD = \&MojoX::XML::AUTOLOAD;

our $VERSION = '0.01';

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
  sub _namespace { ${"${_[0]}::NAMESPACE"} || '' };
  sub _mime      { ${"${_[0]}::MIME"}      || '' };
  sub _prefix    { ${"${_[0]}::PREFIX"}    || '' };
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
    foreach ( grep { index($_, '-') == 0 } keys %$att ) {

      # Set special attribute
      $att->{'serial:' . substr($_, 1) } = lc(delete $att->{$_});
    };

    # Add attributes to node
    my $root_e = $root->at(':root');
    $root_e->attrs($att);

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


# todo:
# sub try_further {
# };
#
# usage:
# sub get_author {
#   return $autor or $self->try_further;
# };

# Append a new child node to the XML Node
sub _add_clean {
  my $self = shift;

  # If root use first element
  if (!$self->parent &&
#	$self->tree->[1]->[0] &&
	  ($self->tree->[1]->[0] eq 'pi')) {
    $self = $self->at('*');
  };

  my ($node, $comment);

  # Node is a node object
  if (ref( $_[0] )) {
    $node    = $self->SUPER::new( shift->to_xml );
    $comment = shift;

    # Push namespaces to new root
    my $root_attr =      $node->_root_element->[2];
    foreach ( grep( index($_,'xmlns:') == 0, keys %{ $root_attr } ) ) {
      $_ = substr($_,6);
      $self->add_namespace( $_ => delete $root_attr->{'xmlns:'.$_} );
    };

    # Delete namespace information, if already set
    if (exists $root_attr->{xmlns}) {
      my $ns = $self->namespace;
      if ($ns && $root_attr->{xmlns} eq $ns) {
	delete $root_attr->{xmlns};
      };
    };

    # Push extensions to new root
    my $root = $self->_root_element;
    if (exists $root_attr->{'serial:ext'}) {
      my $ext = $root->[2]->{'serial:ext'} || '';
      $root->[2]->{'serial:ext'} =
	join("; ", $ext, split(/;\s/, $root_attr->{'serial:ext'}))
    };

    # Delete pi from node
    if (ref($node->tree->[1]) eq 'ARRAY' &&
	  $node->tree->[1]->[0] eq 'pi') {
      splice( @{ $node->tree }, 1,1 );
    };

    # Append new node
    $self->append_content($node);
    $node = $self->children->[-1];
  }

  # Node is a string
  else {
    my $name = shift;
    my $att  = shift if (ref( $_[0] ) eq 'HASH');
    my $text = shift;
    $comment = shift;

    my $string = "<$name />";
    $string    = "<$name>$text</$name>" if defined $text;

    # Append new node
    $self->append_content($string);
    $node = $self->children->[-1];

    # Transform special attributes
    foreach my $special ( grep( index($_, '-') == 0, keys %$att ) ) {
      $att->{'serial:' . substr($special,1) } =
	delete $att->{$special};
    };

    # Add attributes to node
    $node->attrs($att);
  };

  # Add comment
  $node->comment($comment) if $comment;

  return $node;
};


# Add extension to document
sub add_extension {
  my $self = shift;

  # Get root element
  my $root = $self->_root_element or return;

  # New Loader
  my $loader = Mojo::Loader->new;

  # Get ext string
  my @ext = split(/;\s/, $root->[2]->{'serial:ext'} || '');

  my $loaded = 0;

  # Try all given extension names
  while (my $ext = shift( @_ )) {

    # Unable to load extension
    if (my $e = $loader->load($ext)) {
      warn "Exception: $e"  if ref $e;
      warn qq{Unable to load extension "$ext"};
      next;
    };

    {
      no strict 'refs';

      # Check for extension delegation
      if (defined ${ $ext . '::DELEGATE' }) {
	$ext = ${ $ext . '::DELEGATE' };

	# No recursion for security
	if (my $e = $loader->load($ext)) {
	  warn "Exception: $e" if ref $e;
	  warn qq{Unable to load delegated extension "$ext"};
	  next;
	};
      };

      # Add extension to extensions list
      push(@ext, $ext);
      $loaded++;

      # Add namespace for extension
      if (defined ${ $ext . '::NAMESPACE' } &&
	    defined ${ $ext . '::PREFIX' }) {

	$root->[2]->{ 'xmlns:' . ${ $ext . '::PREFIX' } } =
	  ${ $ext . '::NAMESPACE' };
      };
    };
  };

  # Save extension list as attribute
  $root->[2]->{'serial:ext'} = join("; ", @ext);

  return $loaded;
};


# Add namespace to root
sub add_namespace {
  my $self   = shift;
  my $ns     = pop;
  my $prefix = shift;

  # Get root element
  my $root = $self->_root_element or return;

  # Save namespace as attribute
  $root->[2]->{'xmlns' . ($prefix ? ":$prefix" : '')} = $ns;
  return $prefix;
};


# Prepend a comment to the XML node
sub comment {
  my $self = shift;
  $self->prepend('<!--' . b( shift )->xml_escape . '-->');
  return $self;
};


# Render as pretty xml
sub to_pretty_xml {
  my $self = shift;
  my $start = shift // 0;
  return _render_pretty($start, $self->tree);
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

      # Trim whitespace from both ends
      s/[\s\t\n]+$//;
      s/^[\s\t\n]+//;

      # Escape
      $_ = b($_)->xml_escape;
    };

    return $escaped;
  }

  # Element is comment
  elsif ($e eq 'comment') {
    my $comment = join("\n" . ( I x ($i + 2) ), # Todo: Why I.I ?
		       split(/;\s/, $tree->[1]));
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
    foreach my $child_e_i (1 .. $#$tree) {
      $content .=
	_render_pretty( $i, $tree->[$child_e_i] );
    };

    return $content;
  };
};


# Render element with pretty printing
sub _element {
  my $i = shift;

  my ($type,
      $qname,
      $attr,
      $child) = @{ $_[0] };

  # Is the qname valid?
  croak($qname.' is no valid QName')
    unless $qname =~ /^(?:[a-zA-Z_]+:)?[^\s]+$/;

  # Start start tag
  my $content = (I x $i) . '<' . $qname;

  # Add attributes
  $content .= _attr((I x $i).(' ' x ( length($qname) + 2)), $attr);

  # Has the element a child?
  if ($child->[0]) {

    # Close start tag
    $content .= '>';

    # There is only a textual child - no indentation
    if (!$child->[1] &&
	  ($child->[0] && $child->[0]->[0] eq 'text')
	) {

      # Special content treatment
      if (exists $attr->{'serial:type'}) {

	# With base64 indentation
	if ($attr->{'serial:type'} =~ /^armour(?::(\d+))?$/) {
	  my $n = $1 || 60;

	  my $string = $child->[0]->[1];

	  # Delete whitespace
	  $string =~ tr{\t-\x0d }{}d;

	  $content .= "\n";

	  # Introduce newlines after n characters
	  $content .= I x ($i + 1);
	  $content .= join( "\n" . ( I x ($i + 1) ),
			    ( unpack '(A'.$n.')*', $string ) );
	  $content .= "\n" . (I x $i);
	}

	# Escape
	elsif ($attr->{'serial:type'} eq 'escape') {
	  $content .= b($child->[0]->[1])->xml_escape;
	}

	# No special content treatment indentation
	else {
	  $content .= $child->[0]->[1];
	};
      }

      # No special content treatment indentation
      else {
	$content .= $child->[0]->[1];
      };
    }

    # Treat children special
    elsif (exists $attr->{'serial:type'}) {
      if ($attr->{'serial:type'} eq 'raw') {
	foreach my $e_child (@$child) {
	  $content .= __PACKAGE__->new->tree($e_child)->to_xml;
	};
      }

      # Todo:
      elsif ($attr->{'serial:type'} eq 'escape') {
	$content .= "\n";

	foreach my $e_child (@$child) {

	  # Todo: Need a start indentation flag for pretty_xml
	  $content .= b(__PACKAGE__->new->tree($e_child)->to_pretty_xml($i + 1))->xml_escape;
	};

	# Correct Indent
	$content .= (I x $i);

      };
    }

    # There are some childs
    else {
      $content .= "\n";

      # Loop through all child elements
      foreach my $child_e (@$child) {

	# Render next element
	$content .= _render_pretty( $i + 1, $child_e );
      };

      # Correct Indent
      $content .= (I x $i);
    };

    # End Tag
    $content .= '</' . $qname . ">\n";
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
    my %attr         = %{$_[0]};

    # Delete special attributes
    foreach (grep(
      $_ eq 'xmlns:serial' || index($_,'serial:') == 0,
      keys %attr)) {
      delete $attr{$_};
    };

    # Prepare attribute values
    foreach (values %attr) {
	$_ = b($_)->xml_escape->quote;
    };

    # Return indented attribute string
    if (keys %attr) {
      return ' ' .
	join("\n".$indent_space,
	     map($_ . '=' . $attr{$_}, sort keys %attr ) );
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
    while ($root->[$i] &&
	     $root->[$i]->[0] &&
	       $root->[$i]->[0] ne 'tag') {
      $i++;
    };
    $tag = $root->[$i];
  }

  # Root is a tag
  else {
    while ($root->[0] eq 'tag') {
      $tag = $root;
      last unless my $parent = $root->[3];
      $root = $parent;
    };
  };

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

  # Get ext string
  my $ext_string;
  if ($ext_string = $root->[2]->{'serial:ext'}) {
    no strict 'refs';

    foreach my $ext ( split(/;\s/, $ext_string ) ) {
      # Method does not exist in extension
      next unless  defined *{ "${ext}::$method" };

      # Release method
      return *{ "${ext}::$method" }->($self, @param);
    };
  };

  my $errstr = qq{Can't locate object method "$method" via package "$package"};
  $errstr .= qq{ with extensions "$ext_string"} if $ext_string;

  warn $errstr;
  return;
};


1;


__END__

=pod

=head1 NAME

MojoX::XML - Mojo::DOM based XML generator


=head1 SYNOPSIS

  use MojoX::XML;

  my $xml = MojoX::XML->new('entry');

  # Add elements to the document
  my $env = $xml->add(
    env => { foo => 'bar' }
  );

  # Add namespace information for a prefix
  $xml->add_namespace(
    fun => 'http://sojolicio.us/ns/fun'
  );

  # Add children to elements of the document
  # using namespaces
  my $letter = $env->add(
    'fun:letter' => 'Hello World!'
  );

  # Attach comments to elements
  $letter->comment('My Greeting');

  # Print the result with pretty indentation
  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <entry xmlns:fun="http://sojolicio.us/ns/fun">
  #   <env foo="bar">
  #
  #     <!-- My Greeting -->
  #     <fun:letter>Hello World!</fun:letter>
  #   </env>
  # </entry>

  # Use Mojo::DOM's CSS3 selectors for retrieving nodes
  print $xml->at('env > *')->text;

  # Hello World!


=head1 DESCRIPTION

L<MojoX::XML> allows for the simple creation
of serialized XML documents with multiple namespaces and
pretty printing, while giving you the full power of L<Mojo::DOM>
traversal.


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

  my $xml = MojoX::XML->new('Document');
  $xml = MojoX::XML->new(Document => { foo => 'bar' });

  my $xml_new = $xml->new(Document => {id => 'new'} => 'My Content');

Construct a new L<MojoX::XML> object.
Accepts either all parameters supported by L<Mojo::DOM> or
all parameters supported by C<add>.


=head2 add

  my $xml = MojoX::XML->new('Document');
  $xml->add('Element');
  my $elem = $xml->add(Element => { type => 'text/plain' });
  $elem->add(Child => 'I\'m a child element');

  $xml->add(Text => { type => 'text/plain' }, 'Hello World!');
  $xml->add(Text => 'Hello World!');
  $xml->add(Text => 'Hello World!', 'This is a comment!');
  $xml->add(EmptyElement => undef, 'This is an empty element!');
  $xml->add(Data => { -type => 'armour' }, 'PdGzjvj..');

  $elem = $xml->new(Element => 'Hello World!');
  $xml->add($elem);

Add a new element to a L<MojoX::XML> object, either
as another L<MojoX::XML> object or newly defined.
Returns the root node of the added L<MojoX::XML>
object.

Parameters to define elements are a tag name,
followed by an optional hash reference
including all attributes of the XML element,
an optional text content,
and an optional comment on the element.
If the comment should be introduced without text content,
text content has to be C<undef>.

For rendering element content, a special C<-type> attribute
can be defined:

=head3 C<escape>

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


=head3 C<raw>

Treat children as raw data (no pretty printing).

=head3 C<armour>

Indent the content and automatically
introduce linebreaks after every
C<n>th character.
Intended for base64 encoded data.
Defaults to 60 characters linewidth after indentation.

  my $xml = MojoX::XML->new('entry');
  my $env = $xml->add('fun:env' => { foo => 'bar' });
  $xml->add_namespace(fun => 'http://sojolicio.us/ns/fun');
  my $data = $env->add(
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
  # <entry xmlns:fun="http://sojolicio.us/ns/fun">
  #   <fun:env foo="bar">
  #
  #     <!-- This is base64 data! -->
  #     <data type="text/plain">
  #       VGhpcyBpcyBqdXN0IGEgdGVzdCBzdH
  #       JpbmcgZm9yIHRoZSBhcm1vdXIgdHlw
  #       ZS4gSXQncyBwcmV0dHkgbG9uZyBmb3
  #       IgZXhhbXBsZSBpc3N1ZXMu
  #     </data>
  #   </fun:env>
  # </entry>


=head2 add_extension

  $xml->add_extension('Fun', 'MojoX::XML::Atom');

Add an array of packages as extensions to the root
of the document. See L<Extensions> for further information.


=head2 add_namespace

  my $xml = MojoX::XML->new('doc');
  $xml->add_namespace('http://sojolicio.us/ns/global');
  $xml->add_namespace(fun => 'http://sojolicio.us/ns/fun');
  $xml->add('fun:test' => { foo => 'bar' }, 'Works!');

  print $xml->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <doc xmlns="http://sojolicio.us/global"
  #      xmlns:fun="http://sojolicio.us/fun">
  #   <fun:test foo="bar">Works!</fun:test>
  # </doc>


Add namespace to the node's root.
The first parameter gives the prefix, the second one
the namespace. The prefix parameter is optional.
Namespaces are always added to the document's root, that
means, they have to be unique in the scope of the whole
document.


=head2 comment

  $node = $node->comment('Resource Descriptor');

Prepend a comment to the current node.


=head2 to_pretty_xml

  print $xml->to_pretty_xml;
  print $xml->to_pretty_xml(2);

Returns a stringified, pretty printed XML document.
Optionally accepts a numerical parameter,
defining the start indentation (defaults to zero).


=head1 EXTENSIONS

  package MyAtom;
  use MojoX::XML with => (
    prefix    => 'atom',
    namespace => 'http://www.w3.org/2005/Atom',
    mime      => 'application/atom+xml'
  );

  # Add id
  sub add_id {
    my $self = shift;
    my $id = shift or return;
    my $element = $self->add('id', $id);
    $element->parent->attrs('xml:id' => $id);
    return $element;
  };


L<MojoX::XML> allows for inheritance
and thus provides two ways of extending the functionality:
By using a derived class as a base class or by extending a
base class with the C<add_extension> method.

For this purpose three attributes can be set when using
L<MojoX::XML>.

=over 2

=item C<namespace>

Namespace of the extension.

=item C<prefix>

Preferred prefix to associate with the namespace.

=item C<mime>

Mime type of the base document.

=back


These class variables can be defined in a derived L<MojoX::XML> class.

  package Fun;
  use MojoX::XML with => (
    namespace => 'http://sojolicio.us/ns/fun',
    prefix => 'fun'
  );

  sub add_happy {
    my $self = shift;
    my $word = shift;

    my $cool = $self->add('-Cool');
    my $cry  = uc($word) . '!!! \o/ ';
    $cool->add(Happy => {foo => 'bar'}, $cry);
  };

You can use this derived object in your application as you
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

The defined namespace is introduced as the documents
namespace. The prefix is not used for any C<add>
method.

Without any changes to the class, you can use this module as an
extension as well.

  use MojoX::XML;

  my $obj = MojoX::XML->new('object');
  $obj->add_extension('Fun');
  $obj->add_happy('Yeah!');
  print $obj->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <object xmlns:fun="http://sojolicio.us/ns/fun">
  #   <Cool>
  #     <fun:Happy foo="bar">YEAH!!!! \o/ </fun:Happy>
  #   </Cool>
  # </object>

The defined namespace of C<Fun> is introduced with the
prefix C<fun>. The prefix is prepended to all elements
added by C<add>, except for element names beginning with a C<->.

  $self->add(Link => { foo => 'bar' });
  $self->add(-Link => { foo => 'bar' });
  # Both <Link foo="bar" /> in base context,
  # but prefixed in extension context.

New extensions can always be introduced to a base class,
whether it is derived or not.


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/MojoX-XML


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
