package Hoof::Cache;

use warnings;
use strict;

use Storable;
use IO::Dir;

use Hoof;
use Hoof::Plugin;

sub new($$) {
	my ($prot, $name) = @_;
	my $self = [$name];
	bless($self, ref($prot)||$prot);
	$self->reload();
	return $self;
}

my ($timestamp, $changed);

sub load($) {
	my $prot = shift;
	my $cache_file = Hoof->options->{'cache_file'};
	return unless -e $cache_file;
	my $root;
	$timestamp = (stat $cache_file)[9];
	eval {
		($Hoof::Plugin::Registry, $root) = @{retrieve $cache_file};
	};
 	print STDERR "couldn't load cache: $@" if $@;
 	unless (!$@ && $root && UNIVERSAL::isa($root, __PACKAGE__)) {
 		print STDERR "cache is invalid\n";
	 	unlink $cache_file;
	}
 	$root->update if defined $root;
	return $root;
}

sub save($) {
	my $self = shift;
	if (Hoof->options->{'cache_file'} && $changed) {
		store [$Hoof::Plugin::Registry, $self], Hoof->options->{'cache_file'};
		print STDERR "updating cache on disk\n";
	}
	undef $changed;
}

sub name($) {
	$_[0]->[0];
}

sub children($) {
	return $_[0]->[1] ||= {};
}

sub update($) {
	my $self = shift;
	my $mtime = (stat($self->name))[9];
	warn "'".$self->name."' not found" unless defined $mtime;
	if ($mtime > $timestamp) {
		print STDERR "reloading $self->[0]\n";
		$self->reload;
	} else {
		for (values %{$self->children}) {
			if (ref $_) {
				$_->update;
			} else {
				my $mtime = (stat($_))[9];
				warn "'$_' not found" unless defined $mtime;
				require $_ if ($mtime > $timestamp);
			}
		}
	}
}

sub reload($) {
	my $self = shift;
#	print STDERR "reloading $self->{name}\n";
	my $dir;
	my $children = $self->children;
	my @children = keys %$children;
	unless ($dir = new IO::Dir($self->name)) {
		print STDERR "couldn't open directory '$self->[0]'\n";
		$self->delete_children(@children);
		return;
	}
	my %defined_children;
	@defined_children{@children} = undef;
	while (defined (my $name = $dir->read)) {
		next if $name =~ /^\./;
		my $path = $self->name."/$name";
		if ($name =~ /\.pm$/ or (-d $path)) {
			if (exists $children->{$name}) {
				$children->{$name}->update if ref $children->{$name};
				delete $defined_children{$name};
			} else {
				print STDERR "adding $path\n";
				if (-d $path) {
	 				$children->{$name} = $self->new($path);
	 			} else {
	 				$children->{$name} = $path;
	 				require $path;
	 			}
 				$changed = 1;
			}
		}
	}
	$self->delete_children(keys %defined_children);
}

sub delete_children($@) {
	my ($self, @children) = @_;
	return unless @children;
	my $basename = $self->name;
	my $plugin_dir = Hoof->options->{'plugin_dir'};
	print STDERR "deleting $basename/$_\n" for @children;
#	$basename =~ s#^\Q$plugin_dir\E#Hoof::Plugin#;
#	$basename =~ s#/#::#g;
	Hoof::Plugin::remove($basename, @children);
	delete @{$self->children}{@children};
	$changed = 1;
}

1;
