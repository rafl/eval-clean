use strict;
use warnings;
use Test::More;

use Eval::Clean;

my $perl = Eval::Clean::new_perl();
isa_ok($perl, 'Eval::Clean::Perl');

my $result = $perl->eval(
    '{ foo => 42, bar => "baz" }',
);

is_deeply(
    $result,
    { foo => 42, bar => 'baz' },
    'it worked',
);

{
    my $libs = $perl->eval("use strict; \\%INC");
    is_deeply(
        [keys %{ $libs }],
        ['strict.pm'],
        'only strict is loaded',
    );
}

{
    $perl->eval('package main; our $GLOBAL = 123;');
    my $global = $perl->eval('$GLOBAL');
    is $global, 123, 'state is preserved between perls';
}

{
    my $cv = $perl->eval('sub { 42 }');
    is $cv->(), 42, 'coderefs work';
}

{
    my $cv = $perl->eval('my $foo = 42; sub { $foo++ }');
    is $cv->(), 42, 'closures work';
    is $cv->(), 43, 'closures keep their state';
}

done_testing;
