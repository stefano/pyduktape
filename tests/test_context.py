import os
from threading import Thread, Lock

from tests import TestCase
from pyduktape import DuktapeContext, JSError, JSProxy, DuktapeThreadError


class TestContext(TestCase):
    def test_eval_simple_expression(self):
        ctx = DuktapeContext()

        res = ctx.eval_js('1 + 1')

        self.assertEqual(res, 2)

    def test_one_context_per_thread(self):
        ok = [True]
        ok_lock = Lock()
        def run():
            ctx = DuktapeContext()
            res = ctx.eval_js('1 + 1')
            with ok_lock:
                ok[0] = ok[0] and (res == 2)

        threads = [Thread(target=run) for i in range(0, 100)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()

        self.assertTrue(ok[0])

    def test_cant_call_from_different_thread(self):
        ctx = DuktapeContext()
        proxy = ctx.eval_js('[1, 2]')

        ok = [False]

        def run():
            try:
                proxy[0]
            except DuktapeThreadError:
                ok[0] = True

        thread = Thread(target=run)
        thread.start()
        thread.join()

        self.assertTrue(ok[0])

    def test_raise_js_error(self):
        ctx = DuktapeContext()

        with self.assertRaises(JSError):
            ctx.eval_js('throw new Error("error")')

    def test_raise_python_error_from_js(self):
        ctx = DuktapeContext()

        def f():
            raise Exception()

        ctx.set_globals(f=f)

        with self.assertRaises(JSError):
            ctx.eval_js('f()')

    def test_invalid_js_syntax(self):
        ctx = DuktapeContext()

        with self.assertRaises(JSError):
            ctx.eval_js('bad syntax')


class TestExternalFiles(TestCase):
    def setUp(self):
        self.ctx = DuktapeContext()
        self.ctx.set_base_path(os.path.dirname(__file__))

    def test_eval_file(self):
        self.ctx.eval_js_file('js/test0')
        res = self.ctx.get_global('res')

        self.assertEqual(res, 2)

    def test_eval_file_with_extension(self):
        self.ctx.eval_js_file('js/test0.js')
        res = self.ctx.get_global('res')

        self.assertEqual(res, 2)

    def test_require_module(self):
        self.ctx.eval_js_file('js/test2')
        res = self.ctx.get_global('res')

        self.assertEqual(res, 3)


class TestBasicConversion(TestCase):
    def setUp(self):
        self.ctx = DuktapeContext()

    def _convert(self, val):
        self.ctx.set_globals(x=val)
        return self.ctx.eval_js('x')

    def test_None(self):
        self.assertIsNone(self._convert(None))

    def test_int(self):
        self.assertEqual(self._convert(12), 12)

    def test_double(self):
        val = 1.23456789012345678909
        self.assertEqual(self._convert(val), val)

    def test_big_int_overflows(self):
        val = 1 << 54
        with self.assertRaises(OverflowError):
            self._convert(val)

    def test_int_fits_in_double(self):
        val = 1 << 53
        self.assertEqual(self._convert(val), val)

    def test_utf8_string(self):
        val = u'\u05D4'
        self.assertEqual(self._convert(val), val)

    def test_ascii_string(self):
        val = 'hello world'
        self.assertEqual(self._convert(val), val)

    def test_js_null_and_undefined(self):
        self.assertIsNone(self.ctx.eval_js('undefined'))
        self.assertIsNone(self.ctx.eval_js('null'))


class TestJSProxy(TestCase):
    def setUp(self):
        self.ctx = DuktapeContext()
        self.object_proxy = self.ctx.eval_js('x = {a: 1, b: 2, c: {d: 4}}; x')

    def test_array_proxy(self):
        array_proxy = self.ctx.eval_js('[]')
        self.assertIsInstance(array_proxy, JSProxy)

    def test_array_proxy_length(self):
        array_proxy = self.ctx.eval_js('[1, 2, 3, [4, 5]]')

        self.assertEqual(len(array_proxy), 4)
        self.assertEqual(array_proxy.length, 4)

    def test_array_proxy_iterate(self):
        array_proxy = self.ctx.eval_js('[1, 2, 3]')

        self.assertEqual([x for x in array_proxy], [1, 2, 3])
        self.assertEqual(list(array_proxy), [1, 2, 3])

    def test_array_proxy_indexing(self):
        array_proxy = self.ctx.eval_js('[1, 2, 3, [4, 5]]')

        self.assertEqual(array_proxy[0], 1)
        self.assertEqual(array_proxy[1], 2)
        self.assertEqual(array_proxy[2], 3)
        self.assertEqual([x for x in array_proxy[3]], [4, 5])

        with self.assertRaises(AttributeError):
            array_proxy[4]

    def test_object_proxy(self):
        self.assertIsInstance(self.object_proxy, JSProxy)

    def test_object_proxy_length(self):
        with self.assertRaises(AttributeError):
            self.object_proxy.length

        with self.assertRaises(AttributeError):
            len(self.object_proxy)

    def test_object_proxy_iter(self):
        self.assertEqual({x for x in self.object_proxy}, {'a', 'b', 'c'})

    def test_object_proxy_attr(self):
        self.assertEqual(self.object_proxy.a, 1)
        self.assertEqual(self.object_proxy.b, 2)
        self.assertIsInstance(self.object_proxy.c, JSProxy)
        self.assertEqual(self.object_proxy.c.d, 4)

        with self.assertRaises(AttributeError):
            self.assertEqual(self.object_proxy.does_not_exist, None)

    def test_object_proxy_attr_indexing(self):
        self.assertEqual(self.object_proxy['a'], 1)
        self.assertEqual(self.object_proxy['b'], 2)
        self.assertIsInstance(self.object_proxy['c'], JSProxy)
        self.assertEqual(self.object_proxy['c']['d'], 4)

    def test_object_proxy_method_call(self):
        object_proxy = self.ctx.eval_js('function F() { this.a = function () { return this.b; }; this.b = 42; }; new F()')

        self.assertEqual(object_proxy.a(), 42)
        x = object_proxy.a
        self.assertIsInstance(x, JSProxy)
        self.assertEqual(x(), 42)

    def test_function_proxy(self):
        function_proxy = self.ctx.eval_js('function f(a, b, c) { return a + b + c; }; f')
        res = function_proxy(1, 'a', 2)
        self.assertEqual(res, '1a2')

    def test_pass_js_obj_to_js_function(self):
        object_proxy = self.ctx.eval_js('function F() { this.x = function () { return 41; }; }; new F()')

        function_proxy = self.ctx.eval_js('function f(a) { return a.x() + 1; }; f')
        res = function_proxy(object_proxy)
        self.assertEqual(res, 42)

        # check that it's not passed as a python proxy
        function_proxy = self.ctx.eval_js('function f(a) { return a.__class__; }; f')
        res = function_proxy(object_proxy)
        self.assertEqual(res, None)

    def test_call_js_constructor(self):
        class_proxy = self.ctx.eval_js('function F(a) { this.x = a; }; F')

        res = class_proxy.new(42)

        self.assertEqual(res.x, 42)


class TestPyProxy(TestCase):
    def setUp(self):
        self.ctx = DuktapeContext()

    def test_py_proxy_get(self):
        class X(object):
            def __init__(self):
                self.x = 42

        self.ctx.set_globals(x=X())

        res = self.ctx.eval_js('x.x')
        self.assertEqual(res, 42)

        res = self.ctx.eval_js('x.y')
        self.assertEqual(res, None)

    def test_py_proxy_get_list_index(self):
        self.ctx.set_globals(x=[1, 3])

        res = self.ctx.eval_js('x[0]')
        self.assertEqual(res, 1)

        res = self.ctx.eval_js('x[3]')
        self.assertEqual(res, None)

    def test_py_proxy_get_dict_key(self):
        self.ctx.set_globals(x=dict(a=1, b=2))

        res = self.ctx.eval_js('x.a')
        self.assertEqual(res, 1)

        res = self.ctx.eval_js('x.c')
        self.assertEqual(res, None)

    def test_py_proxy_get_dict_method(self):
        self.ctx.set_globals(x=dict(a=1, b=2))

        res = self.ctx.eval_js('x.get("c", 42)')
        self.assertEqual(res, 42)

    def test_py_proxy_has(self):
        class X(object):
            def __init__(self):
                self.x = 42

        self.ctx.set_globals(x=X())

        res = self.ctx.eval_js('"x" in x')
        self.assertTrue(res)

        res = self.ctx.eval_js('"y" in x')
        self.assertFalse(res)

    def test_py_proxy_has_list_index(self):
        self.ctx.set_globals(x=[1, 3])

        res = self.ctx.eval_js('0 in x')
        self.assertTrue(res)

        res = self.ctx.eval_js('3 in x')
        self.assertFalse(res)

    def test_py_proxy_has_dict_key(self):
        self.ctx.set_globals(x=dict(a=1, b=2))

        res = self.ctx.eval_js('"a" in x')
        self.assertTrue(res)

        res = self.ctx.eval_js('"c" in x')
        self.assertFalse(res)

    def test_py_proxy_set(self):
        class X(object):
            def __init__(self):
                self.x = 42

        x = X()
        self.ctx.set_globals(x=x)

        self.ctx.eval_js('x.x = 12')
        self.assertEqual(x.x, 12)

    def test_py_proxy_set_index(self):
        x = [1, 3]
        self.ctx.set_globals(x=x)

        self.ctx.eval_js('x[0] = 2')
        self.assertEqual(x[0], 2)

        with self.assertRaises(JSError):
            self.ctx.eval_js('x[2] = 0')

    def test_py_proxy_set_dict_key(self):
        x = dict(a=1, b=2)
        self.ctx.set_globals(x=x)

        self.ctx.eval_js('x.a = 3')
        self.assertEqual(x['a'], 3)
        self.assertEqual(x['b'], 2)

    def test_py_proxy_call_method(self):
        class X(object):
            def __init__(self):
                self.x = 42

            def f(self, a):
                return self.x + a

        self.ctx.set_globals(x=X())
        res = self.ctx.eval_js('f = x.f; f(1)')

        self.assertEqual(res, 43)

    def test_construct_python_object(self):
        class X(object):
            def __init__(self):
                self.x = 42

        self.ctx.set_globals(X=X)
        res = self.ctx.eval_js('X().x')

        self.assertEqual(res, 42)

    def test_cant_call_new_on_py_proxy(self):
        class X(object):
            pass

        self.ctx.set_globals(X=X)
        with self.assertRaises(JSError) as err:
            self.ctx.eval_js('new X()')
        self.assertIn('can\'t use new on python objects', str(err.exception))

    def test_return_py_proxy_to_python(self):
        class X(object):
            pass

        x = X()
        self.ctx.set_globals(x=x)
        returned_x = self.ctx.eval_js('x')

        self.assertIs(x, returned_x)

    def test_py_proxy_function(self):
        def test(x):
            return x + 1

        self.ctx.set_globals(test=test)
        res = self.ctx.eval_js('test(41)')
        self.assertEqual(res, 42)

    def test_py_proxy_index_list(self):
        self.ctx.set_globals(x=[1, 2, 3])

        self.assertEqual(self.ctx.eval_js('x[0]'), 1)
        self.assertEqual(self.ctx.eval_js('x[1]'), 2)
        self.assertEqual(self.ctx.eval_js('x[2]'), 3)
        self.assertEqual(self.ctx.eval_js('x[3]'), None)

    def test_py_proxy_index_dict(self):
        self.ctx.set_globals(x=dict(a=1, b=2))

        self.assertEqual(self.ctx.eval_js('x["a"]'), 1)
        self.assertEqual(self.ctx.eval_js('x["b"]'), 2)
        self.assertEqual(self.ctx.eval_js('x["c"]'), None)
