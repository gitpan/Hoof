package Hoof::Exception;

use strict;
use warnings;

use Carp;

use overload 
	'""' => 'reason', 
	'cmp' => sub { "$_[0]" cmp "$_[1]" };

# standard constructor. 

sub new($@) {
	my $prot = shift;
	my $self;
	if (@_ > 1) {
		$self = { @_ };
	} elsif (@_ == 1) {
		$self = { 'reason' => shift() };
	} else {
		$self = {};
	}
	bless($self, ref($prot)||$prot);
	local $Carp::CarpLevel = 1;
	$self->{'stacktrace'} = Carp::longmess($self->reason);
	return $self;
}

sub reason($) {
	return $_[0]->{'reason'} || $_[0]->default_reason();
}

sub throw($@) {
	my $prot = shift;
	my $ex = (ref $prot) ? $prot : $prot->new(@_);
	if (defined wantarray) {
# 		return $ex;
		$@ = $ex;
		return;
	} else {
		die $ex;
	}
}

sub handle($$) {
	my ($self, $context) = @_;
	$context->{'template'} = 'error';
	$context->add_variables('error' => $self);
}

use constant status => undef;
use constant default_reason => '';

package Hoof::NotFoundError;

our @ISA = qw[Hoof::Exception];

use constant status => '404 Not Found';
use constant default_reason => 'Invalid URL';

package Hoof::AccessDeniedError;

our @ISA = qw[Hoof::Exception];

use constant status => '403 Forbidden';
use constant default_reason => 'Sie verf&uuml;gen nicht &uuml;ber die n&ouml;tige Berechtigung, um die gew&uuml;nschte Aktion durchzuf&uuml;hren.';

package Hoof::ValidationError;

our @ISA = qw[Hoof::Exception];

package Hoof::InternalError;

our @ISA = qw[Hoof::Exception];

use constant status => '500 Internal Error';
use constant default_reason => 'Ein Interner Fehler ist aufgetreten. <br />Bitte versuchen sie es sp&auml;ter nocheinmal. Der Administrator wurde benachrichtigt.';

sub handle($$) {
	my ($self, $context) = @_;
	print STDERR "$self->{stacktrace}\n";
	$self->SUPER::handle($context);
}

package Hoof::DBException;

our @ISA = qw[Hoof:InternalError];

1;
