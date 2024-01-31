import re


def out_python(data: str) -> None:
    """
    Strip the header file from all macros / comments and output then into the Python file
    :param data:
    :return:
    """

    # remove comments
    data = re.sub(r'/\*.*?\*/', '', data, flags=re.DOTALL)
    data = re.sub(r'//.*?\n', '\n', data)

    # remove macros
    data = re.sub(r'#.*\n', '', data)

    lines = list(filter(lambda l: len(l.strip()) > 0, data.splitlines()))

    assert lines[0] == 'extern "C" {'
    assert lines[-1] == '}'

    lines = lines[1:-1]
    data = '\n'.join(lines)

    with open('../Interop/Python/pyfacade/libfacade_h.py', 'w') as libfacade_hpy:
        libfacade_hpy.write(
            f"""\
facade_h = \"\"\"
{data}
void free(void *);
\"\"\"
"""
        )


if __name__ == "__main__":
    with open('../Include/facade.h', 'r') as facade_h:
        header = facade_h.read()
        out_python(header)
