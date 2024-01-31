find_package (Python3 COMPONENTS Interpreter REQUIRED)

file(GLOB pyfacade_py_src pyktx/*.py)

message(INFO ${pyfacade_py_src})
message(INFO "printed")

add_custom_target(pyfacade ALL
    WORKING_DIRECTORY
        ${CMAKE_SOURCE_DIR}/Interop/Python
    COMMENT
        "pyfacade distribution")

add_custom_command(
    TARGET
        pyfacade
    PRE_BUILD
    COMMAND
        ${Python3_EXECUTABLE} -m pip install -r requirements.txt
    WORKING_DIRECTORY
        ${CMAKE_SOURCE_DIR}/Interop/Python)

add_custom_command(TARGET pyfacade
    BYPRODUCTS
        ${CMAKE_SOURCE_DIR}/Interop/Python/dist/pyfacade-${FACADE_VERSION}.tar.gz
    DEPENDS
        ${pyfacade_py_src}
    COMMAND
        ${CMAKE_COMMAND} -E env
            PYFACADE_VERSION=${FACADE_VERSION}
        ${Python3_EXECUTABLE} -m build --sdist --outdir dist
    WORKING_DIRECTORY
        ${CMAKE_SOURCE_DIR}/Interop/Python)

add_custom_command(TARGET pyfacade
    DEPENDS
        ${pyfacade_py_src}
        conf.py
        index.rst
    COMMAND
        ${CMAKE_COMMAND} -E env
            PYFACADE_VERSION=${FACADE_VERSION}
        make html
    WORKING_DIRECTORY
        ${CMAKE_SOURCE_DIR}/Interop/Python)