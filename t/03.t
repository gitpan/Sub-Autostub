
use strict;
use FindBin::libs;

use Test::More qw( tests 3 );

my $ref = Classy->can( 'AUTOLOAD' );

my $obj = Classy->constructify( qw(foo bar bletch) );

my $one = $obj->whatever( some => 'argument' );

ok( $ref, 'AUTOLOAD ' );

ok( ref $obj, 'AUTOLOAD returns object for non-ref argument' );

ok( $one == 1, 'Autoloaded OO call returns 1' );

package Classy;

use strict;

use base qw( Sub::Autostub );

__END__
