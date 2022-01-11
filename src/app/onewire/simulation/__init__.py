import random


class W1DeviceSimulator:
    def read(self, path: str) -> bytes:
        ...

    def write(self, path: str, value: bytes) -> None:
        ...


class TemperatureSensorSimulator:
    def read(self, path: str) -> bytes:
        result = f"22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t={random.randrange(10000, 80000)}"
        return result.encode()

    def write(self, path: str, value: bytes) -> None:
        raise NotImplementedError(
            f"Simulator: writing to path is not implemented: {path}"
        )


class TwoPinIOSwitchSimulator:
    def __init__(self):
        # set P0, P1 to open drain
        self.output = {pin: 1 for pin in range(2)}

    @property
    def state(self):
        # low if output is driving low, random input otherwise
        return {
            pin: 0 if self.output[pin] == 0 else random.randint(0, 1)
            for pin, state in self.output.items()
        }

    def read(self, path: str) -> bytes:
        state_byte = (
            self.output[1] << 3
            | self.state[1] << 2
            | self.output[0] << 1
            | self.state[0] << 0
        )
        return bytes([state_byte])

    def write(self, path: str, value: bytes) -> None:
        self.output = {pin: int(bool(value[0] & (1 << pin))) for pin in range(2)}


class EightPinIOSwitchSimulator:
    def __init__(self):
        # set P0..P7 to open drain
        self.output = {pin: 1 for pin in range(8)}
        self.status_control = {
            0: 0,  # PLS
            1: 0,  # CT
            2: 0,  # ROS
            3: 1,  # PORL
            4: 0,  # reserved
            5: 0,  # reserved
            6: 0,  # reserved
            7: 0,  # VCCP
        }

    @property
    def state(self):
        # low if output is driving low, random input otherwise
        return {
            pin: 0 if self.output[pin] == 0 else random.randint(0, 1)
            for pin, state in self.output.items()
        }

    def read(self, path: str) -> bytes:
        if "state" in path:
            pin_state_dict = self.state
        elif "output" in path:
            pin_state_dict = self.output
        elif "status_control" in path:
            pin_state_dict = self.status_control
        else:
            raise NotImplementedError(
                f"Simulator: reading from path is not implemented: {path}"
            )

        result = 0
        for pin, state in pin_state_dict.items():
            result |= state << pin
        return bytes([result])

    def write(self, path: str, value: bytes) -> None:
        value = value[0]
        if "output" in path:
            # nop if status_control is wrong
            if not self.status_control[2] or self.status_control[3]:
                return
            self.output = {pin: int(bool(value & (1 << pin))) for pin in range(8)}
        elif "status_control" in path:
            status_control = {pin: int(bool(value & (1 << pin))) for pin in range(8)}
            # nop if reserved bits are set
            if status_control[4] or status_control[5] or status_control[6]:
                return
            self.status_control = status_control
        else:
            raise NotImplementedError(
                f"Simulator: writing to path is not implemented: {path}"
            )
