from os import path

from setuptools import setup, find_packages, Extension
from codecs import open

readme_path = path.join(path.abspath(path.dirname(__file__)), 'README.rst')
with open(readme_path, encoding='utf-8') as readme:
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
    version='0.0.5',
    author='Stefano Dissegna',
    description='Python integration for the Duktape Javascript interpreter',
    long_description=long_description,
    url='https://github.com/stefano/pyduktape',
    license='GPL',
    keywords='javascript duktape embed',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'License :: OSI Approved :: GNU General Public License v2 (GPLv2)',
        'Programming Language :: Python :: 2',
        'Programming Language :: JavaScript',
        'Topic :: Software Development :: Interpreters',
    ],

    packages=find_packages(exclude=['tests']),
    setup_requires=['setuptools>=18.0', 'Cython'],
    test_suite='tests',

    ext_modules=extensions,
)
