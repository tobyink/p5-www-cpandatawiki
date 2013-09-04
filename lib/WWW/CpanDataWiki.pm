use 5.010001;
use strict;
use warnings;

package WWW::CpanDataWiki;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Encode qw( encode_utf8 );
use HTTP::Exception;
use Moose;
use Plack::Response;
use Plack::Request;
use RDF::Trine qw( iri literal blank );
use Try::Tiny;
use namespace::autoclean;

has model => (
	is      => 'ro',
	isa     => 'RDF::Trine::Model',
	default => sub {
		my $dsn   = 'dbi:SQLite:dbname=cpan-data-wiki.sqlite';
		my $store = 'RDF::Trine::Store::DBI'->new(__PACKAGE__, $dsn, '', '');
		$store->init;
		'RDF::Trine::Model'->new($store);
	},
	handles => [qw/ add_statement remove_statement get_statements /],
);

sub app {
	my $self = shift;
	
	return sub {
		my ($req, $res) = 'Plack::Request'->new(shift);
		my $path = $req->path;
		
		try {
			if ($path eq '/')
			{
				$res = $self->handle_root($req);
			}
			elsif ($path =~ m{ \A / (\w+) }x)
			{
				my $method = "handle_$1";
				$res = $self->$method($req)
					if $self->can($method);
			}
			
			'HTTP::Exception'->throw(404) unless $res;
		}
		catch {
			if ($_->isa('HTTP::Exception::Base')) {
				$res = 'Plack::Response'->new($_->code);
				$res->content_type('text/plain');
				$res->body($_->status_message . "\n");
			}
			else {
				die($_);
			}
		};
		
		$res->finalize;
	}
}

sub graph_for {
	my $self = shift;
	my ($req) = @_;
	
	return '<http://localhost/graph/tobyink>';
}

sub _return_rdf {
	my $self = shift;
	my ($req, $data) = @_;
	
	my ($ctype, $s) = RDF::Trine::Serializer->negotiate('request_headers' => $req->headers);
	
	my $res = 'Plack::Response'->new(200);
	$res->content_type($ctype);
	$res->headers->header(Vary => join(", ", qw(Accept)));
	$res->body(
		$data->isa('RDF::Trine::Model')
			? $s->serialize_model_to_string($data)
			: $s->serialize_iterator_to_string($data)
	);
	return $res;
}

sub handle_root {
	my $self = shift;
	
	my $res = 'Plack::Response'->new(200);
	$res->content_type('text/plain');
	$res->body("root page\n");	
	return $res;
}

sub handle_add {
	my $self = shift;
	my ($req) = @_;
	
	if ($req->method eq 'POST')
	{
		my ($s, $p, $o) = map scalar($req->param($_)), qw(s p o);
		my $g = $self->graph_for($req);
		$self->add_statement(
			'RDF::Trine::Statement::Quad'->new(
				map 'RDF::Trine::Node'->from_sse($_) => ($s, $p, $o, $g)
			),
		);
	}
	
	my $res = 'Plack::Response'->new(200);
	$res->content_type('text/plain');
	$res->body("form to add data\n");
	return $res;	
}

sub handle_remove {
	my $self = shift;
	my ($req) = @_;
	
	if ($req->method eq 'POST')
	{
		my ($s, $p, $o) = map scalar($req->param($_)), qw(s p o);
		my $g = $self->graph_for($req);
		$self->remove_statement(
			'RDF::Trine::Statement::Quad'->new(
				map 'RDF::Trine::Node'->from_sse($_) => ($s, $p, $o, $g)
			),
		);
	}
	
	my $res = 'Plack::Response'->new(200);
	$res->content_type('text/plain');
	$res->body("form to remove data\n");
	return $res;	
}

sub _split_release {
	$_ = shift;
	if (my ($d, $v) = /\A (.+) - ([^-]+) \z/x) {
		$v =~ s/\./-/g;
		return ($d, $v);
	}
	'HTTP::Exception'->throw(500);
}

sub handle_lookup {
	my $self = shift;
	my ($req) = @_;
	
	my $p = $req->parameters;
	
	my $uri = $p->{uri};
	$uri ||= sprintf('http://purl.org/NET/cpan-uri/dist/%s/project', $p->{distribution})
		if exists($p->{distribution});
	
	$uri ||= sprintf('http://purl.org/NET/cpan-uri/person/%s', lc($p->{author}))
		if exists($p->{author});
	
	$uri ||= sprintf('http://purl.org/NET/cpan-uri/dist/%s/v_%s', _split_release($p->{release}))
		if exists($p->{release});
	
	my $iter = $self->get_statements( iri($uri), undef, undef );
	return $self->_return_rdf($req, $iter);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

WWW::CpanDataWiki - data wiki about Perl

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=WWW-CpanDataWiki>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

