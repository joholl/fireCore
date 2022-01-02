import binascii
import logging
import os
import re
from enum import IntEnum
from typing import Any, Dict, List, Union

from .w1_device import W1Device

logger = logging.getLogger(__name__)


class PIO(IntEnum):
    A = 0
    B = 1


class State(IntEnum):
    LOW = 0
    HIGH = 1
    DONT_CHANGE = 2

    def input_str(self):
        return {
            State.LOW: "low",
            State.HIGH: "high",
            State.DONT_CHANGE: "ERROR",
        }[self.value]

    def output_str(self, input_state: "State" = None) -> str:
        return {
            State.LOW: "driving low",
            State.HIGH: "open drain"
            + (f" ({input_state.input_str()})" if input_state is not None else ""),
            State.DONT_CHANGE: "ERROR",
        }[self.value]


class IOSwitch(W1Device):
    """Maxim DS2413 IO switch. Kernel driver: w1_ds2413, see https://www.kernel.org/doc/html/latest/w1/slaves/w1_ds2413.html.

    PIOA and PIOB can be inputs or outputs. For output, an output latch can pull
    down a line (pulled high by an external pull-up).

    Output latch: 0 is pull-down, 1 is open drain (line is left high)

    If the output latch is 1 (open drain), the pin state can be read.
    """

    FAMILY_BYTE = 0x3A

    MASK_PIOA_PIN = 0x01
    MASK_PIOA_OUTPUT_LATCH = 0x02
    MASK_PIOB_PIN = 0x04
    MASK_PIOB_OUTPUT_LATCH = 0x08

    def write(
        self,
        pin_a: State = State.DONT_CHANGE,
        pin_b: State = State.DONT_CHANGE,
        pins: Dict[PIO, State] = None,
    ) -> None:
        # if pin_a or pin_b given
        if any(state is not State.DONT_CHANGE for state in (pin_a, pin_b)):
            if pins is not None:
                raise ValueError(
                    "Either a combination of pin_a, pin_b or the pins dict can be given, but not both."
                )
            pins = {
                PIO.A: pin_a,
                PIO.B: pin_b,
            }
        else:
            # pins: set not present pins to DONT_CHANGE
            pins = {pin: pins[pin] if pin in pins else State.DONT_CHANGE for pin in PIO}

        # If any state is DONT_CHANGE, read first. Replace DONT_CHANGE states with current states
        if any(state is State.DONT_CHANGE for state in pins.values()):
            read_outputs = self.read_outputs()
            pins = {
                pin: state if state is not State.DONT_CHANGE else read_outputs[pin]
                for pin, state in pins
            }
        self.write_kernel_device(value=0xFC | pins[PIO.B] << 1 | pins[PIO.A])

    def read_outputs(self) -> Dict[PIO, State]:
        read_value = self.read_kernel_device()

        return {
            PIO.A: State.HIGH
            if read_value & self.MASK_PIOA_OUTPUT_LATCH
            else State.LOW,
            PIO.B: State.HIGH
            if read_value & self.MASK_PIOB_OUTPUT_LATCH
            else State.LOW,
        }

    def read_input(self, pin: PIO) -> State:
        # perform read (to get outputs)
        read_outputs = self.read_outputs()

        # if pin is driving low, we need to switch to open drain first to read
        if read_outputs[pin] is State.LOW:
            self.write({pin: State.HIGH})

        # perform read (to get pin state)
        read_value = self.read_kernel_device()

        mask = {PIO.A: self.MASK_PIOA_PIN, PIO.B: self.MASK_PIOB_PIN}[pin]
        return State.HIGH if read_value & mask else State.LOW

    def read_kernel_device(self) -> int:
        """Read the state from the switch, e.g. from /sys/bus/w1/devices/3a-000000029895/state

        Raises:
            FileNotFoundError: If there is no such file

        Returns:
            int: bit 0: PIOA pin, bit 1: PIOA output latch, bit 2: PIOB pin, bit 3: PIOB output latch
        """
        driver_path = "/sys/bus/w1"
        device_path = os.path.join(
            driver_path, "devices", self.address_w1_string, "state"
        )

        if not os.path.exists(driver_path):
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
        if not os.path.exists(device_path):
            logger.warning(
                f"Path {device_path} does not exist. Is the switch connected?"
            )

        with open(device_path, "rb") as f:
            return f.read(1)[0]

    def write_kernel_device(self, value: int) -> None:
        """Write the output latch state to the switch, e.g. to /sys/bus/w1/devices/3a-000000029895/output

        Args:
            value (int): bit 0: PIOA output latch (0 is pull-down, 1 is open drain), bit 1: PIOB output latch

        Raises:
            FileNotFoundError: If there is no such file
        """
        driver_path = "/sys/bus/w1"
        device_path = os.path.join(
            driver_path, "devices", self.address_w1_string, "output"
        )

        if not os.path.exists(driver_path):
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
        if not os.path.exists(device_path):
            logger.warning(
                f"Path {device_path} does not exist. Is the switch connected?"
            )

        # reserved bits need to be 1
        value |= 0xFC

        with open(device_path, "wb") as f:
            f.write(value)

    @property
    def value_info(self) -> str:
        # e.g. PIO.A driving low, PIO.B open drain (low)

        pin_infos = []
        for pin, state in self.read_outputs().items():
            input_state = None
            if state is State.HIGH:
                input_state = self.read_input(pin)
            pin_infos.append(
                f"{type(pin).__name__}{pin.name} {state.output_str(input_state = input_state)}"
            )

        return ", ".join(pin_infos)
