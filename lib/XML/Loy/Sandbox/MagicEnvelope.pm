package Mojolicious::Plugin::XML::MagicEnvelope;
use Mojo::Base 'Mojolicious::Plugin::XML::Base';
use Mojolicious::Plugin::Util::Base64url;

has 'mime'   => 'application/magic-envelope+xml';
has 'prefix' => 'me';
has 'ns_uri' => 'http://salmon-protocol.org/ns/magic-env';

# Todo: add_data can be called directly with me_add_data

sub add_me_provenance {
  return shift->add('provenance');
};

sub add_me_data {
  my $self = shift;

  # Nothing set
  return unless $_[0];

  # Default to text/plain
  my $type = $_[1] ? shift : 'text/plain';

  return $self->add('data' => {
    -type => 'armour:60',
    type  => $type
  } => b64url_encode( shift ));
};

sub add_me_encoding {
  return shift->add('encoding', shift || 'base64url');
};

sub add_me_alg {
  return shift->add('alg', shift || 'RSA-SHA256');
};

sub add_me_sig {
  my $self = shift;
  my %param;
  $param{'key_id'} = shift if $_[1];
  return $self->add('sig' => {
    -type => 'armour:60',
    %param
  } => b64url_encode( shift ));
};

1;
