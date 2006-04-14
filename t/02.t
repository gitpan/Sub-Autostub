
use strict;
use FindBin::libs;

use Symbol;

use Test::More qw( tests 5 );

use Sub::Autostub;

my $ref = qualify_to_ref 'AUTOLOAD', __PACKAGE__;

ok( *{ $ref }{CODE}, 'AUTOLOAD installed' );

my $valuz = $Sub::Autostub::return_values->( __PACKAGE__ );

my @foo_valuz =
map
{
    $Sub::Autostub::verbose->( $_ );

    local $valuz->{ frobnicate } = $_;

    my $a = frobnicate( bletch => 'blort' );

    ok( $a == $_, "Return value, Verbosity set to: $_" );
}
( 0 .. 3 );

__END__
