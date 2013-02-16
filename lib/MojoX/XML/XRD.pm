package MojoX::XML::XRD;
use Mojo::JSON;
use Carp qw/carp/;
# use Mojo::Date::RFC3339;

use MojoX::XML with => (
  mime      => 'application/xrd+xml',
  namespace => 'http://docs.oasis-open.org/ns/xri/xrd-1.0',
  prefix    => 'xrd'
);


# Constructor
sub new {
  my $class = shift;

  my $xrd;

  # Empty
  unless ($_[0]) {
    unshift(@_, 'XRD') ;
    $xrd = $class->SUPER::new(@_);
  }

  # JRD
  elsif ($_[0] =~ /^\s*\{/) {
    $xrd = $class->SUPER::new('XRD');
    $xrd->_to_xml($_[0]);
  }

  # Whatever
  else {
    $xrd = $class->SUPER::new(@_);
  };

  # Add XMLSchema instance namespace
  $xrd->add_namespace(
    xsi => 'http://www.w3.org/2001/XMLSchema-instance'
  );

  return $xrd;
};


# Add Property
sub add_property {
  my $self = shift;
  my $type = shift;

  # Get possible attributes
  my %hash = (ref $_[0] && ref $_[0] eq 'HASH') ? %{ shift(@_) } : ();

  # Set type
  $hash{type} = $type;

  # Set xsi:nil unless there is content
  $hash{'xsi:nil'} = 'true' unless @_;

  # Return element
  return $self->add(Property => \%hash => @_ );
};


# Get Property
sub get_property {
  my $self = shift;

  # No type given
  return unless $_[0];

  # Returns the first match
  return $self->at( qq{Property[type="$_[0]"]} );
};


# Add Link
sub add_link {
  my $self = shift;
  my $rel = shift;
  my %hash;

  # No link given
  return unless $_[0];

  # Accept hash reference
  if (ref $_[0] && ref $_[0] eq 'HASH') {
    %hash = %{ $_[0] };
  }

  # Accept string
  else {
    $hash{href} = shift;
  };

  # Set relation
  $hash{rel} = $rel;

  # Return link object
  return $self->add(Link => \%hash);
};


# Get Link
sub get_link {
  my $self = shift;

  # Get relation
  my $rel = shift or return;

  # Returns the first match
  return $self->at( qq{Link[rel="$rel"]} );
};


# Get expiration date
# sub get_expiration {
#   my $self = shift;
#   my $exp = $self->at('Expires');
#
#   return 0 unless $exp;
#
#   return Mojo::Date::RFC3339->new($exp->text)->epoch;
# };


sub _to_xml {
  my $xrd = shift;


  my $json = Mojo::JSON->new;

  my $jrd = $json->decode($_[0]);

  carp $json->error unless $jrd;

  foreach my $key (keys %$jrd) {

    given ($key = lc($key)) {

      # Properties
      when ('properties') {
	_to_xml_properties($xrd, $jrd->{$key});
      }

      # Links
      when ('links') {
	_to_xml_links($xrd, $jrd->{$key});
      }

      # Subject or Expires
      when (['subject','expires']) {
	$xrd->add(ucfirst($key), $jrd->{$key});
      }

      # Aliases
      when ('aliases') {
	$xrd->add(Alias => $_) foreach (@{$jrd->{$key}});
      }

      # Titles
      when ('titles') {
	_to_xml_titles($xrd, $jrd->{$key});
      };
    };
  };
};


# Convert From JSON to XML
sub _to_xml_titles {
  my ($node, $hash) = @_;
  foreach (keys %$hash) {

    # Default
    if ($_ eq 'default') {
      $node->add(Title => $hash->{$_});
    }

    # Language
    else {
      $node->add(Title => { 'xml:lang' => $_ } => $hash->{$_});
    };
  };
};


# Convert from JSON to XML
sub _to_xml_links {
  my ($node, $array) = @_;

  # All link objects
  foreach (@$array) {

    # titles and properties
    my $titles     = delete $_->{titles};
    my $properties = delete $_->{properties};

    # Add new link object
    my $link = $node->add_link(delete $_->{rel}, $_);

    # Add titles and properties
    _to_xml_titles($link, $titles)         if $titles;
    _to_xml_properties($link, $properties) if $properties;
  };
};


# Convert from JSON to XML
sub _to_xml_properties {
  my ($node, $hash) = @_;

  $node->add_property($_ => $hash->{$_}) foreach keys %$hash;
};


# Render JRD
sub to_json {
  my $self = shift;
  my $root  = $self->root->at(':root');

  my %object;

  # Serialize Subject and Expires
  foreach (qw/Subject Expires/) {
    my $obj = $root->at($_);
    $object{lc($_)} = $obj->text if $obj;
  };

  # Serialize aliases
  my @aliases;
  $root->children('Alias')->each(
    sub {
      push(@aliases, shift->text );
    });
  $object{'aliases'} = \@aliases if @aliases;

  # Serialize titles
  my $titles = _to_json_titles($root);
  $object{'titles'} = $titles if keys %$titles;

  # Serialize properties
  my $properties = _to_json_properties($root);
  $object{'properties'} = $properties if keys %$properties;

  # Serialize links
  my @links;
  $root->children('Link')->each(
    sub {
      my $link = shift;
      my $link_att = $link->attrs;

      my %link_prop;
      foreach (qw/rel template href type/) {
	if (exists $link_att->{$_}) {
	  $link_prop{$_} = $link_att->{$_};
	};
      };

      # Serialize link titles
      my $link_titles = _to_json_titles($link);
      $link_prop{'titles'} = $link_titles if keys %$link_titles;

      # Serialize link properties
      my $link_properties = _to_json_properties($link);
      $link_prop{'properties'} = $link_properties
	if keys %$link_properties;

      push(@links, \%link_prop);
    });
  $object{'links'} = \@links if @links;
  return Mojo::JSON->new->encode(\%object);
};


# Serialize node titles
sub _to_json_titles {
  my $node = shift;
  my %titles;
  $node->children('Title')->each(
    sub {
      my $val  = $_->text;
      my $lang = $_->attrs->{'xml:lang'} || 'default';
      $titles{$lang} = $val;
    });
  return \%titles;
};


# Serialize node properties
sub _to_json_properties {
  my $node = shift;
  my %property;
  $node->children('Property')->each(
    sub {
      my $val = $_->text || undef;
      my $type = $_->attrs->{'type'};
      $property{$type} = $val;
    });
  return \%property;
};


1;


__END__

=pod

=head1 NAME

MojoX::XML::XRD - Extensible Resource Descriptor


=head1 SYNOPSIS

  use MojoX::XML::XRD;

  # Create new document
  my $xrd = MojoX::XML::XRD->new;

  # Set subject and alias using MojoX::XML's add method
  $xrd->add(Subject => 'http://sojolicio.us/');
  $xrd->add(Alias => 'https://sojolicio.us/');

  # Add properties
  $xrd->add_property(describedBy => '/me.foaf' );
  $xrd->add_property('private');

  # Add links
  $xrd->add_link(lrdd => {
    template => '/.well-known/webfinger?resource={uri}'
  });

  print $xrd->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"
  #      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  #   <Subject>http://sojolicio.us/</Subject>
  #   <Alias>https://sojolicio.us/</Alias>
  #   <Link rel="lrdd"
  #         template="/.well-known/webfinger?resource={uri}" />
  #   <Property type="describedby">/me.foaf</Property>
  #   <Property type="private"
  #             xsi:nil="true" />
  # </XRD>

  print $xrd->to_json;

  # {"subject":"http:\/\/sojolicio.us\/",
  # "aliases":["https:\/\/sojolicio.us\/"],
  # "links":[{"rel":"lrdd",
  # "template":"\/.well-known\/webfinger?resource={uri}"}],
  # "properties":{"private":null,"describedby":"\/me.foaf"}}

=head1 DESCRIPTION

L<MojoX::XML::XRD> is a L<MojoX::XML> base class for handling
L<Extensible Resource Descriptor|http://docs.oasis-open.org/xri/xrd/v1.0/xrd-1.0.html>
documents with L<JRD|https://tools.ietf.org/html/rfc6415> support.

This code may help you to create your own L<MojoX::XML> extensions.


=head1 METHODS

L<MojoX::XML::XRD> inherits all methods
from L<MojoX::XML> and implements the following new ones.


=head2 new

  # Empty document
  my $xrd = MojoX::XML::XRD->new;

  # New document by XRD
  $xrd = MojoX::XML::XRD->new(<<XRD);
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Subject>http://sojolicio.us/</Subject>
    <Alias>https://sojolicio.us/</Alias>
    <Link rel="lrdd"
          template="/.well-known/webfinger?resource={uri}" />
    <Property type="describedby">/me.foaf</Property>
    <Property type="private"
              xsi:nil="true" />
  </XRD>
  XRD

  print $xrd->get_link('lrdd')->attrs('template');

  # New document by JRD
  my $jrd = MojoX::XML::XRD->new(<<'JRD');
  {"subject":"http:\/\/sojolicio.us\/",
  "aliases":["https:\/\/sojolicio.us\/"],
  "links":[{"rel":"lrdd",
  "template":"\/.well-known\/webfinger?resource={uri}"}],
  "properties":{"private":null,"describedby":"\/me.foaf"}}
  JRD

  print $jrd->at('Alias')->text;


Create a new XRD document object.
Beside the accepted input of L<MojoX::XML' new|MojoX::XML/new>,
it can also parse L<JRD|https://tools.ietf.org/html/rfc6415> input.


=head2 add_property

  my $prop = $xrd->add_property(created => 'today');
  print prop->text;

Adds a property to the xrd document.
Returns a L<MojoX::XML::XRD> object.


=head2 get_property

  my $prop = $xrd->get_property('created');
  print prop->text;

Returns a L<Mojox::XML::XRD> element of the first
property element of the given type.


=head2 add_link

  my $link = $xrd->add_link(profile => '/me.html');

  $xrd->add_link(hcard => {
    href => '/me.hcard'
  })->add(Title => 'My hcard');

Adds a link to the xrd document.
Accepts the relation as a string and a hash reference
for the attributes. Is a string following the relation,
this is assumed to be the C<href> attribute.
Returns a L<MojoX::XML::XRD> object.


=head2 get_link

  print $xrd->get_link('lrdd')->attrs('href');

Returns a L<MojoX::XML::XRD> element of the first link
element of the given relation.


=head2 to_json

  print $xrd->to_json;

Returns a JSON string representing a
L<JRD|https://tools.ietf.org/html/rfc6415> document.


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/MojoX-XML


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut

