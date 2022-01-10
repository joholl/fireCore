import binascii
import logging
import os
import random
import re
from collections import defaultdict
from enum import IntEnum
from typing import Any, Dict, List, Optional, Union

from .w1_device import W1Device

logger = logging.getLogger(__name__)


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
    """DS2413 2-pin (family code 0x3A) or DS2408 8-pin (family code 0x29) IO switch."""

    @property
    def value_info(self) -> str:
        # e.g. P0 driving low, P1 open drain (low)

        # for every pin: get output latch states
        output_states = self.read_outputs()
        # for pins in open drain state: measure pin state
        input_states = defaultdict(
            lambda: None, self.read_inputs(pins=None, outputs_from_cache=True)
        )

        return ", ".join(
            f"{pin.name} {state.output_str(input_state = input_states[pin])}"
            for pin, state in output_states.items()
        )

    def __html__(self, name: str = None) -> str:
        """Return html-encoded info about the device value/state.

        Returns:
            str: html-encoded info
        """
        # TODO wrap all that with exception stuff

        if not name:
            name = f"{self!r}"

        # for every pin: get output latch states
        output_states = self.read_outputs()
        # for pins in open drain state: measure pin state
        input_states = defaultdict(
            lambda: None, self.read_inputs(pins=None, outputs_from_cache=True)
        )

        def pin_html(pin):
            output_checked = "checked" if output_states[pin] is State.LOW else ""
            input_checked = (
                "checked"
                if output_states[pin] is State.LOW or input_states[pin] is State.LOW
                else ""
            )

            # TODO javascript handler: call api for writing which refreshes* on response/return (*rm and re-add from id?)
            return f"""
                <li>
                    <div style="text-align: center;">
                        {pin.name}
                    </div>
                    <div>
                        <label class="pinswitch">
                            <input type="checkbox" {input_checked} disabled>
                            <span class="pinslider round"></span>
                        </label>
                    </div>
                    <div>
                        <label class="pinswitch" onchange="onclick_pin(this)" data-device="{self.address_w1_string}" data-pin="{pin}">
                            <input type="checkbox" {output_checked}>
                            <span class="pinslider round"></span>
                        </label>
                    </div>
                </li>
            """

        return f"""
            {name}
            <div class="devicebox">
                <ol class="pins">
                    {"".join(pin_html(pin) for pin in self.Pin)}
                </ol>
            </div>
        """

    def read_inputs(
        self, pins: Optional[List[int]] = None, outputs_from_cache: bool = False
    ) -> Dict[int, State]:
        """
        Reads if all given pins are in open drain. If not, they are set to open drain. Then reads the pin states.
        If no pins are given, all pins which are currently open drain are read.

        Only the first call of read_outputs() can be cached ("state" file for TwoPin, "output" file for EightPin) by giving outputs_from_cache=True.
        """
        if pins is not None and len(pins) == 0:
            return {}

        # perform read (to get outputs)
        outputs = self.read_outputs(from_cache=outputs_from_cache)
        # for TwoPinIOSwitch, "state" file is read here, so we can read from cache subsequently (unlesss we change state)
        state_from_cache = isinstance(self, TwoPinIOSwitch)

        if pins is None:
            pins = [pin for pin, state in outputs.items() if state is State.HIGH]
        else:
            # for each pin: if pin is driving low, we need to switch to open drain first
            output_pins = [pin for pin in pins if outputs[pin] is State.LOW]
            if output_pins:
                self.write({pin: State.HIGH for pin in output_pins})
                # we change the pin states, don't use cache for reading later
                state_from_cache = False

        # perform read (to get pin states)
        # if all pins where in input mode previously, use cached value
        pin_states = self.read_file("state", from_cache=state_from_cache)

        return self.pin_states_from_mask(mask=pin_states, pins=pins)

    def read_input(self, pin: int, outputs_from_cache: bool = False) -> State:
        return self.read_inputs([pin], outputs_from_cache=outputs_from_cache)[pin]

    # TODO test
    def write(
        self,
        pins: Dict[int, State] = None,
        **pn: Dict[str, State],
    ) -> None:
        """Write the output latch state to the switch, e.g. to /sys/bus/w1/devices/3a-000000029895/output."""

        if not pins and not pn:
            return
        if pn and pins:
            raise ValueError(
                "Either kwargs (e.g. p0=State.LOW, p1=State.HIGH) or pins dict can be given, but not both."
            )
        if pn:
            # convert kwargs=Dict[str, State] to Dict[int, State]
            # e.g. {"p0": State.LOW, "p1": State.HIGH} -> {0: State.LOW, 1: State.HIGH}
            pins = {pin: int(pin_str[1:]) for pin_str, state in pn.items()}

        # sanity check given pins
        if any(pin not in self.Pin.__members__.values() for pin in pins.keys()):
            raise ValueError(
                f"Some of given pins are not valid: {pins.keys()} not in Pin({list(self.Pin.__members__.values())})"
            )

        # pins: set not present pins to DONT_CHANGE
        pins = {
            pin: pins[pin] if pin in pins else State.DONT_CHANGE for pin in self.Pin
        }

        # if any state is DONT_CHANGE, read first. Replace DONT_CHANGE states with current states
        if any(state is State.DONT_CHANGE for state in pins.values()):
            read_outputs = self.read_outputs()
            pins = {
                pin: state if state is not State.DONT_CHANGE else read_outputs[pin]
                for pin, state in pins.items()
            }

        value = self.dict_to_mask(pins)

        # reserved bits need to be 1 for DS2413
        if isinstance(self, TwoPinIOSwitch):
            value &= ~0xFC

        self.write_file(filename="output", value=value)

    def dict_to_mask(self, pins: Dict[int, State]) -> int:
        result = 0
        for pin, state in pins.items():
            result |= int(state == State.HIGH) << pin
        return result

    def mask_to_dict(self, mask: int) -> Dict[int, State]:
        result = {}
        for pin in self.Pin:
            result[pin] = State.HIGH if mask & (1 << pin) else State.LOW
        return result


class TwoPinIOSwitch(IOSwitch):
    """Maxim DS2413 IO switch. Kernel driver: w1_ds2413, see https://www.kernel.org/doc/html/latest/w1/slaves/w1_ds2413.html.

    P0 and P1 can be inputs or outputs. For output, an output latch can pull
    down a line (pulled high by an external pull-up).

    Output latch: 0 is pull-down, 1 is open drain (line is left high)

    If the output latch is 1 (open drain), the pin state can be read.

    Files:
        state (r):  bits about if pins are driven low and if not, their input state
        output (w): drive bit low or open drain
    """

    FAMILY_BYTE = 0x3A

    class Pin(IntEnum):
        P0 = 0x00
        P1 = 0x01

    MASK_P0_PIN = 0x01
    MASK_P0_OUTPUT_LATCH = 0x02
    MASK_P1_PIN = 0x04
    MASK_P1_OUTPUT_LATCH = 0x08

    def read_outputs(
        self, from_cache: bool = False
    ) -> Dict["TwoPinIOSwitch.Pin", State]:
        read_value = self.read_file("state", from_cache=from_cache)

        return {
            self.Pin.P0: State.HIGH
            if read_value & self.MASK_P0_OUTPUT_LATCH
            else State.LOW,
            self.Pin.P1: State.HIGH
            if read_value & self.MASK_P1_OUTPUT_LATCH
            else State.LOW,
        }

    def pin_states_from_mask(self, mask: int, pins: List[int]) -> Dict[int, State]:
        result = {}

        if self.Pin.P0 in pins:
            result[self.Pin.P0] = State.HIGH if mask & self.MASK_P0_PIN else State.LOW
        if self.Pin.P1 in pins:
            result[self.Pin.P1] = State.HIGH if mask & self.MASK_P1_PIN else State.LOW

        return result


class EightPinIOSwitch(IOSwitch):
    """Maxim DS2408 IO switch. Kernel driver: w1_ds2408 (no doc page).

    P0..P7 can be inputs or outputs. For output, an output latch can pull
    down a line (pulled high by an external pull-up).

    Output latch: 0 is pull-down, 1 is open drain (line is left high)

    If the output latch is 1 (open drain), the pin state can be read.

    Files:
        output (r): if pins are driven low or open drain
        output (w): drive pins low or open drain
        state (r):  read pin input states (if they are open drain)
    """

    FAMILY_BYTE = 0x29

    MASK_CONTROL_STATUS_ROS = 0x04
    MASK_CONTROL_STATUS_PORL = 0x08

    class Pin(IntEnum):
        P0 = 0x00
        P1 = 0x01
        P2 = 0x02
        P3 = 0x03
        P4 = 0x04
        P5 = 0x05
        P6 = 0x06
        P7 = 0x07

    def ensure_inited(self) -> None:
        """Control/Status Register bit PORL (Power-On Reset Latch) needs to be set to 0 before IOSwitch operation."""
        # the following bits need to be clear and set, respectively
        mask_clear = self.MASK_CONTROL_STATUS_PORL
        mask_set = self.MASK_CONTROL_STATUS_ROS

        control_status_register = 0xFF
        while control_status_register == 0xFF:
            # read until result is not 0xff (error reading)
            control_status_register = self.read_file("status_control")

            # return if all bits set/clear according to masks
            if (
                control_status_register & mask_set == mask_set
                and ~control_status_register & mask_clear == mask_clear
            ):
                return

        logger.info(
            f"{self!r}: Status/Control Register is {control_status_register:02x}. Set ROS and reset PROL bit."
        )
        control_status_register |= mask_set
        control_status_register &= ~mask_clear

        # bit is set, reset bit
        self.write_file(filename="status_control", value=control_status_register)

    def read_outputs(
        self, from_cache: bool = False
    ) -> Dict["EightPinIOSwitch.Pin", State]:
        if not from_cache:
            self.ensure_inited()

        return self.mask_to_dict(self.read_file("output", from_cache=from_cache))

    def read_inputs(
        self, pins: List[int], outputs_from_cache: bool = False
    ) -> Dict[int, State]:
        # if we did an output operation recently, the switch was inited then
        if not outputs_from_cache:
            self.ensure_inited()

        return super().read_inputs(pins=pins, outputs_from_cache=outputs_from_cache)

    def pin_states_from_mask(self, mask: int, pins: List[int]) -> Dict[int, State]:
        all_pin_states = self.mask_to_dict(mask)
        return {pin: all_pin_states[pin] for pin in pins}
