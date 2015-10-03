from os import path

from setuptools import setup, find_packages, Extension
from codecs import open
from Cython.Build import cythonize


with open(path.join(path.abspath(path.dirname(__file__)), 'README'), encoding='utf-8') as readme:
    long_description = readme.read()

extensions = [
    Extension(
      'pyduktape',
      ['pyduktape.pyx'],
      define_macros=[
        ('DUK_OPT_DEBUGGER_SUPPORT', '1'),
        ('DUK_OPT_INTERRUPT_COUNTER', '1'),
      ],
    )
]

setup(
    name='pyduktape',
    version='0.0.1',
    author='Stefano Dissegna',
    description='Python interface to duktape',
    long_description=long_description,
    url='',
    license='GPL',
    keywords='javascript duktape embed',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'License :: OSI Approved :: GNU General Public License v2 (GPLv2)',
        'Programming Language :: Python :: 2',
        'Programming Language :: JavaScript',
        'Topic :: Software Development :: Interpreters',
    ],

    packages=find_packages(),
    install_requires=['cython'],
    test_suite='tests',

    ext_modules=cythonize(extensions),
)
