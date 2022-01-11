import binascii
import logging
import os
import platform
import re
from enum import IntEnum
from typing import Any, Dict, List, Type, Union

from .io_switch import EightPinIOSwitch, State, TwoPinIOSwitch
from .simulation import (
    EightPinIOSwitchSimulator,
    TemperatureSensorSimulator,
    TwoPinIOSwitchSimulator,
    W1DeviceSimulator,
)
from .temperature_sensor import TemperatureSensor, TemperatureSensorGroup
from .w1_device import W1Device

logger = logging.getLogger(__name__)


# TODO by config/env
SIMULATION = False  # "x86_64" in platform.uname().machine


SIMULATOR_CLASSES = {
    W1Device: W1DeviceSimulator,
    TemperatureSensor: TemperatureSensorSimulator,
    TwoPinIOSwitch: TwoPinIOSwitchSimulator,
    EightPinIOSwitch: EightPinIOSwitchSimulator,
}


simulators_by_addresses = {}


class OneWire:
    @staticmethod
    def _get_device_type(address_w1_str: str) -> Type[W1Device]:
        w1_classes = (TemperatureSensor, TwoPinIOSwitch, EightPinIOSwitch)

        family_byte = binascii.unhexlify(address_w1_str[0:2])[0]

        # match family byte in address
        for w1_class in w1_classes:
            if family_byte == w1_class.FAMILY_BYTE:
                return w1_class

        # return generic class
        return W1Device

    @staticmethod
    def device_from_address(address_w1_str: str) -> Type[W1Device]:
        device_type = OneWire._get_device_type(address_w1_str=address_w1_str)

        simulator = None
        if SIMULATION:
            if address_w1_str in simulators_by_addresses:
                simulator = simulators_by_addresses[address_w1_str]
            else:
                simulator = SIMULATOR_CLASSES[device_type]()
                simulators_by_addresses[address_w1_str] = simulator

        return device_type(
            address=address_w1_str,
            simulator=simulator,
        )

    @staticmethod
    def get_devices() -> List[Type[W1Device]]:
        driver_path = "/sys/bus/w1"
        devices_path = os.path.join(driver_path, "devices")
        if not os.path.exists(driver_path) and not SIMULATION:
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
            return {}

        if not SIMULATION:
            addresses = [
                device
                for device in os.listdir(devices_path)
                if re.match(r"[0-9a-fA-F]{2}-[0-9a-fA-F]{12}", device)
            ]
        else:
            addresses = [
                "10-000802295789",
                "29-0000000869e8",
                "3a-000000029895",
                "3a-001122334455",
                "55-001122334455",
            ]

        return [OneWire.device_from_address(addr) for addr in addresses]
