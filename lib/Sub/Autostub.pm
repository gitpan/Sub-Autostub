########################################################################
# housekeeping
########################################################################

package Sub::Autostub;

use strict;

use Carp;
use Symbol;

use Data::Dumper;

use Scalar::Util qw( &blessed );

########################################################################
# package variables
########################################################################

our $VERSION    = '0.02';

our $AUTOLOAD   = '';

our $verbose    = 0;

my $print_message
= sub
{
    local $\ = "\n";
    local $, = "\n\t";

    local $Data::Dumper::Purity     = 1;
    local $Data::Dumper::Terse      = 1;
    local $Data::Dumper::Indent     = 1;
    local $Data::Dumper::Deparse    = 1;
    local $Data::Dumper::Sortkeys   = 1;
    local $Data::Dumper::Deepcopy   = 0;
    local $Data::Dumper::Quotekeys  = 0;

    my $sub = shift;

    my @callinfo = "Stub '$sub'";

    if( $verbose )
    {
        $callinfo[ 0 ] .= 'called at:';

        push @callinfo, ( caller 1 )[ 0, 1, 2 ];

        push @callinfo, "\rWith:";
    };

    print @callinfo, Dumper @_;

};

########################################################################
# functional handler:
#
# push an AUTOLOAD into the caller's package. this is how the 
# process knows the difference between functional and OO.
# 
# can also be useful if the calling class is inherited so that
# calls to the base class can be tracked.

sub import
{
    my $caller = caller;

    my $ref = qualify_to_ref 'AUTOLOAD', $caller;

    croak "Bogus import: '$caller' already has an AUTOLOAD"
    if *{ $ref }{ CODE };

    *$ref
    = sub
    {
        my $name = ( split /::/, $AUTOLOAD )[ -1 ];

        my $sub = join '::', $caller, $name;

        $print_message->( $sub, @_ );

        # return true for all calls.

        1
    };

    # check import args after discarding the package name.
    # verbose defaults to false.

    shift;

    my %argz = @_;

    $verbose = $argz{ verbose } ||= 0;

    ()
}

########################################################################
# OO handler lives here since the derived class does a use base to
# get access to the local AUTOLOAD. Issue here is that the caller 
# may need to stub a constructor. Fix there is to pass back a (minimal)
# object if the first argument is not a referent.
#
# this is less painful than it seems at first since the caller is likely
# to create their own constructor and class methods early in development
# and thus avoid this code entirely.

AUTOLOAD
{
    my $caller = caller;

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    if( ref $_[0] )
    {
        if( my $class = blessed $_[0] )
        {
            splice @_, 0, 1, "method '$name'";

            &$print_message;

            1
        }
        else
        {
            # this makes no sense, must not have been
            # called via $obj->method() notation. 

            croak "Bogus method call: not blessed '$_[0]'"
        }
    }
    else
    {
        # assume this is a constructor and make a new,
        # if pretty much useless, object.

        my $proto = shift;

        splice @_, 0, 1, "construct '$proto'";

        &$print_message;

        bless \$proto, $proto;
    }
}

# keep require happy

1

__END__

=head1 NAME

Sub::Autostub - Stubbed OO and functional calls with logging.

=head1 SYNOPSIS

    # functional

    package Foo;

    use Sub::Autostub verbose => 1;

    frobnicate foo => 1, bar => 2;

    # OO with constructor and methods stubbed

    package Bar;

    use base qw( Sub::Autostub );

    my $obj = Bar->construct( -foo => 'bar', -bletch => 'blort' );

    $obj->frobnicate( bar => 'foo' );

    # OO with the serving package shown

    package Base;

    use Sub::Autostub;

    package Derived;

    use base qw( Base );

    ...

    # this logs the call as being Base::construct if 
    # "construct" is still stubbed in both classes.

    my $obj = Derived->construct();

=head1 DESCRIPTION

During development the entire contents of some modules
may not be known. In this case stubbing the functions
or methods is helpful. Sub::Autostub simplifies this 
process with an AUTOLOAD that logs the subroutine being
called and the arguments passed via Data::Dumper. 

OO calls without a reference as the first argument the
call are assumed to be constructor's and return a minimal
object (see KNOWN ISSUES for more on this).

If the module is included via "use" then it exports an
AUTOLOAD into the caller's namespace. This will log the 
calls as "Stub Package::Name:" with the package value
assigned to the use-ing package. This is useful for 
functional programming or in cases where knowing which 
of multiple packages is resolved to handle a task in OO.

If the module is added via "use base" then the built-in
AUTOLOAD will be called. This will return a blessed 
scalar containing the name of the package if the first
argument is not a reference, otherwise it returns 1.
The former case is logged as "Stub construct $package:"
the latter as "Sub method $name:" each with the arguments
listed via Data::Dumper.

Setting $Sub::Autostub::verbose = 1 or passing "verbose" 
with a true value with the "use" will add source line 
information to the output. For an example see the 
t/02.t for verbose use, t/03.t for non-verbose.


=head1 KNOWN ISSUES

=over 4

=item All class methods default to a constructor.

If the first argument in OO code (i.e., via use base) is 
not a referent then it is assumed to be a constructor. This
is less painful than it seems at first since class methods
are usually few, coded early, and can be explicitly stubbed
easily.

Eventually, adding an argument to discern constructor-vs-class
method (e.g., constructor => 'blah') will be the best way to
handle this issue.

=item The default object is simplistic.

This is also less painful than it looks at first since a workable
constructor is the first thing people usually add to a class. After
that the AUTOLOAD here is never called and the only issue is class
methods (see previous entry).

=back

=head1 COPYRIGHT

=head1 AUTHOR

