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

    PL_perl_destruct_level = 1;
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
    PL_perl_destruct_level = 1;
    perl_destruct(perl);
    perl_free(perl);
}

static SV *
eval (PerlInterpreter *perl, const char *code)
{
    PerlInterpreter *prev = GET_PERL;
    SV *ret, *cloned;
    CLONE_PARAMS clone_params;

    SET_PERL(perl);
    ret = eval_pv(code, TRUE);
    SET_PERL(prev);

    clone_params.flags = 0;
    clone_params.unreferenced = newAV();
    PL_ptr_table = ptr_table_new();

    cloned = SvREFCNT_inc(sv_dup(ret, &clone_params));

    SvREFCNT_dec(clone_params.unreferenced);
    ptr_table_free(PL_ptr_table);
    PL_ptr_table = NULL;

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
    PREINIT:
        dXCPT;
        PerlInterpreter *prev = GET_PERL;
    CODE:
        /* doesn't work. exception gets thrown in the other perl */
        XCPT_TRY_START {
            RETVAL = eval(perl, code);
        } XCPT_TRY_END

        XCPT_CATCH {
            SET_PERL(prev);
        }
    OUTPUT:
        RETVAL

void
DESTROY (perl)
        PerlInterpreter *perl
    CODE:
        free_perl(perl);
