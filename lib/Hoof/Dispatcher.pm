package Hoof::Dispatcher;

use strict;
use warnings;

BEGIN {
	our @ISA = qw[Exporter];
	
	our @EXPORT = qw[child_native];
	our %EXPORT_TAGS = ('all' => [@EXPORT]);
}

use Hoof::Plugin;

sub import {
	my $package = shift;
	my $target = caller;
	my @symbols;
	my $classname;
	for (@_) {
		if (ref $_ eq 'HASH') {
			$classname = $_->{'class'};
		} else {
			push(@symbols, $_);
		}
	}
	__PACKAGE__->export_to_level(1, $package, @symbols);
	if (defined $classname) {
		no strict 'refs';
		*{"${target}::Class"} = sub() { $classname } 
			unless defined *{"${target}::Class"}{'CODE'};
	}
}

sub child_native($$) {
	my ($self, $name) = @_;
	my $class = 'Hoof::Plugin::'.$self->Class;
	Hoof::Plugin::load_plugin($class);
	return $class->new($name, $self, $name);
}

1;
