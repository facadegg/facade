from enum import IntEnum


class FacadeErrorCode(IntEnum):
    none = 0
    unknown = 1
    protocol = 2
    invalid_type = 3
    invalid_state = 4
    invalid_input = 5
    reader_not_ready = 6
    writer_not_ready = 7


class FacadeError(Exception):
    def __init__(self, invocation: str, code: FacadeErrorCode):
        self.invocation = invocation
        self.code = code

    def __str__(self) -> str:
        return f"{self.invocation} return with error {self.code}"
