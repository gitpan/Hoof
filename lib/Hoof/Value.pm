package Hoof::Value;

use strict;
use warnings;

use base 'Hoof::Model';

*import = \&Exporter::import;

sub Flat_attributes($) {
	sort $_[0]->Attributes_for_db;
}

sub new($$) {
	my ($prot, $value) = shift;
	my $self;
	@self{$self->Flat_attributes} = (UNIVERSAL::isa($value, 'ARRAY')) ? 
		@$value : 
		($value);
	bless($self, ref($prot)||$prot)->initialize;
	return $self;
}

sub initialize($) {
	my $self = shift;
	$self->SUPER::initialize;
	$self->lock;
}

1;
