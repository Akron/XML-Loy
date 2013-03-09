package XML::Loy::Atom::Threading;

our $PREFIX;
BEGIN { $PREFIX = 'thr' };

use XML::Loy with => (
  prefix    => $PREFIX,
  namespace => 'http://purl.org/syndication/thread/1.0'
);

use Carp qw/carp/;

# No constructor
sub new {
  carp 'Only use ' . __PACKAGE__ . ' as an extension to Atom';
  return;
};


# Set 'in-reply-to' element
sub in_reply_to {
  my ($self, $ref, $param) = @_;

  # Set in-reply-to
  if ($ref) {

    # No ref defined
    return unless defined $ref;

    # Adding a related link as advised in the spec
    if (defined $param->{href}) {
      $self->link(related => $param->{href});
    };

    $param->{ref} = $ref;
    return $self->set('in-reply-to' => $param );
  };

};


# Set 'link' element for replies
sub replies {
  my $self = shift;
  my $href = shift;

  # No href defined
  return unless $href;

  my %param = %{ shift(@_) };

  my %new_param = (href => $href);
  if (exists $param{count}) {
    $new_param{$PREFIX . ':count'} = delete $param{count};
  };

  # updated parameter exists
  if (exists $param{updated}) {
    my $date = delete $param{updated};

    # Date is no object
    $date = XML::Loy::Date::RFC3339->new($date) unless ref $date;

    # Set parameter
    $new_param{$PREFIX . ':updated'} = $date->to_string;
  };

  $new_param{type} = $param{type} // $self->mime;

  # Add atom link
  $self->link(rel => 'replies',  %new_param );
};


# Add total value
sub total {
  my ($self, $count, $param) = @_;

  # Set count
  if ($count) {

    # Set new total element
    return $self->set(total => ($param || {}) => $count);
  };

  # Get total
  my $total = $self->children('total');

  # No total set
  return 0 unless $total = $total->[0];

  # Return count
  return $total->text if $total->text;

  return 0;
};


1;


__END__

=pod

=head1 NAME

XML::Loy::Atom::Threading - Threading Extension for Atom


=head1 SYNOPSIS

  use XML::Loy::Atom;

  my $entry = XML::Loy::Atom->new('entry');
  for ($entry) {
    $_->extension('XML::Loy::Atom::Threading');
    $_->author(name => 'Zoidberg');
    $_->id('http://sojolicio.us/blog/2');

    # Set threading information
    $_->in_reply_to('http://sojolicio.us/blog/1' => {
      href => 'http://sojolicio.us/blog/1'
    });
  };

  # Pretty print
  print $entry->to_pretty_xml;

  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <entry xmlns="http://www.w3.org/2005/Atom"
  #        xmlns:thr="http://purl.org/syndication/thread/1.0">
  #   <author>
  #     <name>Zoidberg</name>
  #   </author>
  #   <id>http://sojolicio.us/blog/2</id>
  #   <link rel="related"
  #         href="http://sojolicio.us/blog/1" />
  #   <thr:in-reply-to ref="http://sojolicio.us/blog/1"
  #                    href="http://sojolicio.us/blog/1" />
  # </entry>


=head1 DESCRIPTION

L<XML::Loy::Atom::Threading> is an extension to
L<XML::Loy::Atom> and provides additional
functionality for the work with
L<Threading|https://www.ietf.org/rfc/rfc4685.txt>.


=head2 C<in_reply_to>

  $self->in_reply_to('http://sojolicio.us/entry/1' => {
    href => 'http://sojolicio.us/entry/1.html
  });

Adds an C<in-reply-to> element to the Atom object.
Will automatically introduce a 'related' link, if a C<href> parameter is given.
Accepts one parameter with the reference string and an optional hash with
further attributes.


=head2 C<replies>

  $self->replies('http://sojolicio.us/entry/1/replies' => {
    count   => 5,
    updated => '2011-08-30T16:16:40Z'
  });

Adds a C<link> element with a relation of 'replies' to the atom object.
Accepts optional parameters for reply count and update.

The update parameter accepts all valid parameters of
L<XML::Loy::Date::RFC3339::new|XML::Loy::Date::RFC3339/new>.

B<This method is experimental and may return another
object with a different API!>


=head2 C<total>

  $self->total(5);

Adds a C<total> element for response count to the atom object.


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/XML-Loy


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, L<Nils Diewald|http://nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
