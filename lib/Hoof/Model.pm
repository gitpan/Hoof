package Hoof::Model;

use strict;
use warnings;

BEGIN {
	our @ISA = qw[Exporter];
	our @EXPORT = qw[attribute attributes];
}

use base qw[Class::Data::Inheritable];

use Carp;

use Hoof::Exception;

__PACKAGE__->mk_classdata('Attributes', {});

sub import {
	my $package = shift;
	my $target = caller;
	my @symbols;
	my $classname;
	for (@_) {
		if (ref $_ eq 'HASH') {
			$classname = $_->{'table'};
		} else {
			push(@symbols, $_);
		}
	}
	__PACKAGE__->export_to_level(1, $package, @symbols);
	if (defined $classname) {
		no strict 'refs';
		*{"${target}::Table"} = sub() { $classname } 
			unless defined *{"${target}::Table"}{'CODE'};
	}
}

sub new($@) {
	my $prot = shift;
	my $self;
	if (@_ == 1) {
		my $p = shift;
		if (UNIVERSAL::isa($p, 'HASH')) {
			%$self = %$p;
		} else {
			@$self{$prot->Flat_attributes} = UNIVERSAL::isa($p, 'ARRAY') ? @$p : ($p);
			$self->{'_lazy'} = UNIVERSAL::isa($prot, 'Hoof::Entity');
		}
	} else {
		%$self = @_;
	}
	bless($self, ref($prot)||$prot);
	$self->initialize unless $self->{'_lazy'};
	return $self;
}

sub class($) {
	return ref($_[0]) || $_[0];
}

sub encoding($$) {
	my ($self, $attr) = @_;
	return $self->Attributes->{$attr}{'encoding'} || '';
}

sub Attributes_for_init($) {
	my $self = shift;
	my @attributes;
	while (my ($name, $meta) = each %{$self->Attributes}) {
		push(@attributes, @{$meta->{'mapping'} || [$name]});
	}
	return wantarray ? @attributes : \@attributes;
}

sub initialize($) {
	my $self = shift;
	while (my ($name, $meta) = each %{$self->Attributes}) {
		$self->set($name, $meta->{'class'}->new($self->get($meta->{'mapping'} || $name))) 
			if $meta->{'class'};
	}
}

sub flatten($) {
	my $self = shift;
	return $self->get([$self->Flat_attributes]);
}

sub is_locked($) {
	my $self = shift;
	return $self->{'_locked'};
}

sub check_mutable($) {
	my $self = shift;
	return !($self->is_locked) || throw Hoof::AccessDeniedError;
}

sub validate($;$) {
	return 1; # TODO
}

sub validate_on_access($) { 1 }

sub lock($) {
	my $self = shift;
	$self->{'_locked'} = 1; # this even returns a true value... nice :-)
}

sub mk_attribute($$@) {
	my ($attr, $package, %meta) = @_;
	my %attributes = %{$package->Attributes};
	$attributes{$attr} = \%meta;
	$package->Attributes(\%attributes);
	my $read_only = $meta{'read_only'};
	my $access = sub($$;$) { 
		my $self = shift;
		if (defined $_[0]) {
			throw Hoof::AccessDeniedError if $read_only;
			return $self->set($attr, shift);
		} else {
			$self->validate_on_access;
			return $self->get($attr);
		}
	};
	{
		no strict 'refs';
		*{"${package}::$attr"} = $access unless defined *{"${package}::$attr"}{'CODE'};
	}
}

sub attribute($@) {
	my ($attr, @meta) = @_;
	mk_attribute($attr, caller, @meta);
}

sub attributes(@) {
	my ($last, $attr);
	my $package = caller;
	foreach $attr(@_) {
		if (UNIVERSAL::isa($attr, 'HASH')) {
			die "invalid syntax for 'attributes'" unless defined $last;
			mk_attribute($last, $package, %$attr);
			undef $last;
		} else {
			mk_attribute($last, $package) if $last;
			$last = $attr;
		}
	}
	mk_attribute($last, $package) if $last;
}

sub get($$) {
	my ($self, $field) = @_;
	if (UNIVERSAL::isa($field, 'ARRAY')) {
		return [@{$self}{@$field}];
	} else {
		return $self->{$field};
	}
}

sub set($$@) {
	my ($self, $field, @v) = @_;
	$self->check_mutable;
	my $num_values;
	if (UNIVERSAL::isa($field, 'ARRAY')) {
		@{$self}{@$field} = @v;
		$num_values = @$field;
	} elsif (UNIVERSAL::isa($field, 'HASH')) {
		@{$self}{keys %$field} = values %$field;
		$num_values = 0;
	} else {
		$self->{$field} = $v[0];
		$num_values = 1;
	}
	carp "wrong number of values for set (expected $num_values)" 
		unless @v == $num_values;
}


1;