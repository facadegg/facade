from enum import IntEnum


class FacadeErrorCode(IntEnum):
    """
    An enumeration of the different failure modes that can occur using pyfacade.
    """

    none = 0

    unknown = 1
    """
    An unspecified error that is system specific.
    """

    protocol = 2
    """
    An incompatibility between libfacade and the Facade system extension.
    """

    invalid_type = 3
    """
    A device with the wrong type was passed.
    """

    invalid_state = 4
    """
    A given operation cannot be done in the current state.
    """

    invalid_input = 5
    """
    The passed argument have unacceptable values.
    """

    reader_not_ready = 6
    """
    The device is not ready to be read again.
    """

    writer_not_ready = 7
    """
    The device is not ready to be written to again.
    """


class FacadeError(Exception):
    """
    Thrown when a native Facade operation fails. A :py:class:`FacadeErrorCode` code is
    attached for debugging purposes.
    """

    invocation: str
    """
    The C function that returned a non-success code.
    """

    code: FacadeErrorCode
    """
    The failure code returned.
    """

    def __init__(self, invocation: str, code: FacadeErrorCode):
        self.invocation = invocation
        self.code = code

    def __str__(self) -> str:
        return f"{self.invocation} return with error {self.code}"
