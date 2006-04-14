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

our $VERSION    = '1.00';

our $AUTOLOAD   = '';

# 0 => nada
# 1 => call
# 2 => call + caller
# 3 => call + caller + args

my $verbosity   = 1;

our $verbose = sub { $verbosity = shift || 1 };

my $print_message
= sub
{
    if( $verbosity )
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

        if( $verbosity > 1 )
        {
            $callinfo[ 0 ] .= 'called at:';

            push @callinfo, ( caller 1 )[ 0, 1, 2 ];

        }

        if( $verbosity > 2 )
        {
            push @callinfo, "\rWith:", Dumper @_;
        }

        print @callinfo, 
    };
};

# store the return values for subs by package. this allows
# returning a fixed argument more interesting than one for
# any methods.
#
# handling updates requires folding any new values in via
# slice rather than bulk assignment.
#
# this also allows callers to get back a local copy of the
# return values for local assignment.  
#
# leaving $returnz->{ $caller } undefined will speed up
# the exists test, hence the if.

my $returnz = {};

our $return_values =
sub
{
    my $caller = shift;

    my $valuz = $returnz->{ $caller } ||= {};

    if( @_ )
    {
        my %argz = @_;

        @$valuz{ keys %argz } = values %argz;
    }

    $valuz
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

        # return defaults to 1. no telling if the caller
        # decided that a sub should return zero-but-true 
        # or undef, so this has to check for an existing
        # returns entry or zero.

        exists $returnz->{ $caller }{ $name }
        ? $returnz->{ $caller }{ $name } : 1;
    };

    # discard the current package name, then check the
    # arg's for anything useful. caller gets back either
    # a hash ref of return values or nada if there were
    # no arguments.

    shift;

    $return_values->( $caller, @_ );
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

            $returnz->{ $class }{ $name } ||= 1
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
        # assume this is a constructor.

        my $proto = shift;

        splice @_, 0, 1, "construct '$proto'";

        &$print_message;

        my ( $class ) = $AUTOLOAD =~ m{ ^ (.+) :: }x;

        my $ref = $returnz->{ $class }{ $name } ||= \$proto;

        bless $ref, $proto;
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

    use Sub::Autostub;

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


    # sometimes it's handy to get something other 
    # than 1 back from all of the calls. use makes 
    #
    # sets $a to { this => 'test' } verbosely.

    use Sub::Autostub
    (
        frobnicate  => { this => 'test' }
    );

    $Sub::Autostub->verbose( 1 );

    my $a = frobnicate foo => 1;

    # no import mechanism for use base...
    # $returnz->{ class }{ method } stores the return
    # value. in this case allowing testify to return
    # zero but true.

    use base Sub::Autostub;

    $Sub::Autostub::return_values->
    (
        {
            foo => 0E0,

            bar => 'bletch',
        }
    );

    $verbose->( 1 );

    # foo and bar now return 0E0 and 'bletch' verbosely.

    $obj->foo;

    $obj->bar;

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

=head2 Specific Return Values

There are times when returning 1 for all subs just doesn't
cut it. A fixed value can be returned for specific sub's
(even if they don't yet exist) by passing in a hash of 
sub names and their returns via:

    # Functinal

    use Stub::Autostub
    qw( foo => 0E0, bar => 'Your Message Here' );

or

    # OO or functional

    $Sub::Autostub::return_values->
    (
        foo => 0E0,
        bar => 'Your Message Here'
    );

The call to return_values will pass back a hash
reference, which allows for one-time return values
via local:

    # test something...

    my $valuz = $Sub::Autostub::return_values->( foo => 1 );

    ...

    sub test_reply
    {
        local $valuz->{ reply } => 'The moon! the sun: it is not moonlight now.';

        $katharina->reply( 'how bright and goodly shines the moon!' );
    }

This could be handy for some situations with Test::* where
controling the return values is useful for testing handling
of returned error codes.

=head2 Verbosity

The verbosity of logging output is controlled via:

    $Sub::Autostub::verbose->( $level )

with the levels of 0 (silent), 1 (log call), 2 (log call & 
caller), or 3 (log call, caller, & arguments).

The default level is 1.


=head1 KNOWN ISSUES

=over 4

=item All class methods default to a constructor.

If the first argument in OO code (i.e., via use base) is 
not a referent then it is assumed to be a constructor. This
is less painful than it seems at first since class methods
are usually few, coded early, and can be explicitly stubbed
easily via code or setting explicit return values.

=item The default object is simplistic.

This is also less painful than it looks at first since a workable
constructor is the first thing people usually add to a class. After
that the AUTOLOAD here is never called and the only issue is class
methods (see previous entry).

Fix for this is either adding an explicit stub constructor
early or setting the return value for the constructor to 
some more useful value via $Sub::Autostub::return_values.

=back

=head1 COPYRIGHT

Copyright (C) 2005, Steven Lembark. This code is released
under the same terms as Perl-5.8.0 itself.

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>
