package Hoof::Context;

use strict;
use warnings;

use CGI;
use Template;

#use Util;
use Hoof::Exception;
use Hoof::Escape;
use Hoof::Plugin;
use Hoof;

sub new($;$) {
	my $prot = shift;
	my $self;
	if ($ENV{'MOD_PERL'} and @_ == 1) {
		my $r = shift;
		my $q;
		eval {
			require 'Apache::Request';
			$q = new Apache::Request($r);
		};
		if ($@) {
			$q = new CGI($r);
		}
		$self = {
			'output' => $r, 
			'q' => $q,
		};
	} else {
		$self = { 
			'q' => new CGI, 
			'output' => \*STDOUT, 
			'variables' => Hoof->options->{'variables'}
		};
	}
	bless($self, ref($prot)||$prot);
	return $self;
}

sub handle_request($) {
	my $self = shift;
	my $root_class = 'Hoof::Plugin::'.Hoof->options->{'root_class'};
	Hoof::Plugin::load_plugin($root_class);
	$root_class->new->handle_request($self->{'q'}->path_info, $self);
}

sub render($) {
	my $self = shift;
	if ($self->{'template'}) {
		my $variables = $self->{'variables'};
		$variables->{'header'} = $self->{'q'}->header;
		my $template = new Template(
			INCLUDE_PATH => 'templates', 
			POST_CHOMP => 0, 
			PRE_CHOMP => 1,
			INTERPOLATE => 1, 
			COMPILE_EXT => '.ttc', 
			COMPILE_DIR => '/tmp/ttc/qdb', 
		);
		my $escape = 'Hoof::Escape::'.($self->{'encoding'}||'HTML');
		$template->process($self->{'template'}, $escape->new($variables), $self->{'output'}) || die $template->error;
	} else {
		$self->show_redirect($self->{'redirect'} || $self->{'q'}->param('nextpage') || ($self->{'action'} && $self->{'path'}) || '');
	}
}

sub show_redirect($$) {
	my ($context, $loc) = @_;
	$loc ||= '';
	my $www_server = $context->{'variables'}{'www_server'};
	my $www_root = $context->{'variables'}{'www_root'};
# 	my $query = query_string();
# 	print STDERR "loc: '$loc' query: '$query'\n";
	if ($context->{'cookie'}) { 
		$context->{'output'}->print($context->{'q'}->redirect(
			-uri => "http://$www_server$www_root/$loc", 
			-cookie => [$context->user_cookie(), $context->password_cookie()]
		));
	} else {
		$context->{'output'}->print($context->{'q'}->redirect(
			-uri => "http://$www_server$www_root/$loc"
		));
	}
}

sub collect_params($@) {
	my ($self, @params) = @_;
	my $params;
	for (@params) {
		$params->{$_} = $self->{'q'}->param($_) || '';
	}
	return $params;
}

sub check_admin($) {
	my ($self) = @_;
	die new Hoof::AccessDeniedError('Die gew&uuml;nschte Aktion kann nur von einem Administrator ausgef&uuml;hrt werden.')
		unless ($self->{'hoof_user'}->is_admin);
}

sub check_permitted($$) {
	my ($self, $userid) = @_;
	die new Hoof::AccessDeniedError('Sie sind nicht berechtigt, die gew&uuml;nschte Aktion auszuf&uuml;hren.')
		unless ($self->{'hoof_user'}->can_edit($userid));
}

sub user_cookie($) {
	my ($self) = @_;
	my $userid = $self->{'hoof_user'}->{'email'};
	return $self->{'q'}->cookie(-name => 'hoof_user', -value => $userid, -path => '/', -expires => $userid?'+10y':'now');
}

sub password_cookie($) {
	my ($self) = @_;
	my $password = $self->{'hoof_user'}->{'password'};
	return $self->{'q'}->cookie(-name => 'hoof_password', -value => $password, -path => '/', -expires => $password?'+10y':'now');
}

sub check_logged_in($) {
	my $self = shift;
	my $www_root = Hoof->options->{'www_root'};
	die new Hoof::AccessDeniedError(qq[Sie m&uuml;ssen <a href="$www_root/special/login?nextpage=].escape_url($self->{'path'}).qq[">eingeloggt</a> sein, um die gew&uuml;nschte Aktion auszuf&uuml;hren.])
		if $self->{'hoof_user'}->is_guest;
}

sub add_variables($@) {
	my $self = shift;
	for (@_) {
		my $key = shift;
		$self->{'variables'}{$key} = shift;
	}
}

1;
