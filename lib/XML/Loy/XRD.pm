package XML::Loy::XRD;
use Mojo::JSON;
use Carp qw/carp/;
use XML::Loy::Date::RFC3339;

use XML::Loy with => (
  mime      => 'application/xrd+xml',
  namespace => 'http://docs.oasis-open.org/ns/xri/xrd-1.0',
  prefix    => 'xrd'
);

our @CARP_NOT;

# Constructor
sub new {
  my $class = shift;

  my $xrd;

  # Empty
  unless ($_[0]) {
    unshift(@_, 'XRD');
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
  $xrd->namespace(
    xsi => 'http://www.w3.org/2001/XMLSchema-instance'
  );

  return $xrd;
};


# Set subject
sub subject {
  my $self = shift;

  # Return subject
  unless ($_[0]) {

    # Subject found
    my $sub = $self->at('Subject') or return;
    return $sub->text;
  };

  # Set subject (only once)
  return $self->set(Subject => @_);
};


# Add alias
sub alias {
  my $self = shift;

  # Return subject
  unless ($_[0]) {

    # Subject found
    my $sub = $self->find('Alias') or return;
    return @{ $sub->pluck('text') };
  };

  # Add new alias
  $self->add(Alias => $_) foreach @_;

  return 1;
};


# Add Property
sub property {
  my $self = shift;

  return unless $_[0];

  my $type = shift;

  # Returns the first match
  return $self->at( qq{Property[type="$type"]} ) unless scalar @_ == 1;

  # Get possible attributes
  my %hash = ($_[0] && ref $_[0] && ref $_[0] eq 'HASH') ? %{ shift(@_) } : ();

  # Set type
  $hash{type} = $type;

  # Set xsi:nil unless there is content
  $hash{'xsi:nil'} = 'true' unless $_[0];

  # Return element
  return $self->add(Property => \%hash => @_ );
};


# Add Link
sub link {
  my $self = shift;

  # No rel given
  return unless $_[0];

  my $rel = shift;

  # Get link
  unless ($_[0]) {
    return $self->at( qq{Link[rel="$rel"]} );
  };

  my %hash;

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


# Set or get expiration date
sub expires {
  my $self = shift;

  # Return subject
  unless ($_[0]) {

    # Subject found
    my $exp = $self->at('Expires');

    return 0 unless $exp;

    return XML::Loy::Date::RFC3339->new($exp->text);
  };

  my $new_time = XML::Loy::Date::RFC3339->new($_[0])->to_string(0);

  return $self->set(Expires => $new_time) if $new_time;
};


# Check for expiration
sub expired {
  my $self = shift;

  # No expiration date given
  my $exp = $self->expires or return;

  # Document is expired
  return 1 if $exp->epoch < time;

  # Document is still current
  return;
};


# Convert to xml
sub _to_xml {
  my $xrd = shift;

  # Create new json object
  my $json = Mojo::JSON->new;

  # Parse json document
  my $jrd = $json->decode($_[0]);

  # There is a parsing error
  carp $json->error unless $jrd;

  # Itterate over all XRD elements
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
	$xrd->set(ucfirst($key), $jrd->{$key});
      }

      # Aliases
      when ('aliases') {
	$xrd->alias($_) foreach (@{$jrd->{$key}});
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
    my $link = $node->link(delete $_->{rel}, $_);

    # Add titles and properties
    _to_xml_titles($link, $titles)         if $titles;
    _to_xml_properties($link, $properties) if $properties;
  };
};


# Convert from JSON to XML
sub _to_xml_properties {
  my ($node, $hash) = @_;

  $node->property($_ => $hash->{$_}) foreach keys %$hash;
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

XML::Loy::XRD - Extensible Resource Descriptor Extension


=head1 SYNOPSIS

  use XML::Loy::XRD;

  # Create new document
  my $xrd = XML::Loy::XRD->new;

  # Set subject and alias
  $xrd->subject('http://sojolicio.us/');
  $xrd->alias('https://sojolicio.us/');

  # Add properties
  $xrd->property(describedBy => '/me.foaf' );
  $xrd->property(private => undef);

  # Add links
  $xrd->link(lrdd => {
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

L<XML::Loy::XRD> is a L<XML::Loy> base class for handling
L<Extensible Resource Descriptor|http://docs.oasis-open.org/xri/xrd/v1.0/xrd-1.0.html>
documents with L<JRD|https://tools.ietf.org/html/rfc6415> support.

This code may help you to create your own L<XML::Loy> extensions.

B<This module is an early release! There may be significant changes in the future.>

=head1 METHODS

L<XML::Loy::XRD> inherits all methods
from L<XML::Loy> and implements the following new ones.


=head2 new

  # Empty document
  my $xrd = XML::Loy::XRD->new;

  # New document by XRD
  $xrd = XML::Loy::XRD->new(<<XRD);
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

  print $xrd->link('lrdd')->attrs('template');

  # New document by JRD
  my $jrd = XML::Loy::XRD->new(<<'JRD');
  {"subject":"http:\/\/sojolicio.us\/",
  "aliases":["https:\/\/sojolicio.us\/"],
  "links":[{"rel":"lrdd",
  "template":"\/.well-known\/webfinger?resource={uri}"}],
  "properties":{"private":null,"describedby":"\/me.foaf"}}
  JRD

  print join ', ', $jrd->alias;


Create a new XRD document object.
Beside the accepted input of L<XML::Loy' new|XML::Loy/new>,
it can also parse L<JRD|https://tools.ietf.org/html/rfc6415> input.


=head2 alias

  $xrd->alias(
    'https://sojolicio.us/',
    'https://sojolicio.us'
  );
  my @aliases = $xrd->alias;

Adds multiple aliases to the xrd document
or returns an array of aliases.


=head2 expired

  if ($xrd->expired) {
    print "Don't use this document anymore!"
  };

Returns a C<true> value, if the document has expired
based on the value of C<E<lt>Expires /E<gt>>,
otherwise returns C<false>.


=head2 expires

  $xrd->expires('1264843800');
  # or
  $xrd->expires('2010-01-30T09:30:00Z');

  print $xrd->expires->to_string;

Set an expiration date or get the expiration date
as a L<XML::Loy::Date::RFC3339> object.

B<This method is experimental and may return another
object with a different API!>


=head2 link

  # Add links
  my $link = $xrd->link(profile => '/me.html');

  $xrd->link(hcard => {
    href => '/me.hcard'
  })->add(Title => 'My hcard');

  # Get links
  print $xrd->link('lrdd')->attrs('href');

  # use Mojo::DOM remove method
  $xrd->link('hcard')->remove;

Adds links to the xrd document or retrieve them.
Accepts the relation as a string and for adding a link
a hash reference containing the attributes.
Is a string following the relation,
this is assumed to be the C<href> attribute.
Returns a L<XML::Loy::XRD> object.


=head2 property

  # Add properties
  $xrd->property(created => 'today');
  my $prop = $xrd->property(private => undef);
  print prop->text;

  # Get properties
  my $prop = $xrd->property('created');
  print prop->text;

  # use Mojo::DOM remove method
  $xrd->property('private')->remove;

Add properties to the xrd document or retrieve them.
To add empty propertys, you have to pass C<undef> as the value.
Returns a L<XML::Loy::XRD> object.


=head2 subject

  $xrd->subject('http://sojolicio.us/');
  my $subject = $xrd->subject;

Set the subject of the xrd document
or return it.


=head2 to_json

  print $xrd->to_json;

Returns a JSON string representing a
L<JRD|https://tools.ietf.org/html/rfc6415> document.


=head1 MIME-TYPES

When loaded as a base class, L<XML::Loy::XRD>
makes the mime-type C<application/xrd+xml>
available.


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/XML-Loy


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut

