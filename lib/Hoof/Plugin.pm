package Hoof::Plugin;

use strict;
use warnings;

use base 'Exporter';
BEGIN {
	our @EXPORT = qw[child_of actions];
	our @EXPORT_OK = qw[Registry remove load_plugin];
}

use Hoof;
use Hoof::Cache;

our $Registry;

sub Registry() {
	unless (defined $Registry) {
		my $root = 
			(Hoof->options->{'cache_file'} && Hoof::Cache->load) || 
			(new Hoof::Cache(Hoof->options->{'plugin_dir'})); 
				# side effect: the plugin registry is filled
		$root->save();
	}
	return $Registry;
}

sub actions(@) {
	my $package = caller;
	my %actions = %{$package->Actions || {}};
	for(@_) {
		if (UNIVERSAL::isa($_, 'HASH')) {
			@actions{keys %$_} = values %$_;
		} else {
			$actions{$_} = $_;
		}
	}
	$package->Actions(\%actions);
}

sub child_of($$) {
	my ($name, $class) = @_;
	my ($package, $filename, undef) = caller;
	my $entry = ($Registry->{"Hoof::Plugin::$class"} ||= {});
	$entry->{$name} = [$package, $filename];
}

sub remove($@) {
	my ($basename, @packages) = @_;
	s/\.pm$// for @packages;
	my $text = "^$basename/(".join('|', @packages).')\.pm$';
	my $re = qr[$text];
	for my $class(values %$Registry) {
		while (my ($name, $value) = each %$class) {
			delete $class->{$name} if $value->[1] =~ $re;
		}
	}
}

sub load_plugin($) {
	my $plugin = shift;
	my $plugin_dir = Hoof->options->{'plugin_dir'};
	$plugin =~ s#^Hoof::Plugin#$plugin_dir#;
	$plugin =~ s#::#/#g;
	require "$plugin.pm";
}

1;
