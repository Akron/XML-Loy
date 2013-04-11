package XML::Loy::File;
use Mojo::ByteStream;
use XML::Loy with => (
  prefix    => 'loy',
  namespace => 'http://sojolicio.us/ns/xml-loy'
);

use Carp qw/carp/;

# No constructor
sub new {
  carp 'Only use ' . __PACKAGE__ . ' as an extension';
  return;
};


# Store filename
sub file {
  my $self = shift;

  # Get root element
  my $root = $self->_root_element or return;

  # Set file name
  if (@_) {

    # Get root element
    return $root->[2]->{'loy:file'} = shift;
  };

  # Get file name
  return $root->[2]->{'loy:file'};
};


# Save document to filesystem
sub save {
  my $self = shift;

  # Get file name
  my $file = shift || $self->file || return;

  # Remember filename
  $self->file($file) unless $self->file;


  # Create new bytestream
  my $byte = Mojo::ByteStream->new($self->root->to_pretty_xml);

  # Save data to filesystem
  return $byte->spurt( $file );
};


# Load document from filesystem
sub load {
  my $self = shift;

  # Get file name
  my $file = shift || $self->file || return;

  # Load data from file
  my $byte = Mojo::ByteStream->new($file)->slurp or return;

  # Remember filename
  $self->file($file);

  # Create new document
  return $self->new($byte);
};


1;


__END__

=pod

Not ready yet
