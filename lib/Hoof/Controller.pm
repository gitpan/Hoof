package Hoof::Controller;

use strict;
use warnings;

use base 'Hoof::Node';

use Hoof::Plugin;

actions qw[update delete];

sub Template_name($) {
	my $self = shift;
	return 'edit_'.lc($self->Model_class);
}

sub new($$$$) { # we don't seem to need a context here...
	my ($prot, $id, $parent, $name) = @_;
	my $self = $prot->SUPER::new($id, $parent, $name);
	my $model = (defined $id) ? 
		$prot->Model_class->new($id) : 
		$prot->Model_class->new;
	$model->validate_on_access;
	$self->{'model'} = $model;
	return $self;
}

sub view($$) {
	my ($self, $context) = @_;
	$context->{'template'} = $self->Template_name;
	$context->add_variables(lc($self->Model_class) => $self->{'model'});
}

use constant check_delete => 1;

sub delete($$) {
	my ($self, $context) = @_;
	my $model = $self->{'model'};
	$self->check_delete($model, $context);
	$model->destroy;
	$context->{'redirect'} = $self->{'parent'}->path;
}

sub attributes($$) {
	my ($self, $context) = @_;
	return $context->collect_params($self->{'model'}->Attributes_for_init);
}

sub post_update_hook($$) {
	my ($self, $context) = @_;
	$context->{'redirect'} = $self->{'parent'}->path;
}

use constant check_update => 1;

sub update($$) {
	my ($self, $context) = @_;
	my $model = $self->{'model'};
	my $attributes = $self->attributes($context);
	$model->fill($attributes);
	$self->check_update($model, $context);
	if ($model->save) {
		$self->post_update_hook;
	} elsif (UNIVERSAL::isa($@, 'Hoof::ValidationError')) {
		$context->add_variables('error' => $@);
		$model->revert;
		$self->view;
	} else {
		$@->throw;
	}
}

1;