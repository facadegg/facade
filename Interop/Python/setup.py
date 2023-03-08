from setuptools import setup

setup(
    name='pyfacade',
    version='1.0.0rc1',
    description='A Python interface to the libktx library',
    author='Shukant Pal',
    author_email='facade@palcor.net',
    classifiers=[
        "Programming Language :: Python :: 3",
    ],
    include_package_data=True,
    install_requires=["cffi>=1.15.1"],
    packages=['facade'],
    package_dir={'facade': 'facade'},
    setup_requires=["cffi>=1.15.1"],
    url='https://source.shukantpal.com/PaalMaxima/Facade'
)
