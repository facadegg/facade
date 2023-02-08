from enum import IntEnum


class FacadeErrorCode(IntEnum):
    none = 0
    unknown = 1
    protocol = 2
    invalid_type = 3
    reader_not_ready = 4
    writer_not_ready = 5


class FacadeError(Exception):
    def __init__(self, invocation: str, code: FacadeErrorCode):
        self.invocation = invocation
        self.code = code

    def __str__(self):
        return f"{self.invocation} return with error {self.code}"
