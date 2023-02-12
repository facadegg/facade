# xsd.py
#
# Copy the facade.xsd schema into target folders.

from typing import Iterable


def copy_to_darwin(xsdContents: Iterable[str]):
    c_literal = '\n'.join(map(lambda l: '"' + str(l)
                              .replace('\\', '\\\\')
                              .replace('\n', '\\n')
                              .replace('"', '\\"') + '"',
                              xsdContents))
    c_src = f"""\
//
//  libfacadexml.m
//  libfacade
//
//  This is an auto-generated file. Do not edit it directly (see Buildscripts/xsd.py).
//

char *xsd_contents =
{c_literal};

char *facade_xsd(void)
{{
    return xsd_contents;
}}
"""

    with open('../Darwin/libfacade/libfacadexml.m', 'w') as libfacadeXmlSourceFile:
        libfacadeXmlSourceFile.write(c_src)


if __name__ == "__main__":
    with open('../Include/facade.xsd', 'r') as xsd_file:
        xsd_contents = xsd_file.readlines()

        copy_to_darwin(xsd_contents)

