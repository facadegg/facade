from os import environ
from setuptools import setup

setup(
    name='pyfacade',
    version=environ['PYFACADE_VERSION'],
    description='A Python interface to Facade virtual device management',
    author='Shukant Pal',
    author_email='facade@shukantpal.com',
    classifiers=[
        "Programming Language :: Python :: 3",
    ],
    include_package_data=True,
    install_requires=["cffi>=1.15.1"],
    packages=['pyfacade'],
    package_dir={'pyfacade': 'pyfacade'},
    setup_requires=["cffi>=1.15.1"],
    url='https://facade.gg/docs'
)
