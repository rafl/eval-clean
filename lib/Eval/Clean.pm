package Eval::Clean;
# ABSTRACT: run code in a pristine perl interpreter and inspect the results in another
use strict;
use warnings;
use XSLoader;
use XS::Object::Magic;

XSLoader::load(
    __PACKAGE__,
    # we need to be careful not to touch $VERSION at compile time, otherwise
    # DynaLoader will assume it's set and check against it, which will cause
    # fail when being run in the checkout without dzil having set the actual
    # $VERSION
    exists $Eval::clean::{VERSION} ? ${ $Eval::clean::{VERSION} } : (),
);

1;
