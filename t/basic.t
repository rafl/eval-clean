use strict;
use warnings;
use Test::More;
use Test::Exception;

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
    my $cv = $perl->eval('my $foo = 42; our $OTHER_GLOBAL = sub { $foo++ }');
    is $cv->(), 42, 'closures work';
    is $cv->(), 43, 'closures keep their state';

    $cv = $perl->eval('$OTHER_GLOBAL');
    is $cv->(), 42, "running closures from the cage doesn't change the cage";
}

{
    throws_ok sub {
        $perl->eval('BEGIN { die "foo" }');
    }, qr/\bfoo\b/, 'compile-time exceptions propagated from the cage';

    throws_ok sub {
        $perl->eval('die "foo"');
    }, qr/\bfoo\b/, 'run-time exceptions propagated from the cage';

    eval {
        $perl->eval('die { foo => q[bar] }');
    };

    my $err = $@;
    is_deeply(
        $err,
        { foo => 'bar' },
        'structured expections work too',
    );
}

done_testing;
