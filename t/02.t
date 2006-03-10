
use strict;
use FindBin::libs;

use Symbol;

use Test::More qw( tests 2 );

use Sub::Autostub verbose => 1;

my $ref = qualify_to_ref 'AUTOLOAD', __PACKAGE__;

my $one = frobnicate( foo => 'bar', bletch => 1 );

ok( *{ $ref }{CODE}, 'AUTOLOAD installed' );

ok( $one == 1, 'Local autoload returns 1' );

__END__
