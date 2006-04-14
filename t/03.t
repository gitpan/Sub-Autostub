
use strict;
use FindBin::libs;

use Test::More qw( tests 4 );

$Sub::Autostub::verbose->( 3 );

my $ref = Classy->can( 'AUTOLOAD' );

my $hash = {};

$Sub::Autostub::return_values->
(
    'Classy',
    constructify    => $hash,
    whatever        =>  2,
);

my $obj = Classy->constructify( qw(foo bar bletch) );

my $two = $obj->whatever( some => 'argument' );

ok( $ref, 'AUTOLOAD ' );

ok( ref $obj, 'AUTOLOAD returns object for non-ref argument' );

ok( 0+$obj == 0+$hash, "Constructify returns $hash" );

ok( $two == 2, 'Autoloaded OO call returns 2' );

package Classy;

use strict;

use base qw( Sub::Autostub );

__END__
