package Hoof::Node;
# base class for all plugins.

use strict;
use warnings;

use Hoof;
use Hoof::Exception;
use Hoof::Plugin qw[];

use constant title => '';
use constant visible => 2;
use constant expanded => 1;

use base 'Class::Data::Inheritable';
BEGIN {
	__PACKAGE__->mk_classdata('Actions');
}

sub new($$$$) {
	my ($prot, $id, $parent, $name) = @_;
	my $self = {
		'parent' => $parent, 
		'name'   => $name, 
		'id'     => $id
	};
	return bless($self, ref($prot)||$prot);
}

sub path($) {
	my $self = shift;
	return (defined $self->{'parent'}) ? 
		($self->{'parent'}->path . '/' . $self->{'name'}) : '';
}

sub child($$) {
	my ($self, $name) = @_;
	my $class = ref($self) || $self;
	my $child = Hoof::Plugin::Registry->{$class}{$name};
	if ($child) {
		my ($package, $filename) = @$child;
		require $filename;
		return $package->new(undef, $self, $name);
	} else {
		return $self->child_native($name);
	}
}

sub check_access($$) {
#	my ($self, $context) = @_;
	return 1;
}

sub handle_request($$$) {
	my ($self, $path, $context) = @_;
	my (undef, $name, $rest) = ($path =~ m#^(/*)([^/]*)/*(.*)$#);
	eval {
		if ($name) {
			my $child = $self->child($name);
			$child->check_access($context);
			$child->handle_request($rest, $context);
		} else {
			$context->{'info'} = $path;
			$context->add_variables('title' => $self->title);
			my $action = $context->{'q'}->param('action');
			if (defined $action) {
				my $action_method = $self->Actions->{$action};
				throw Hoof::NotFoundError("Ungültiger Parameter: action ($action)") unless defined $action_method;
				$self->$action_method($context);
			} else {
				$self->view($context);
			}
		}
	};
	if ($@) {
		my $error = (UNIVERSAL::isa($@, 'Hoof::Exception')) ?
			$@ : 
			new Hoof::InternalError($@);
		$error->handle($context);
	}
}

sub child_native($$$) {
	throw Hoof::NotFoundError(); 
}

1;
