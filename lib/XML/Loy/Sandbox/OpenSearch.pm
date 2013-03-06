package MojoX::XML::OpenSearch;
use Mojo::Base 'MojoX::XML';

our $MIME      = 'application/opensearchdescription+xml';
our $PREFIX    = 'osd';
our $NAMESPACE = 'http://a9.com/-/spec/opensearch/1.1/';

# Constructor
sub new {
  my $class = shift;
  my $osd;

  unless ($_[0]) {
    unshift(@_, 'OpenSearchDescription') ;
    $osd = $class->SUPER::new(@_);
  }

  else {
    $osd = $class->SUPER::new(@_);
  };

  return $osd;
};

sub add_short_name {
  shift->add(ShortName => shift);
};

sub add_long_name {
  shift->add(LongName => shift);
};

sub add_description {
  shift->add(Description => shift);
};

sub add_tags {
  shift->add(Tags => join(' ', @_));
};

sub add_contact {
  return shift->add(Contact => shift);
};



1;

__END__

  % use Mojo::ByteStream 'b';
<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
  <ShortName><%= $short_name %></ShortName>
% if (stash 'long_name') {
  <LongName><%= stash 'long_name' %></LongName>
% };
  <Description><%= $description %></Description>
% if (@$tags) {
  <Tags><%= join ' ', @$tags %></Tags>
% };
  <Contact>admin@example.com</Contact>
  <Url type="application/opensearchdescription+xml"
       template="<%= url_for 'opensearch-description' %>"/>
  <Url type="application/atom+xml"
       template="<%= endpoint 'opensearch' => { format => 'atom' } %>"/>
  <Url type="application/rss+xml"
       template="<%= endpoint 'opensearch' => { format => 'rss' } %>"/>
  <Url type="text/html"
       template="<%= endpoint 'opensearch' %>"/>
  <Image height="64"
         width="64"
         type="image/png">http://example.com/websearch.png</Image>
  <Image height="16"
         width="16"
         type="image/vnd.microsoft.icon">http://example.com/websearch.ico</Image>
  <Query role="example" searchTerms="cat" />
% foreach (qw(developer attribution syndication_right language)) {
%   if (stash $_) {
  <<%= b($_)->decamelize %>><%= stash $_ %></<%= b($_)->decamelize %>>
%   };
% };
% if (stash 'adult_content') {
  <AdultContent>true</AdultContent>
% };
  <OutputEncoding>UTF-8</OutputEncoding>
  <InputEncoding>UTF-8</InputEncoding>
</OpenSearchDescription>
