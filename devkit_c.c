
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/unixsupport.h>
#include <caml/signals.h>
#include <caml/alloc.h>
#include <assert.h>
#include <malloc.h>
#include <memory.h>

#if defined(_MSC_VER)

CAMLprim value caml_devkit_fsync(value v)
{
   CAMLparam1(v);
   HANDLE h = INVALID_HANDLE_VALUE;
   int r = 0;
   if (KIND_HANDLE != Descr_kind_val(v))
     caml_invalid_argument("fsync");
   h = Handle_val(v);
   caml_enter_blocking_section();
   r = FlushFileBuffers(h);
   caml_leave_blocking_section();
   if (0 == r)
     uerror("fsync",Nothing);
   CAMLreturn(Val_unit); 
}

#else

#include <unistd.h>

CAMLprim value caml_devkit_fsync(value v_fd)
{
    CAMLparam1(v_fd);
    int r = 0;
    assert(Is_long(v_fd));
    caml_enter_blocking_section();
    r = fsync(Int_val(v_fd));
    caml_leave_blocking_section();
    if (0 != r)
      uerror("fsync",Nothing);
    CAMLreturn(Val_unit);
}

CAMLprim value caml_devkit_mallinfo(value u)
{
  CAMLparam1(u);
  CAMLlocal1(v);
  struct mallinfo mi = mallinfo();

  v = caml_alloc(10,0);
  Store_field(v,0,mi.arena);
  Store_field(v,1,mi.ordblks);
  Store_field(v,2,mi.smblks);
  Store_field(v,3,mi.hblks);
  Store_field(v,4,mi.hblkhd);
  Store_field(v,5,mi.usmblks);
  Store_field(v,6,mi.fsmblks);
  Store_field(v,7,mi.uordblks);
  Store_field(v,8,mi.fordblks);
  Store_field(v,9,mi.keepcost);

  CAMLreturn(v);
}

CAMLprim value caml_malloc_stats(value v_unit)
{
  malloc_stats();
  return Val_unit;
}

CAMLprim value caml_malloc_info(value v_unit)
{
  CAMLparam0();
  CAMLlocal1(v_s);
  char* buf = NULL;
  size_t size;
  int r;
  FILE* f = open_memstream(&buf,&size);
  if (NULL == f)
    uerror("malloc_info", Nothing);
  r = malloc_info(0,f);
  fclose(f);
  if (0 != r)
  {
    free(buf);
    uerror("malloc_info", Nothing);
  }
  v_s = caml_alloc_string(size);
  memcpy(Bp_val(v_s), buf, size);
  free(buf);
  CAMLreturn(v_s);
}

#endif

