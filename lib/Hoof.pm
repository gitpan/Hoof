package Hoof;

use strict;
use warnings;

our $VERSION = '0.01';

use YAML qw[LoadFile];

# use Data::Dumper;

use Hoof::Context;

sub handle_request($;$) {
	my ($self, $info) = @_;
	my $context_class = $self->options->{'context_class'} || 'Hoof::Context';
	my $context = (defined $info) ? 
		new $context_class() : 
		new $context_class($info);
	$context->handle_request;
	$context->render;
}

*handler = \&handle_request; # for mod_perl

my $options;

sub options($) {
	$options = LoadFile('config.yml') unless defined $options;
	return $options;
}

1;
