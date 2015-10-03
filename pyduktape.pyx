import json
import select
import socket
import sys
import traceback


DUK_TYPE_NONE = 0
DUK_TYPE_UNDEFINED = 1
DUK_TYPE_NULL = 2
DUK_TYPE_BOOLEAN = 3
DUK_TYPE_NUMBER = 4
DUK_TYPE_STRING = 5
DUK_TYPE_OBJECT = 6
DUK_TYPE_BUFFER = 7
DUK_TYPE_POINTER = 8
DUK_TYPE_LIGHTFUNC = 9

DUK_ENUM_OWN_PROPERTIES_ONLY = (1 << 2)

DUK_VARARGS = -1

DUK_ERR_ERROR = 100

cdef extern from 'vendor/duktape.c':
    ctypedef struct duk_context:
        pass

    ctypedef int duk_errcode_t
    ctypedef int duk_int_t
    ctypedef size_t duk_size_t
    ctypedef duk_int_t duk_idx_t
    ctypedef int duk_bool_t
    ctypedef unsigned int duk_uint_t
    ctypedef unsigned int duk_uarridx_t
    ctypedef double duk_double_t
    ctypedef int duk_ret_t

    ctypedef void* (*duk_alloc_function) (void *udata, duk_size_t size)
    ctypedef void* (*duk_realloc_function) (void *udata, void *ptr, duk_size_t size)
    ctypedef void (*duk_free_function) (void *udata, void *ptr)
    ctypedef void (*duk_fatal_function) (duk_context *ctx, duk_errcode_t code, const char *msg)
    ctypedef duk_ret_t (*duk_c_function)(duk_context *ctx)
    ctypedef duk_ret_t (*duk_safe_call_function) (duk_context *ctx)

    ctypedef duk_size_t (*duk_debug_read_function) (void *udata, char *buffer, duk_size_t length)
    ctypedef duk_size_t (*duk_debug_write_function) (void *udata, const char *buffer, duk_size_t length)
    ctypedef duk_size_t (*duk_debug_peek_function) (void *udata)
    ctypedef void (*duk_debug_read_flush_function) (void *udata)
    ctypedef void (*duk_debug_write_flush_function) (void *udata)
    ctypedef void (*duk_debug_detached_function) (void *udata)

    cdef duk_context* duk_create_heap(duk_alloc_function alloc_func, duk_realloc_function realloc_func, duk_free_function free_func, void *heap_udata, duk_fatal_function fatal_handler)
    cdef duk_context* duk_create_heap_default()
    cdef void duk_destroy_heap(duk_context *context)
    cdef duk_int_t duk_peval_string(duk_context *context, const char *source)
    cdef const char* duk_safe_to_string(duk_context *ctx, duk_idx_t index)
    void duk_pop(duk_context *ctx)

    cdef duk_bool_t duk_get_boolean(duk_context *ctx, duk_idx_t index)
    cdef const char* duk_get_string(duk_context *ctx, duk_idx_t index)
    cdef double duk_get_number(duk_context *ctx, duk_idx_t index)
    cdef int duk_get_type(duk_context *ctx, duk_idx_t index)
    cdef void duk_enum(duk_context *ctx, duk_idx_t obj_index, duk_uint_t enum_flags)
    cdef duk_bool_t duk_next(duk_context *ctx, duk_idx_t enum_index, duk_bool_t get_value)
    cdef duk_bool_t duk_get_prop_string(duk_context *ctx, duk_idx_t obj_index, const char *key)
    cdef duk_bool_t duk_get_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_bool_t duk_is_array(duk_context *ctx, duk_idx_t index)
    cdef duk_int_t duk_get_int(duk_context *ctx, duk_idx_t index)
    cdef void duk_push_undefined(duk_context *ctx)
    cdef void duk_push_boolean(duk_context *ctx, duk_bool_t value)
    cdef duk_bool_t duk_put_prop(duk_context *ctx, duk_idx_t obj_index)
    cdef duk_idx_t duk_push_object(duk_context *ctx)
    cdef duk_bool_t duk_put_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_idx_t duk_push_array(duk_context *ctx)
    cdef const char *duk_push_string(duk_context *ctx, const char *str)
    cdef void duk_push_number(duk_context *ctx, duk_double_t val)
    cdef void duk_push_int(duk_context *ctx, duk_int_t val)
    cdef duk_bool_t duk_put_global_string(duk_context *ctx, const char *key)
    cdef duk_bool_t duk_get_global_string(duk_context *ctx, const char *key)
    cdef void duk_push_current_function(duk_context *ctx)
    cdef duk_idx_t duk_get_top(duk_context *ctx)
    cdef duk_bool_t duk_put_prop_string(duk_context *ctx, duk_idx_t obj_index, const char *key)
    cdef duk_idx_t duk_push_c_function(duk_context *ctx, duk_c_function func, duk_idx_t nargs)
    cdef duk_bool_t duk_is_constructor_call(duk_context *ctx)
    cdef void duk_pop_2(duk_context *ctx)
    cdef void duk_error(duk_context *ctx, duk_errcode_t err_code, const char *fmt, ...)
    cdef const char *duk_require_string(duk_context *ctx, duk_idx_t index)
    cdef duk_ret_t duk_pcall(duk_context *ctx, duk_idx_t nargs)
    cdef duk_int_t duk_pcall_method(duk_context *ctx, duk_idx_t nargs)
    cdef duk_bool_t duk_is_object(duk_context *ctx, duk_idx_t index)
    cdef void duk_push_global_stash(duk_context *ctx)
    cdef void duk_dup(duk_context *ctx, duk_idx_t from_index)
    cdef duk_bool_t duk_has_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_bool_t duk_del_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_bool_t duk_is_callable(duk_context *ctx, duk_idx_t index)
    cdef void duk_push_pointer(duk_context *ctx, void *p)
    cdef void *duk_get_pointer(duk_context *ctx, duk_idx_t index)
    cdef duk_int_t duk_safe_call(duk_context *ctx, duk_safe_call_function func, duk_idx_t nargs, duk_idx_t nrets)
    cdef void duk_new(duk_context *ctx, duk_idx_t nargs)
    cdef duk_int_t duk_require_int(duk_context *ctx, duk_idx_t index)
    cdef void duk_swap(duk_context *ctx, duk_idx_t index1, duk_idx_t index2)
    cdef void duk_dump_context_stdout(duk_context *ctx)
    cdef void duk_debugger_attach(duk_context *ctx,
                                  duk_debug_read_function read_cb,
                                  duk_debug_write_function write_cb,
                                  duk_debug_peek_function peek_cb,
                                  duk_debug_read_flush_function read_flush_cb,
                                  duk_debug_write_flush_function write_flush_cb,
                                  duk_debug_detached_function detached_cb,
                                  void *udata)


class DuktapeError(Exception):
    pass


cdef class DuktapeContext(object):
    cdef duk_context *ctx
    cdef int next_ref_index

    def __init__(self):
        self.next_ref_index = -1
        self.ctx = duk_create_heap_default()
        if self.ctx == NULL:
            raise DuktapeError('Can\'t allocate context')

        duk_get_global_string(self.ctx, 'Duktape')
        duk_push_c_function(self.ctx, module_search, 1)
        duk_put_prop_string(self.ctx, -2, 'modSearch')
        duk_pop(self.ctx)

        duk_push_global_stash(self.ctx)
        duk_push_pointer(self.ctx, <void*>self)
        duk_put_prop_string(self.ctx, -2, '__py_ctx')
        duk_pop(self.ctx)

    def set_globals(self, **kwargs):
        for name, value in kwargs.iteritems():
            set_global(self.ctx, name, value)

    def eval_js(self, src):
        if duk_peval_string(self.ctx, src) != 0:
            error = self.get_error()
            duk_pop(self.ctx)
            result = None
        else:
            error = None
            result = to_python(self, -1)
        duk_pop(self.ctx)

        if error:
            raise DuktapeError(error)

        return result

    def make_jsref(self, duk_idx_t index):
        assert duk_is_object(self.ctx, index)

        self.next_ref_index += 1

        # [... obj] -> [... obj stash obj] -> [... obj stash] -> [... obj]
        duk_push_global_stash(self.ctx)
        duk_dup(self.ctx, index - 1)
        duk_put_prop_index(self.ctx, -2, self.next_ref_index)
        duk_pop(self.ctx)

        return JSRef(self, self.next_ref_index)

    def __del__(self):
        duk_destroy_heap(self.ctx)

    def get_error(self):
        if duk_get_prop_string(self.ctx, -1, 'stack') == 0:
           return duk_safe_to_string(self.ctx, -2)
        else:
            return to_python(self, -1)


cdef class JSRef(object):
    cdef DuktapeContext py_ctx
    cdef int ref_index

    def __init__(self, DuktapeContext py_ctx, int ref_index):
        self.py_ctx = py_ctx
        self.ref_index = ref_index

    def to_js(self):
        duk_push_global_stash(self.py_ctx.ctx)
        if duk_get_prop_index(self.py_ctx.ctx, -1, self.ref_index) == 0:
            duk_pop_2(self.py_ctx.ctx)
            raise DuktapeError('Invalid reference')
        duk_swap(self.py_ctx.ctx, -1, -2)
        duk_pop(self.py_ctx.ctx)

    def __del__(self):
        duk_push_global_stash(self.py_ctx.ctx)
        if not duk_has_prop_index(self.py_ctx.ctx, -1, self.ref_index):
            duk_pop(self.py_ctx.ctx)
            raise DuktapeError('Trying to delete non-existent reference')

        duk_del_prop_index(self.py_ctx.ctx, -1, self.ref_index)
        duk_pop(self.py_ctx.ctx)


cdef class JSProxy(object):
    cdef JSRef __ref
    cdef JSProxy __bind_proxy

    def __init__(self, ref, bind_proxy):
        self.__ref = ref
        self.__bind_proxy = bind_proxy

    def __setattr__(self, name, value):
        ctx = self.__ref.py_ctx.ctx

        self.__ref.py_ctx.to_js()
        to_js(ctx, value)
        duk_put_prop_string(ctx, -2, name)
        duk_pop(ctx)

    def __getattr__(self, name):
        ctx = self.__ref.py_ctx.ctx

        self.__ref.to_js()
        if not duk_get_prop_string(ctx, -1, name):
            duk_pop_2(ctx)
            raise AttributeError('Attribute {} missing'.format(name))

        try:
            res = to_python(self.__ref.py_ctx, -1, self)
        finally:
            duk_pop_2(ctx)

        return res

    def __repr__(self):
        ctx = self.__ref.py_ctx.ctx

        self.__ref.to_js()
        res = duk_safe_to_string(ctx, -1)
        duk_pop(ctx)

        return '<JSProxy: {}, bind_proxy={}>'.format(res, self.__bind_proxy.__repr__())

    def __call__(self, *args):
        if self.__bind_proxy is None:
            return self.__call(duk_pcall, args, None)
        else:
            return self.__call(duk_pcall_method, args, self.__bind_proxy)

    def construct(self, *args):
        # TODO: not great...
        return self.__call(safe_new, args, None)

    cdef __call(self, duk_ret_t (*call_type)(duk_context *, duk_idx_t), args, this):
        ctx = self.__ref.py_ctx.ctx

        self.__ref.to_js()

        if not duk_is_callable(ctx, -1):
            duk_pop(ctx)
            raise TypeError('Can\'t call')

        if this is not None:
            to_js(ctx, this)

        for arg in args:
            to_js(ctx, arg)

        if call_type(ctx, len(args)) == 0:
            res, error = to_python(self.__ref.py_ctx, -1), None
        else:
            res, error = None, self.__ref.py_ctx.get_error()

        duk_pop(ctx)

        if error is not None:
            raise DuktapeError(error)

        return res

    def to_js(self):
        self.__ref.to_js()


cdef duk_ret_t call_new(duk_context *ctx):
    nargs = duk_require_int(ctx, -1)
    duk_pop(ctx)
    duk_new(ctx, nargs)

    return 1


cdef duk_ret_t safe_new(duk_context *ctx, int nargs):
    duk_push_int(ctx, nargs)
    return duk_safe_call(ctx, call_new, 1, 1)


cdef duk_ret_t module_search(duk_context *ctx):
    module_id = duk_require_string(ctx, -1)

    try:
        with open('{}.js'.format(module_id)) as module:
            source = module.read()
    except IOError:
        duk_error(ctx, DUK_ERR_ERROR, 'Could not load module: %s', module_id)

    duk_push_string(ctx, source)

    return 1


cdef object to_python(DuktapeContext py_ctx, duk_idx_t index, JSProxy bind_proxy=None):
    cdef duk_context *ctx = py_ctx.ctx

    type_ = duk_get_type(ctx, index)

    if type_ == DUK_TYPE_NONE:
        raise DuktapeError('Nothing to convert')

    if type_ == DUK_TYPE_BUFFER or type_ == DUK_TYPE_LIGHTFUNC or type_ == DUK_TYPE_POINTER:
        raise DuktapeError('Type cannot be converted')

    if type_ == DUK_TYPE_NULL or type_ == DUK_TYPE_UNDEFINED:
        return None

    if type_ == DUK_TYPE_BOOLEAN:
        return bool(duk_get_boolean(ctx, index))

    if type_ == DUK_TYPE_NUMBER:
        value = float(duk_get_number(ctx, index))
        if value.is_integer():
            return int(value)
        else:
            return value

    if type_ == DUK_TYPE_STRING:
        return unicode(duk_get_string(ctx, index))

    if type_ == DUK_TYPE_OBJECT:
        return JSProxy(py_ctx.make_jsref(index), bind_proxy)

    # if duk_is_array(ctx, index):
    #     if duk_get_prop_string(ctx, index, 'length') == 0:
    #         duk_pop(ctx)
    #         return []

    #     length = duk_get_int(ctx, -1)
    #     duk_pop(ctx)

    #     res = [None] * length
    #     for i in xrange(0, length):
    #         duk_get_prop_index(ctx, index, i)
    #         res[i] = to_python(ctx, -1)
    #         duk_pop(ctx)

    #     return res

    # if type_ == DUK_TYPE_OBJECT:
    #     res = dict()

    #     duk_enum(ctx, index, DUK_ENUM_OWN_PROPERTIES_ONLY)

    #     while duk_next(ctx, -1, 1) != 0:
    #         key = unicode(duk_get_string(ctx, -2))
    #         value = to_python(ctx, -1)
    #         duk_pop(ctx)
    #         duk_pop(ctx)

    #         res[key] = value

    #     duk_pop(ctx)

    #   return res

    assert False


cdef void set_global(duk_context *ctx, const char *name, object value) except *:
    to_js(ctx, value)
    duk_put_global_string(ctx, name)


cdef void to_js(duk_context *ctx, object value) except *:
    # TODO: this doesn't handle recurring objects correctly!
    # it will break when the structure has cycles

    if value is None:
        duk_push_undefined(ctx)
        return

    if value is False or value is True:
        duk_push_boolean(ctx, int(value))
        return

    if isinstance(value, (int, long)):
        if value >= -sys.maxint - 1 and value <= sys.maxint:
            duk_push_int(ctx, value)
        elif value >= (-(2 << 53) - 1) and value <= (2 << 53):
            duk_push_number(ctx, float(value))
        else:
            raise DuktapeError('Cannot convert {}, number out of range'.format(value))
        return

    if isinstance(value, float):
        duk_push_number(ctx, value)
        return

    if isinstance(value, basestring):
        duk_push_string(ctx, value)
        return

    if isinstance(value, (list, tuple)):
        arr_idx = duk_push_array(ctx)
        for i, item in enumerate(value):
            to_js(ctx, item)
            duk_put_prop_index(ctx, arr_idx, i)
        return

    if isinstance(value, dict):
        obj_idx = duk_push_object(ctx)
        for key, value in value.iteritems():
            if not isinstance(key, basestring):
                raise DuktapeError('Only strings are supported as dict keys, found {}'.format(key))
            to_js(ctx, key)
            to_js(ctx, value)
            duk_put_prop(ctx, obj_idx)
        return

    if isinstance(value, JSProxy):
        # assert that context is the same?
        value.to_js()
        return

    if callable(value):
        push_callback(ctx, value)
        return

    raise DuktapeError('Don\'t know how to convert {}'.format(value))


callbacks = [] # this keeps all functions alive


cdef void push_callback(duk_context *ctx, object fn) except *:
    assert callable(fn)

    callbacks.append(fn)
    python_callback_id = len(callbacks) - 1

    duk_push_c_function(ctx, callback, DUK_VARARGS)
    duk_push_int(ctx, python_callback_id)
    duk_put_prop_string(ctx, -2, 'python_callback_id')


cdef duk_ret_t callback(duk_context *ctx):
    assert not duk_is_constructor_call(ctx)

    duk_push_global_stash(ctx)
    duk_get_prop_string(ctx, -1, '__py_ctx')
    py_ctx = <DuktapeContext>duk_get_pointer(ctx, -1)
    assert py_ctx.ctx is ctx
    duk_pop_2(ctx)

    n_args = duk_get_top(ctx)
    args = []
    for i in xrange(0, n_args):
        args.append(to_python(py_ctx, i - n_args))

    duk_push_current_function(ctx)
    duk_get_prop_string(ctx, -1, 'python_callback_id')
    python_callback_id = duk_get_int(ctx, -1)
    duk_pop_2(ctx)

    try:
        res = callbacks[python_callback_id](*args)
    except:
        error = traceback.format_exc()
        error = error.replace('%', '%%')
        duk_error(ctx, DUK_ERR_ERROR, error)

    to_js(ctx, res)

    return 1
