package DBI::db;

sub do_cached {
	my($dbh, $statement, $attr, @params) = @_;
	my $sth = $dbh->prepare_cached($statement, $attr) or return undef;
	$sth->execute(@params) or return undef;
	my $rows = $sth->rows;
	return ($rows == 0) ? "0E0" : $rows;
}

package Hoof::Entity;

use strict;
use warnings;

use base 'Hoof::Model';
use Hoof;
use Hoof::Model;
use Hoof::Exception qw[affirm];

use Carp;
use DBI;

*import = \&Exporter::import;

use constant Primary_key => 'id';

sub Attributes_for_db($) {
	my $self = shift;
	my @attributes;
	while (my ($name, $meta) = each %{$self->Attributes}) {
		push(@attributes, @{$meta->{'mapping'} || [$name]}) 
			unless $meta->{'read_only'};
	}
	return wantarray ? @attributes : \@attributes;
}

sub Flat_attributes($) {
	$_[0]->Primary_key;
}

sub validate_on_update($) {
	return ($_[0]->validate) || throw Hoof::ValidationError;
}

*validate_on_create = \&validate_on_update;

sub validate_on_access($) {
	my $self = shift;
	if ($self->{'_lazy'}) {
		$self->read;
		$self->initialize;
		delete $self->{'_lazy'};
	}
	1;
}

sub fill($$) {
	my ($self, $attributes) = @_;
	$self->set($attributes);
	$self->initialize;
	delete $self->{'_lazy'};
}

sub prepare_for_db($) {
	my $self = shift;
	while (my ($name, $meta) = each %{$self->Attributes}) {
		$self->set($meta->{'mapping'} || $name, $self->get($name)->flatten) 
			if $meta->{'class'};
	}
	return 1;
}

sub save($) {
	my $self = shift;
	if ($self->has_primary_key) {
		return ($self->validate_on_update && 
			$self->prepare_for_db &&
			$self->update
			or throw $@
		);
	} else {
		return ($self->validate_on_create && 
			$self->prepare_for_db &&
			$self->create
			or throw $@
		);
	}
}

sub revert($) {
	my $self = shift;
	unless ($self->has_primary_key) {
		throw Hoof::Exception('revert() called without primary key');
	}
	$self->read or throw $@;
}

sub destroy($) {
	my $self = shift;
	unless ($self->has_primary_key) {
		throw Hoof::Exception('destroy() called without primary key');
	}
	$self->delete or throw $@;
	$self->lock;
}

my $dbh;

sub dbh($) {
	my $self = shift;
	my $options = Hoof->options;
	$dbh ||= DBI->connect(@$options{qw[db_name db_user db_pass]});
	return $dbh;
}

sub read_daf($$$@) {
	my ($self, $sql_string, $options) = @_;
	return sub {
		my $self = shift;
		my $dbh = $self->dbh;
		my @params = $options->{'param_fields'} ? 
			@{$self->get($options->{'param_fields'})} : 
			();
		my $result = $dbh->selectrow_arrayref($sql_string, undef, @params, @_);
		if (defined $result) {
			$self->set($options->{'result_fields'}, @$result);
			return 1;
		} elsif ($dbh->errstr) {
			throw Hoof::DBException($dbh->errstr);
		} else {
			throw Hoof::NotFoundError();
		}
	};
}

sub select_daf($$$@) {
	my ($self, $sql_string, $options) = @_;
	return sub {
		my $self = shift;
		my $context = shift;
		my $sth = $self->dbh->prepare_cached($sql_string);
		my @params = $options->{'param_fields'} ? 
			@{$self->get($options->{'param_fields'})} : 
			();
		$sth->execute(@params, @_) or throw Hoof::DBException($sth->errstr);
		my %result_set;
		$sth->bind_columns(\(@result_set{@{$options->{'result_fields'}}}));
		my @result;
		while ($sth->fetch) {
			push(@result, $options->{'class'}->new(\%result_set));
		};
		return wantarray ? @result : 
			(@result == 1) ? $result[0] : 
			\@result;
	};
}

sub do_daf($$$@) {
	my ($self, $sql_string, $options) = @_;
	return sub {
		my $self = shift;
		my $context = shift;
		my @params = $options->{'param_fields'} ? 
			@{$self->get($options->{'param_fields'})} : 
			();
		return ($self->dbh->do_cached($sql_string, undef, @params, @_)) ||
			throw Hoof::DBException($self->dbh->errstr);
	};
}

sub mk_daf($$$$$@) {
	my ($self, $type, $name) = splice(@_, 0, 3);
	my $package = $self->class;
	{
		no strict 'refs';
		return (*{"${package}::$name"} = $self->$type(@_));
	}
}

sub Where_clause($) {
	my $self = shift;
	my @conditions = map "$_ = ?", $self->Primary_key;
	return @conditions ? ' WHERE '.join(' AND ', @conditions) : '';
}


sub has_primary_key($) {
	my $self = shift;
	my $key;
	for (@{$self->get([$self->Primary_key])}) {
		return unless defined $_;
	}
	return 1;
}

sub create {
	my $self = $_[0];
	my @attributes = $self->Attributes_for_db;
	my $values = join(', ', ('?') x @attributes);
	goto &{$self->mk_daf('do_daf', 'create', 
		'INSERT INTO '.$self->Table.' ('.join(', ', @attributes).") VALUES ($values)", {
			'param_fields' => \@attributes
		})
	};
}

sub read {
	my $self = $_[0];
	my @attributes = $self->Attributes_for_init;
	goto &{$self->mk_daf('read_daf', 'read', 
		'SELECT '.join(', ', @attributes).' FROM '.$self->Table.$self->Where_clause, {
			'param_fields' => [$self->Primary_key], 
			'result_fields' => \@attributes
		})
	};
}

sub update {
	my $self = $_[0];
	my @attributes = $self->Attributes_for_db;
	my @changes = map "$_ = ?", @attributes;
	goto &{$self->mk_daf('do_daf', 'update', 
		'UPDATE '.$self->Table.' SET '.join(', ', @changes).$self->Where_clause, {
			'param_fields' => [@attributes, $self->Primary_key]
		})
	};
}

sub delete {
	my $self = $_[0];
	goto &{$self->mk_daf('do_daf', 'delete', 
		'DELETE FROM '.$self->Table.$self->Where_clause, {
			'param_fields' => [$self->Primary_key]
		})
	};
}

sub get_all {
	my $self = $_[0];
	my @attributes = ($self->Primary_key, $self->Attributes_for_init);
	goto &{$self->mk_daf('select_daf', 'get_all', 
		'SELECT '.join(', ', @attributes).' FROM '.$self->Table, {
			'result_fields' => \@attributes, 
			'class' => $self->class
		})
	};
}


1;
