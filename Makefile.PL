use strict;
use inc::Module::Install;
use ExtUtils::Depends;

all_from 'lib/Eval/Clean.pm';

my $deps = ExtUtils::Depends->new('Eval::Clean', 'XS::Object::Magic');
makemaker_args($deps->get_makefile_vars);

WriteAll;
