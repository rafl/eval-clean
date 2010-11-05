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
    PerlInterpreter *prev = GET_PERL;

    SET_PERL(perl);
    perl_destruct(perl);
    perl_free(perl);
    SET_PERL(prev);
}

static SV *
clone_scalar (SV *sv, PerlInterpreter *from, PerlInterpreter *to)
{
    SV *ret;
    PerlInterpreter *prev = GET_PERL;

    /* Some closures can reference the main program as their OUTSIDE. Cloning
     * that doesn't quite do what we'd want it to. Therefore we just fiddle its
     * bits until things won't fail anymore during normal garbage collection on
     * LEAVE. This probably leaks tho. The proper fix for this is probably to
     * remove the cloning main_root limitations from the core. */
    if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVCV) {
        CV *outside = CvOUTSIDE(SvRV(sv));

        if (outside && SvTEMP(outside) && CvUNIQUE(outside) && !SvFAKE(outside))
            SvTEMP_off(outside);
    }

    SET_PERL(to);

#if (PERL_VERSION < 13) || (PERL_VERSION == 13 && PERL_SUBVERSION <= 1)
    {
        CLONE_PARAMS clone_params;

        clone_params.stashes = newAV();
        clone_params.flags = CLONEf_JOIN_IN;
        PL_ptr_table = ptr_table_new();
        ptr_table_store(PL_ptr_table, &from->Isv_undef, &PL_sv_undef);
        ptr_table_store(PL_ptr_table, &from->Isv_no, &PL_sv_no);
        ptr_table_store(PL_ptr_table, &from->Isv_yes, &PL_sv_yes);
        ret = sv_dup(sv, &clone_params);
        SvREFCNT_dec(clone_params.stashes);
        SvREFCNT_inc_void(ret);
        ptr_table_free(PL_ptr_table);
        PL_ptr_table = NULL;
    }
#else
    {
        CLONE_PARAMS *clone_params = Perl_clone_params_new(perl, aTHX);

        clone_params->flags |= CLONEf_JOIN_IN;
        PL_ptr_table = ptr_table_new();
        ptr_table_store(PL_ptr_table, &from->Isv_undef, &PL_sv_undef);
        ptr_table_store(PL_ptr_table, &from->Isv_no, &PL_sv_no);
        ptr_table_store(PL_ptr_table, &from->Isv_yes, &PL_sv_yes);
        ret = sv_dup(sv, clone_params);
        Perl_clone_params_del(clone_params);
        SvREFCNT_inc_void(ret);
        ptr_table_free(PL_ptr_table);
        PL_ptr_table = NULL;
    }
#endif

    SET_PERL(prev);

    return ret;
}

static SV *
eval (PerlInterpreter *perl, const char *code)
{
    PerlInterpreter *prev = GET_PERL;
    SV *ret;

    SET_PERL(perl);
    ret = eval_pv(code, FALSE);
    SET_PERL(prev);

#define ERRSVp(p) (GvSVn(p->Ierrgv))

    if (SvTRUE(ERRSVp(perl))) {
        SV *err = clone_scalar(ERRSVp(perl), perl, prev);
#ifdef croak_sv
        croak_sv(err);
#else
        ERRSV = err;
        croak(NULL);
#endif
    }

#undef ERRSVp

    return clone_scalar(ret, perl, prev);
}

MODULE = Eval::Clean   PACKAGE = Eval::Clean

PROTOTYPES: DISABLE

PerlInterpreter *
new (class)
    CODE:
        RETVAL = new_perl();
    OUTPUT:
        RETVAL

MODULE = Eval::Clean   PACKAGE = Eval::Clean::Perl

PROTOTYPES: DISABLE

SV *
eval (perl, code)
        PerlInterpreter *perl
        const char *code
    CODE:
        RETVAL = eval(perl, code);
    OUTPUT:
        RETVAL

void
DESTROY (perl)
        PerlInterpreter *perl
    CODE:
        free_perl(perl);
