from cffi import FFI
import os
import sys

from .libfacade_h import facade_h

LIBFACADE_LIB_DIR = os.getenv("LIBFACADE_DIR")

if sys.platform == 'darwin':
    if LIBFACADE_LIB_DIR is None:
        LIBFACADE_LIB_DIR = '/Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework/'

os.environ['DYLD_LIBRARY_PATH'] = f"{LIBFACADE_LIB_DIR}" \
                                  f"{':' +  os.environ['DYLD_LIBRARY_PATH'] if 'DYLD_LIBRARY_PATH' in os.environ else ''}"

ffi = FFI()
ffi.cdef(facade_h)

libfacade = ffi.dlopen('facade')
