#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"

#include "xs_object_magic.h"

#define SET_PERL(perl)  PERL_SET_CONTEXT(perl);
#define GET_PERL        PERL_GET_CONTEXT

char *default_args[] =  { "a_perl", "-e", "0" };

static void xs_init (pTHX);

EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);

EXTERN_C void xs_init(pTHX) {
  char *file = __FILE__;
  /* DynaLoader is a special case */
  newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}

static PerlInterpreter *
new_perl (void)
{
    PerlInterpreter *perl, *prev = GET_PERL;

    perl = perl_alloc();

    SET_PERL(perl);
    perl_construct(perl);
    perl_parse(perl, xs_init, (sizeof(default_args) / sizeof(default_args[0])),
               default_args, (char **)NULL);
    SET_PERL(prev);

    return perl;
}

static void
free_perl (PerlInterpreter *perl)
{
    perl_destruct(perl);
    perl_free(perl);
}

static SV *
eval (PerlInterpreter *perl, const char *code)
{
    PerlInterpreter *prev = GET_PERL;
    SV *ret, *cloned;
    int xcpt = 0;

    SET_PERL(perl);
    ret = eval_pv(code, FALSE);

    if (SvTRUE(ERRSV)) {
        xcpt = 1;
        ret = ERRSV;
    }

    SET_PERL(prev);

#if (PERL_VERSION < 13) || (PERL_VERSION == 13 && PERL_SUBVERSION <= 1)
    {
        CLONE_PARAMS clone_params;

        clone_params.stashes = newAV();
        clone_params.flags = CLONEf_JOIN_IN;
        PL_ptr_table = ptr_table_new();
        ptr_table_store(PL_ptr_table, &perl->Isv_undef, &PL_sv_undef);
        ptr_table_store(PL_ptr_table, &perl->Isv_no, &PL_sv_no);
        ptr_table_store(PL_ptr_table, &perl->Isv_yes, &PL_sv_yes);
        cloned = sv_dup(ret, &clone_params);
        SvREFCNT_dec(clone_params.stashes);
        SvREFCNT_inc_void(cloned);
        ptr_table_free(PL_ptr_table);
        PL_ptr_table = NULL;
    }
#else
    {
        CLONE_PARAMS *clone_params = Perl_clone_params_new(perl, aTHX);

        clone_params->flags |= CLONEf_JOIN_IN;
        PL_ptr_table = ptr_table_new();
        ptr_table_store(PL_ptr_table, &perl->Isv_undef, &PL_sv_undef);
        ptr_table_store(PL_ptr_table, &perl->Isv_no, &PL_sv_no);
        ptr_table_store(PL_ptr_table, &perl->Isv_yes, &PL_sv_yes);
        cloned = sv_dup(ret, clone_params);
        Perl_clone_params_del(clone_params);
        SvREFCNT_inc_void(cloned);
        ptr_table_free(PL_ptr_table);
        PL_ptr_table = NULL;
    }
#endif

    if (xcpt) {
#ifdef croak_sv
        croak_sv(cloned);
#else
        ERRSV = cloned;
        croak(NULL);
#endif
    }

    return cloned;
}

MODULE = Eval::Clean   PACKAGE = Eval::Clean

PROTOTYPES: DISABLE

PerlInterpreter *
new_perl ()

MODULE = Eval::Clean   PACKAGE = Eval::Clean::Perl

PROTOTYPES: DISABLE

SV *
eval (perl, code)
        PerlInterpreter *perl
        const char *code
    CODE:
        /* doesn't work. exception gets thrown in the other perl */
        RETVAL = eval(perl, code);
    OUTPUT:
        RETVAL

void
DESTROY (perl)
        PerlInterpreter *perl
    CODE:
        free_perl(perl);
