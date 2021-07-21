import contextlib
import json
import os
import select
import socket
import sys
import threading
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
    ctypedef duk_ret_t (*duk_safe_call_function) (duk_context *ctx, void *udata)

    cdef duk_context* duk_create_heap(duk_alloc_function alloc_func, duk_realloc_function realloc_func, duk_free_function free_func, void *heap_udata, duk_fatal_function fatal_handler)
    cdef duk_context* duk_create_heap_default()
    cdef void duk_destroy_heap(duk_context *context)
    cdef duk_int_t duk_peval_string(duk_context *context, const char *source)
    cdef const char* duk_safe_to_string(duk_context *ctx, duk_idx_t index)
    cdef void duk_pop(duk_context *ctx)

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
    cdef void duk_push_heap_stash(duk_context *ctx)
    cdef void duk_dup(duk_context *ctx, duk_idx_t from_index)
    cdef duk_bool_t duk_has_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_bool_t duk_del_prop_index(duk_context *ctx, duk_idx_t obj_index, duk_uarridx_t arr_index)
    cdef duk_bool_t duk_is_callable(duk_context *ctx, duk_idx_t index)
    cdef void duk_push_pointer(duk_context *ctx, void *p)
    cdef void *duk_get_pointer(duk_context *ctx, duk_idx_t index)
    cdef duk_bool_t duk_is_pointer(duk_context *ctx, duk_idx_t index)
    cdef duk_int_t duk_safe_call(duk_context *ctx, duk_safe_call_function func, void *udata, duk_idx_t nargs, duk_idx_t nrets)
    cdef void duk_new(duk_context *ctx, duk_idx_t nargs)
    cdef duk_int_t duk_require_int(duk_context *ctx, duk_idx_t index)
    cdef void duk_swap(duk_context *ctx, duk_idx_t index1, duk_idx_t index2)
    cdef void duk_dump_context_stdout(duk_context *ctx)
    cdef void duk_set_finalizer(duk_context *ctx, duk_idx_t index)
    cdef void *duk_get_heapptr(duk_context *ctx, duk_idx_t index)
    cdef void duk_push_this(duk_context *ctx)
    cdef void duk_push_thread(duk_context *ctx)


cdef extern from 'vendor/duk_module_duktape.c':
    ctypedef struct duk_context:
        pass

    cdef void duk_module_duktape_init(duk_context *ctx)


class DuktapeError(Exception):
    pass


class DuktapeThreadError(DuktapeError):
    pass


class JSError(Exception):
    pass


cdef class DuktapeHeap(object):
    # index into the global js stash
    # when a js value is returned to python,
    # a reference is kept in the global stash
    # to avoid garbage collection
    cdef int next_ref_index

    # these keep python objects referenced only by js code alive
    cdef object registered_objects
    cdef object registered_proxies
    cdef object registered_proxies_reverse

    cdef duk_context *ctx

    def __cinit__(self):
        self.ctx = duk_create_heap_default()
        if self.ctx == NULL:
            raise DuktapeError('Can\'t allocate context')

        set_python_heap(self.ctx, self)

        self.next_ref_index = -1

        self.registered_objects = {}
        self.registered_proxies = {}
        self.registered_proxies_reverse = {}

    def __dealloc__(self):
        duk_destroy_heap(self.ctx)

    cdef new_jsref(self, duk_context *ctx, index):
        self.next_ref_index += 1
        assert duk_is_object(ctx, index)

        ref_index = self.next_ref_index

        duk_push_heap_stash(ctx)
        duk_dup(ctx, index - 1)
        duk_put_prop_index(ctx, -2, 2*ref_index)
        duk_push_thread(ctx)
        duk_put_prop_index(ctx, -2, 2*ref_index+1)
        duk_pop(ctx)

        return ref_index

    def delete_jsref(self, ref_index):
        duk_push_heap_stash(self.ctx)
        if not (duk_has_prop_index(self.ctx, -1, 2*ref_index)
                and duk_has_prop_index(self.ctx, -1, 2*ref_index+1)):
            duk_pop(self.ctx)
            raise DuktapeError('Trying to delete non-existent reference')
        duk_del_prop_index(self.ctx, -1, 2*ref_index)
        duk_del_prop_index(self.ctx, -1, 2*ref_index+1)
        duk_pop(self.ctx)

    cdef void register_object(self, void *proxy_ptr, object py_obj):
        self.registered_objects[<unsigned long>proxy_ptr] = py_obj

    cdef object get_registered_object(self, void *proxy_ptr):
        return self.registered_objects[<unsigned long>proxy_ptr]

    cdef int is_registered_object(self, void *proxy_ptr):
        return <unsigned long>proxy_ptr in self.registered_objects

    cdef void unregister_object(self, void *proxy_ptr):
        del self.registered_objects[<unsigned long>proxy_ptr]

    cdef void register_proxy(self, void *proxy_ptr, void *target_ptr, object py_obj):
        self.registered_proxies[<unsigned long>proxy_ptr] = <unsigned long>target_ptr
        self.registered_proxies_reverse[<unsigned long>target_ptr] = <unsigned long>proxy_ptr
        self.register_object(target_ptr, py_obj)

    cdef object get_registered_object_from_proxy(self, void *proxy_ptr):
        return self.registered_objects[self.registered_proxies[<unsigned long>proxy_ptr]]

    cdef int is_registered_proxy(self, void *proxy_ptr):
        if <unsigned long>proxy_ptr not in self.registered_proxies:
            return 0

        return self.registered_proxies[<unsigned long>proxy_ptr] in self.registered_objects

    cdef void unregister_proxy_from_target(self, void *target_ptr):
        proxy_ptr = self.registered_proxies_reverse.pop(<unsigned long>target_ptr)
        del self.registered_objects[<unsigned long>target_ptr]
        del self.registered_proxies[proxy_ptr]

cdef push_jsref(duk_context *ctx, ref_index):
    duk_push_heap_stash(ctx)
    if duk_get_prop_index(ctx, -1, 2*ref_index) == 0:
        duk_pop_2(ctx)
        raise DuktapeError('Invalid reference')
    duk_swap(ctx, -1, -2)
    duk_pop(ctx)


cdef class DuktapeContext(object):
    cdef duk_context *ctx
    cdef object js_base_path
    cdef DuktapeHeap py_heap

    def __init__(self):
        self.js_base_path = ''

        self.py_heap = DuktapeHeap()
        self.ctx = self.py_heap.ctx
>>>>>>> bpe/master

    def delete_jsref(self, ref_index):
        duk_push_heap_stash(self.ctx)
        if not (duk_has_prop_index(self.ctx, -1, 2*ref_index)
                and duk_has_prop_index(self.ctx, -1, 2*ref_index+1)):
            duk_pop(self.ctx)
            raise DuktapeError('Trying to delete non-existent reference')
        duk_del_prop_index(self.ctx, -1, 2*ref_index)
        duk_del_prop_index(self.ctx, -1, 2*ref_index+1)
        duk_pop(self.ctx)

    cdef void register_object(self, void *proxy_ptr, object py_obj):
        self.registered_objects[<unsigned long>proxy_ptr] = py_obj

    cdef object get_registered_object(self, void *proxy_ptr):
        return self.registered_objects[<unsigned long>proxy_ptr]

    cdef int is_registered_object(self, void *proxy_ptr):
        return <unsigned long>proxy_ptr in self.registered_objects

    cdef void unregister_object(self, void *proxy_ptr):
        del self.registered_objects[<unsigned long>proxy_ptr]

    cdef void register_proxy(self, void *proxy_ptr, void *target_ptr, object py_obj):
        self.registered_proxies[<unsigned long>proxy_ptr] = <unsigned long>target_ptr
        self.registered_proxies_reverse[<unsigned long>target_ptr] = <unsigned long>proxy_ptr
        self.register_object(target_ptr, py_obj)

    cdef object get_registered_object_from_proxy(self, void *proxy_ptr):
        return self.registered_objects[self.registered_proxies[<unsigned long>proxy_ptr]]

    cdef int is_registered_proxy(self, void *proxy_ptr):
        if <unsigned long>proxy_ptr not in self.registered_proxies:
            return 0

        return self.registered_proxies[<unsigned long>proxy_ptr] in self.registered_objects

    cdef void unregister_proxy_from_target(self, void *target_ptr):
        proxy_ptr = self.registered_proxies_reverse.pop(<unsigned long>target_ptr)
        del self.registered_objects[<unsigned long>target_ptr]
        del self.registered_proxies[proxy_ptr]

cdef push_jsref(duk_context *ctx, ref_index):
    duk_push_heap_stash(ctx)
    if duk_get_prop_index(ctx, -1, 2*ref_index) == 0:
        duk_pop_2(ctx)
        raise DuktapeError('Invalid reference')
    duk_swap(ctx, -1, -2)
    duk_pop(ctx)


cdef class DuktapeContext(object):
    cdef duk_context *ctx
    cdef object js_base_path
    cdef DuktapeHeap py_heap

    def __init__(self):
        self.js_base_path = ''

        self.py_heap = DuktapeHeap()
        self.ctx = self.py_heap.ctx

        duk_module_duktape_init(self.ctx)
        self._setup_module_search_function()

    cdef void _setup_module_search_function(self):
        self.get_global('Duktape').modSearch = self.module_search

    def module_search(self, module_id, require, exports, module):
        with open(self.get_file_path(module_id)) as module:
            return module.read()

    def set_globals(self, **kwargs):
        for name, value in kwargs.iteritems():
            self._set_global(name.encode('utf-8'), value)

    cdef void _set_global(self, const char *name, object value) except *:
        to_js(self.ctx, value)
        duk_put_global_string(self.ctx, name)

    def get_global(self, name):
        if not isinstance(name, basestring):
            raise TypeError('Global variable name must be a string, {} found'.format(type(name)))

        duk_get_global_string(self.ctx, name.encode('utf-8'))
        try:
            value = to_python(self.ctx, -1)
        finally:
            duk_pop(self.ctx)

        return value

    def set_base_path(self, path):
        if not isinstance(path, basestring):
            raise TypeError('Path must be a string, {} found'.format(type(path)))

        self.js_base_path = path

    def eval_js(self, src):
        if not isinstance(src, basestring):
            raise TypeError('Javascript source must be a string')

        def eval_string():
            return duk_peval_string(self.ctx, src.encode('utf-8'))

        return self._eval_js(eval_string)

    def eval_js_file(self, src_path):
        with open(self.get_file_path(src_path), 'r', encoding='utf-8') as f:
            code = f.read()

        return self.eval_js(code)

    def get_file_path(self, src_path):
        if not isinstance(src_path, basestring):
            raise TypeError('Javascript source path must be a string')

        if not src_path.endswith('.js'):
            src_path = '{}.js'.format(src_path)

        if not os.path.isabs(src_path):
            src_path = os.path.join(self.js_base_path, src_path)

        return src_path

    def _eval_js(self, eval_function):

        if eval_function() != 0:
            error = get_error(self.ctx)
            result = None
        else:
            error = None
            result = to_python(self.ctx, -1)
        duk_pop(self.ctx)

        if error:
            raise JSError(error)

        return result


cdef void set_python_heap(duk_context *ctx, DuktapeHeap py_heap):
    duk_push_heap_stash(ctx)
    duk_push_pointer(ctx, <void*>py_heap)
    duk_put_prop_string(ctx, -2, '__py_heap')
    duk_pop(ctx)


cdef DuktapeHeap get_python_heap(duk_context *ctx):
    duk_push_heap_stash(ctx)
    duk_get_prop_string(ctx, -1, '__py_heap')
    py_heap_ptr = duk_get_pointer(ctx, -1)
    py_heap = <DuktapeHeap>py_heap_ptr
    duk_pop_2(ctx)

    return py_heap


cdef object get_error(duk_context *ctx):
    error = to_python(ctx, -1) 
    return error


cdef class JSProxy(object):
    cdef duk_context *ctx
    cdef int ref_index
    cdef JSProxy __bind_proxy

    def __init__(self, ref_index, bind_proxy):
        self.ref_index = ref_index
        self.__bind_proxy = bind_proxy

    def __dealloc__(self):
        py_heap = get_python_heap(self.ctx)
        py_heap.delete_jsref(self.ref_index)

    def __setattr__(self, name, value):
        ctx = self.ctx

        to_js(ctx, self)
        to_js(ctx, value)
        duk_put_prop_string(ctx, -2, name.encode('utf-8'))
        duk_pop(ctx)

    def __getattr__(self, name):
        ctx = self.ctx

        to_js(ctx, self)
        if not duk_get_prop_string(ctx, -1, name.encode('utf-8')):
            duk_pop_2(ctx)
            raise AttributeError('Attribute {} missing'.format(name))

        try:
            res = to_python(ctx, -1, self)
        finally:
            duk_pop_2(ctx)

        return res

    def __getitem__(self, name):
        if not isinstance(name, (int, long, basestring)):
            raise TypeError('{} is not a valid index'.format(name))

        return getattr(self, unicode(name))

    def __repr__(self):
        ctx = self.ctx

        to_js(ctx, self)
        res = duk_safe_to_string(ctx, -1)
        duk_pop(ctx)

        return '<JSProxy: {}, bind_proxy={}>'.format(res, self.__bind_proxy.__repr__())

    def __call__(self, *args):
        if self.__bind_proxy is None:
            return self.__call(duk_pcall, args, None)
        else:
            return self.__call(duk_pcall_method, args, self.__bind_proxy)

    def new(self, *args):
        return self.__call(safe_new, args, None)

    cdef __call(self, duk_ret_t (*call_type)(duk_context *, duk_idx_t), args, this):
        ctx = self.ctx

        to_js(ctx, self)

        if not duk_is_callable(ctx, -1):
            duk_pop(ctx)
            raise TypeError('Can\'t call')

        if this is not None:
            to_js(ctx, this)

        for arg in args:
            to_js(ctx, arg)

        if call_type(ctx, len(args)) == 0:
            res, error = to_python(ctx, -1), None
        else:
            res, error = None, get_error(ctx)

        duk_pop(ctx)

        if error is not None:
            raise JSError(error)

        return res

    def __nonzero__(self):
        return getattr(self, 'length', 1) > 0

    def __len__(self):
        return self.length

    def __iter__(self):
        ctx = self.ctx

        to_js(ctx, self)
        is_array = duk_is_array(ctx, -1)
        is_object = duk_is_object(ctx, -1)

        if is_array:
            duk_pop(ctx)
            for i in xrange(0, self.length):
                yield self[i]
        elif is_object:
            duk_enum(ctx, -1, DUK_ENUM_OWN_PROPERTIES_ONLY)

            keys = []
            while duk_next(ctx, -1, 0) != 0:
                keys.append(get_python_string(ctx, -1))
                duk_pop(ctx)
            duk_pop_2(ctx) # pop enumerator and self

            for key in keys:
                yield key


cdef duk_ret_t call_new(duk_context *ctx, void *udata):
    # [ constructor arg1 arg2 ... argn nargs ]
    nargs = duk_require_int(ctx, -1)
    duk_pop(ctx)
    duk_new(ctx, nargs)
    duk_push_undefined(ctx) # replace the popped argument
    duk_swap(ctx, -1 , -2)

    return 1


cdef duk_int_t safe_new(duk_context *ctx, int nargs):
    # [ constructor arg1 arg2 ... argn nargs ]
    duk_push_int(ctx, nargs)
    return duk_safe_call(ctx, call_new, NULL, nargs + 2, 1)



cdef object to_python(duk_context *ctx, duk_idx_t index, JSProxy bind_proxy=None):
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
        return get_python_string(ctx, index)

    if type_ == DUK_TYPE_OBJECT:
        py_heap = get_python_heap(ctx)
        value_ptr = duk_get_heapptr(ctx, index)
        if py_heap.is_registered_proxy(value_ptr):
            return py_heap.get_registered_object_from_proxy(value_ptr)
        else:
            ref_index = py_heap.new_jsref(ctx, index)
            value = JSProxy(ref_index, bind_proxy) 
            (<JSProxy>value).ctx = ctx
            return value
    assert False


cdef object get_python_string(duk_context *ctx, duk_idx_t index):
    return duk_get_string(ctx, index).decode('utf-8')


cdef void to_js(duk_context *ctx, object value) except *:
    if value is None:
        duk_push_undefined(ctx)
        return

    if value is False or value is True:
        duk_push_boolean(ctx, int(value))
        return

    if isinstance(value, (int, long)):
        max_positive_js_int = 1 << 53
        min_negative_js_int = -(1 << 53) - 1

        if value >= min_negative_js_int and value <= max_positive_js_int:
            duk_push_number(ctx, float(value))
        else:
            raise OverflowError('Cannot convert {}, number out of range'.format(value))
        return

    if isinstance(value, float):
        duk_push_number(ctx, value)
        return

    if isinstance(value, basestring):
        duk_push_string(ctx, value.encode('utf-8'))
        return

    if isinstance(value, JSProxy):
        ref_index = (<JSProxy>value).ref_index
        push_jsref(ctx, ref_index)
        return

    if callable(value):
        push_callback(ctx, value)
        return

    push_py_proxy(ctx, value)


cdef void push_py_proxy(duk_context *ctx, object obj) except *:
    py_heap = get_python_heap(ctx)

    duk_get_global_string(ctx, 'Proxy')

    duk_push_object(ctx) # proxy target
    duk_push_c_function(ctx, py_proxy_finalizer, 1)
    duk_set_finalizer(ctx, -2)
    target_ptr = duk_get_heapptr(ctx, -1)

    duk_push_object(ctx) # proxy options

    duk_push_c_function(ctx, py_proxy_get, 3)
    duk_put_prop_string(ctx, -2, 'get')

    duk_push_c_function(ctx, py_proxy_set, 4)
    duk_put_prop_string(ctx, -2, 'set')

    duk_push_c_function(ctx, py_proxy_has, 2)
    duk_put_prop_string(ctx, -2, 'has')

    if safe_new(ctx, 2) != 0:
        error = get_error(ctx)
        duk_pop(ctx)
        raise DuktapeError(error)

    proxy_ptr = duk_get_heapptr(ctx, -1)
    py_heap.register_proxy(proxy_ptr, target_ptr, obj)


cdef duk_ret_t py_proxy_finalizer(duk_context *ctx):
    py_heap = get_python_heap(ctx)

    target_ptr = duk_get_heapptr(ctx, -1)
    py_heap.unregister_proxy_from_target(target_ptr)

    return 0


cdef duk_ret_t py_proxy_get(duk_context *ctx):
    py_heap = get_python_heap(ctx)
    n_args = duk_get_top(ctx)

    try:
        target = py_heap.get_registered_object(duk_get_heapptr(ctx, 0 - n_args))
        key = to_python(ctx, 1 - n_args)
        value = None

        if isinstance(target, (list, tuple)):
            if key == 'length':
                # special attribute
                value = len(target)
            else:
                # key is always a string,
                # but we need ints to index list and tuples
                try:
                    key = int(key)
                except (TypeError, ValueError):
                    pass

        if value is None:
            try:
                value = target[key]
            except (TypeError, IndexError, KeyError):
                if isinstance(key, basestring):
                    value = getattr(target, key, None)

        to_js(ctx, value)
    except:
        throw_python_exception(ctx)

    return 1


cdef duk_ret_t py_proxy_has(duk_context *ctx):
    py_heap = get_python_heap(ctx)
    n_args = duk_get_top(ctx)

    try:
        target = py_heap.get_registered_object(duk_get_heapptr(ctx, 0 - n_args))
        key = to_python(ctx, 1 - n_args)

        if isinstance(target, (list, tuple)):
            try:
                key = int(key)
            except (TypeError, ValueError):
                pass

        try:
            target[key]
            res = True
        except (KeyError, IndexError):
            res = False
        except TypeError:
            res = hasattr(target, key)

        to_js(ctx, res)
    except:
        throw_python_exception(ctx)

    return 1


cdef duk_ret_t py_proxy_set(duk_context *ctx):
    py_heap = get_python_heap(ctx)
    n_args = duk_get_top(ctx)

    try:
        target = py_heap.get_registered_object(duk_get_heapptr(ctx, 0 - n_args))
        key = to_python(ctx, 1 - n_args)
        value = to_python(ctx, 2 - n_args)

        if isinstance(target, (list, tuple)):
            try:
                key = int(key)
            except (TypeError, ValueError):
                pass

        try:
            target[key] = value
        except TypeError:
            setattr(target, key, value)
    except:
        throw_python_exception(ctx)

    duk_push_boolean(ctx, 1)

    return 1


cdef duk_ret_t callback_finalizer(duk_context *ctx):
    py_heap = get_python_heap(ctx)
    target_ptr = duk_get_heapptr(ctx, -1)
    py_heap.unregister_object(target_ptr)

    return 0


cdef void push_callback(duk_context *ctx, object fn) except *:
    assert callable(fn)

    py_heap = get_python_heap(ctx)

    duk_push_c_function(ctx, callback, DUK_VARARGS)

    duk_push_c_function(ctx, callback_finalizer, 1)
    duk_set_finalizer(ctx, -2)

    py_heap.register_object(duk_get_heapptr(ctx, -1), fn)


cdef duk_ret_t callback(duk_context *ctx):
    if duk_is_constructor_call(ctx):
        duk_error(ctx, DUK_ERR_ERROR, 'can\'t use new on python objects')

    py_heap = get_python_heap(ctx)

    n_args = duk_get_top(ctx)

    try:
        args = []
        for i in xrange(0, n_args):
            args.append(to_python(ctx, i - n_args))

        duk_push_current_function(ctx)
        python_callback = py_heap.get_registered_object(duk_get_heapptr(ctx, -1))
        duk_pop(ctx)

        res = python_callback(*args)

        to_js(ctx, res)
    except:
        throw_python_exception(ctx)

    return 1

cdef throw_python_exception(duk_context *ctx):
    error = traceback.format_exc()
    error_bytes = error.encode('utf-8')
    cdef char *error_str = error_bytes
    duk_error(ctx, DUK_ERR_ERROR, "%s", error_str)

