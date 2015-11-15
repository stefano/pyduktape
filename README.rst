Introduction
############

Pyduktape is a python wrapper around `Duktape <http://duktape.org/>`_,
an embeddable Javascript interpreter.

On top of the interpreter wrapper, pyduktape offers easy integration
between the Python and the Javascript environments. You can pass
Python objects to Javascript, call methods on them and access their
attributes.  Similarly, you can pass Javascript objects to Python.

Objects are never copied or serialized. Instead, they are passed
between the two environments using proxy objects. Proxy objects
delegate the execution to the original object environment.

Threading
#########

It is possible to invoke Javascript code from multiple threads. Each
thread will need to use its own embedded interpreter. Javascript
objects returned to the Python environment will only be usable on the
same thread that created them. The runtime always checks this
condition automatically, and raises a ``DuktapeThreadError`` if it's
violated.

Getting Started
###############

Installation
------------

To install from pypi::

    $ pip install -U setuptools
    $ pip install pyduktape

To install the latest version from github::

    $ git clone https://github.com/stefano/pyduktape.git
    $ cd pyduktape
    $ pip install -U setuptools
    $ python setup.py install

Running Javascript code
-----------------------

To run Javascript code, you need to create an execution context and
use the method ``eval_js``::

    import pyduktape

    context = pyduktape.DuktapeContext()
    context.eval_js("print('Hello, world!');")

Each execution context starts its own interpreter. Each context is
independent, and tied to the Python thread that created it. Memory is
automatically managed.

To evaluate external Javascript files, use ``eval_js_file``::

    // helloWorld.js
    print('Hello, World!');

    # in the Python interpreter
    import pyduktape

    context = pyduktape.DuktapeContext()
    context.eval_js_file('helloWorld.js')

Pyduktape supports Javascript modules::

    // js/helloWorld.js
    exports.sayHello = function () {
        print('Hello, World!');
    };

    // js/main.js
    var helloWorld = require('js/helloWorld');
    helloWorld.sayHello();

    # in the Python interpreter
    import pyduktape

    context = pyduktape.DuktapeContext()
    context.eval_js_file('js/main')

The ``.js`` extension is automatically added if missing.  Relative
paths are relative to the current working directory, but you can
change the base path using ``set_base_path``::

    # js/helloWorld.js
    print('Hello, World!');

    # in the Python interpreter
    import pyduktape

    context = pyduktape.DuktapeContext()
    context.set_base_path('js')
    context.eval_js_file('helloWorld')

Python and Javascript integration
---------------------------------

You can use ``set_globals`` to set Javascript global variables::

    import pyduktape

    def say_hello(to):
        print 'Hello, {}!'.format(to)

    context = pyduktape.DuktapeContext()
    context.set_globals(sayHello=say_hello, world='World')
    context.eval_js("sayHello(world);")

You can use ``get_global`` to access Javascript global variables::

    import pyduktape

    context = pyduktape.DuktapeContext()
    context.eval_js("var helloWorld = 'Hello, World!';")
    print context.get_global('helloWorld')

``eval_js`` returns the value of the last expression::

    import pyduktape

    context = pyduktape.DuktapeContext()
    hello_world = context.eval_js("var helloWorld = 'Hello, World!'; helloWorld")
    print hello_world

You can seamlessly use Python objects and functions within Javascript
code.  There are some limitations, though: any Python callable can
only be used as a function, and other attributes cannot be
accessed. Primitive types (int, float, string, None) are converted to
equivalent Javascript primitives.  The following code shows how to
interact with a Python object from Javascript::

    import pyduktape

    class Hello(object):
        def __init__(self, what):
            self.what = what

        def say(self):
            print 'Hello, {}!'.format(self.what)

    context = pyduktape.DuktapeContext()
    context.set_globals(Hello=Hello)
    context.eval_js("var helloWorld = Hello('World'); helloWorld.say();")

In the same way, you can use Javascript objects in Python.  You can
use the special method `new` to instantiate an object::

    import pyduktape

    context = pyduktape.DuktapeContext()
    Hello = context.eval_js("""
    function Hello(what) {
        this.what = what;
    }

    Hello.prototype.say = function () {
        print('Hello, ' + this.what + '!');
    };

    Hello
    """)

    hello_world = Hello.new('World')
    hello_world.say()

You can use Python lists and dicts from Javascript, and viceversa::

    import pyduktape

    context = pyduktape.DuktapeContext()
    res = context.eval_js('[1, 2, 3]')

    for item in res:
        print item

    context.set_globals(lst=[4, 5, 6])
    context.eval_js('for (var i = 0; i < lst.length; i++) { print(lst[i]); }')

    res = context.eval_js('var x = {a: 1, b: 2}; x')
    for key, val in res.items():
        print key, '=', val
    res.c = 3
    context.eval_js('print(x.c);')

    context.set_globals(x=dict(a=1, b=2))
    context.eval_js("""
    var items = x.items();
    for (var i = 0; i < items.length; i++) {
        print(items[i][0] + ' = ' + items[i][1]);
    }
    """)
    context.set_globals(x=dict(a=1, b=2))
    context.eval_js('for (var k in x) { print(k + ' = ' + x[k]); }')
