package Hoof::Escape;

use strict;
use warnings;

use Carp;

use overload '""' => '_as_string';

sub new($$) {
	my ($prot, $value) = @_;
	if (!ref $value) {
		return $prot->_escape($value);
	} elsif (ref $value eq 'HASH') {
		for (values %$value) {
			$_ = new $prot($_);
		}
		return $value;
	} elsif (ref $value eq 'ARRAY') {
		for (@$value) {
			$_ = new $prot($_);
		}
		return $value;
	} else {
		return bless(\$value, ref($prot) || $prot);
	}
}

sub _encoding($) {
	my $class = ref($_[0]) || $_[0];
	$class =~ s/.*:://;
	return $class;
}

sub _as_string($) {
	my $self = shift;
	return $self->new("$$self");
}

our $AUTOLOAD;

sub AUTOLOAD {
	my $self = shift;
	my $wanted = $AUTOLOAD;
	$wanted =~ s/.*:://;
	return if $wanted eq 'DESTROY';
	my $value = ${$self}->$wanted;
#	if (${$self}->isa('Hoof::Model') && (${$self}->encoding($wanted) eq $self->_encoding)) {
#		return $value;
#	} else {
		return $self->new($value);
#	}
}

sub _escape($$) {
	$_[1];
}

package Hoof::Escape::HTML;

use strict;
use warnings;

our @ISA = qw[Hoof::Escape];

use HTML::Entities;

sub _escape($$) {
	HTML::Entities::encode_entities($_[1]);
}

package Hoof::Escape::UTF8;

use strict;
use warnings;

our @ISA = qw[Hoof::Escape];

use Encode;

sub _escape($$) {
	Encode::from_to($_[1], 'iso-8859-1', 'utf-8');
}

1;
