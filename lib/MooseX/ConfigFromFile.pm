package MooseX::ConfigFromFile;

use Moose::Role;
use MooseX::Types::Path::Tiny 'Path';
use MooseX::Types::Moose 'Undef';
use Try::Tiny;
use Carp qw(croak);
use namespace::autoclean;

requires 'get_config_from_file';

# overridable in consuming class or role to provide a default value
# This is called before instantiation, so it must be a class method,
# and not depend on any other attributes
sub _get_default_configfile { }

has configfile => (
    is => 'ro',
    isa => Path|Undef,
    coerce => 1,
    predicate => 'has_configfile',
    do { try { require MooseX::Getopt; (traits => ['Getopt']) } },
    lazy => 1,
    # it sucks that we have to do this rather than using a builder, but some old code
    # simply swaps in a new default sub into the attr definition
    default => sub { shift->_get_default_configfile },
);

sub new_with_config {
    my ($class, %opts) = @_;

    my $configfile;

    if(defined $opts{configfile}) {
        $configfile = $opts{configfile}
    }
    else {
        # This would only succeed if the consumer had defined a new configfile
        # sub to override the generated reader - as suggested in old
        # documentation
        $configfile = try { $class->configfile };

        # this is gross, but since a lot of users have swapped in their own
        # default subs, we have to keep calling it rather than calling a
        # builder sub directly - and it might not even be a coderef either
        my $cfmeta = $class->meta->find_attribute_by_name('configfile');
        $configfile = $cfmeta->default if not defined $configfile and $cfmeta->has_default;

        if (ref $configfile eq 'CODE') {
            $configfile = $configfile->($class);
        }

        my $init_arg = $cfmeta->init_arg;
        $opts{$init_arg} = $configfile if defined $configfile and defined $init_arg;
    }

    if (defined $configfile) {
        my $hash = $class->get_config_from_file($configfile);

        no warnings 'uninitialized';
        croak "get_config_from_file($configfile) did not return a hash (got $hash)"
            unless ref $hash eq 'HASH';

        %opts = (%$hash, %opts);
    }

    $class->new(%opts);
}

no Moose::Role; 1;

__END__

=pod

=head1 NAME

MooseX::ConfigFromFile - An abstract Moose role for setting attributes from a configfile

=head1 SYNOPSIS

  ########
  ## A real role based on this abstract role:
  ########

  package MooseX::SomeSpecificConfigRole;
  use Moose::Role;

  with 'MooseX::ConfigFromFile';

  use Some::ConfigFile::Loader ();

  sub get_config_from_file {
    my ($class, $file) = @_;

    my $options_hashref = Some::ConfigFile::Loader->load($file);

    return $options_hashref;
  }


  ########
  ## A class that uses it:
  ########
  package Foo;
  use Moose;
  with 'MooseX::SomeSpecificConfigRole';

  # optionally, default the configfile:
  sub _get_default_configfile { '/tmp/foo.yaml' }

  # ... insert your stuff here ...

  ########
  ## A script that uses the class with a configfile
  ########

  my $obj = Foo->new_with_config(configfile => '/etc/foo.yaml', other_opt => 'foo');

=head1 DESCRIPTION

This is an abstract role which provides an alternate constructor for creating
objects using parameters passed in from a configuration file.  The
actual implementation of reading the configuration file is left to
concrete sub-roles.

It declares an attribute C<configfile> and a class method C<new_with_config>,
and requires that concrete roles derived from it implement the class method
C<get_config_from_file>.

Attributes specified directly as arguments to C<new_with_config> supersede those
in the configfile.

L<MooseX::Getopt> knows about this abstract role, and will use it if available
to load attributes from the file specified by the command line flag C<--configfile>
during its normal C<new_with_options>.

=head1 Attributes

=head2 configfile

This is a L<Path::Tiny> object which can be coerced from a regular path
string or any object that supports stringification.
This is the file your attributes are loaded from.  You can add a default
configfile in the consuming class and it will be honored at the appropriate
time; see below at L</_get_default_configfile>.

If you have L<MooseX::Getopt> installed, this attribute will also have the
C<Getopt> trait supplied, so you can also set the configfile from the
command line.

=head1 Class Methods

=head2 new_with_config

This is an alternate constructor, which knows to look for the C<configfile> option
in its arguments and use that to set attributes.  It is much like L<MooseX::Getopts>'s
C<new_with_options>.  Example:

  my $foo = SomeClass->new_with_config(configfile => '/etc/foo.yaml');

Explicit arguments will override anything set by the configfile.

=head2 get_config_from_file

This class method is not implemented in this role, but it is required of all
classes or roles that consume this role.
Its two arguments are the class name and the configfile, and it is expected to return
a hashref of arguments to pass to C<new()> which are sourced from the configfile.

=head2 _get_default_configfile

This class method returns nothing by default, but can and should be redefined
in a consuming class to return the default value of the configfile (if not
passed into the constructor explicitly).

=head1 COPYRIGHT

Copyright (c) - the MooseX::ConfigFromFile "AUTHOR" and "CONTRIBUTORS" as listed below.

=head1 AUTHOR

Brandon L. Black, E<lt>blblack@gmail.comE<gt>

=head1 CONTRIBUTORS

=over

=item Tomas Doran

=item Karen Etheridge

=item Chris Prather

=item Zbigniew Lukasiak

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
