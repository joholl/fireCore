import binascii
import logging
import os
import re
from enum import IntEnum
from typing import Any, Dict, List, Type, Union

from .io_switch import PIO, IOSwitch, State
from .temperature_sensor import TemperatureSensor
from .w1_device import W1Device

logger = logging.getLogger(__name__)


class OneWire:
    @staticmethod
    def get_device_type(address_w1_str: str) -> Type[W1Device]:
        w1_classes = (IOSwitch, TemperatureSensor)

        family_byte = binascii.unhexlify(address_w1_str[0:2])[0]

        # match family byte in address
        for w1_class in w1_classes:
            if family_byte == w1_class.FAMILY_BYTE:
                return w1_class

        # return generic class
        return W1Device

    @staticmethod
    def get_devices() -> List[Type[W1Device]]:
        driver_path = "/sys/bus/w1"
        devices_path = os.path.join(driver_path, "devices")
        if not os.path.exists(driver_path):
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
            return {}

        addresses = [
            device
            for device in os.listdir(devices_path)
            if re.match(r"[0-9a-fA-F]{2}-[0-9a-fA-F]{12}", device)
        ]

        return [OneWire.get_device_type(addr)(addr) for addr in addresses]


# TemperatureSensor(address=b"\x00\x08\x02\x29\x57\x89\x10")


# Finden im csv: (?<=16,).*,0
# Umwandeln csv zu python bytes: fn = lambda *args: print(''.join(r"\x" + f"{b:02x}" for b in args[::-1]))


# kreis_holzofen = [
#     TemperatureSensorGroup(
#         sensors=[
#             # Holzofen Vorlauf 1
#             TemperatureSensor(address=b"\x00\x08\x01\xe1\xaa\x1a\x10"),
#             # Holzofen Vorlauf 2
#             TemperatureSensor(address=b"\x00\x08\x01\xe1\xa3\x5d\x10"),
#         ]
#     ),
# ]

# water_buffers = [
#     # Wasser Puffer 1
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x01\xe3\x7b\x0d\x10"),
#             TemperatureSensor(address=b"\x00\x08\x01\xe3\x75\x96\x10"),
#             TemperatureSensor(address=b"\x00\x08\x01\xe3\x9c\x76\x10"),
#             TemperatureSensor(address=b"\x00\x08\x01\xe3\x54\x81\x10"),
#             # TemperatureSensor(address=b"\x00\x08\x01\xe3\x\x\x10"),
#         ]
#     ),
#     # Wasser Puffer 2
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x02\xc3\x91\xa5\x10"),
#             TemperatureSensor(address=b"\x00\x08\x02\xc3\xe1\xf3\x10"),
#             TemperatureSensor(address=b"\x00\x08\x02\xc3\x46\x6a\x10"),
#             TemperatureSensor(address=b"\x00\x08\x02\xc3\xa9\xe0\x10"),
#             # TemperatureSensor(address=b"\x00\x08\x02\xc3\x\x\x10"),
#         ]
#     ),
#     # Wasser Puffer 3
#     TemperatureSensorGroup(
#         sensors=[
#             # TODO
#         ]
#     ),
# ]

# boilers = [
#     # Boiler 1
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x01\xe1\x82\xf6\x10"),
#         ]
#     ),
#     # Boiler 2
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x02\x1d\x84\x73\x10"),
#             TemperatureSensor(address=b"\x00\x08\x02\xc3\x8f\x52\x10"),
#         ]
#     ),
# ]

# kreis_heizkreis = [
#     TemperatureSensorGroup(
#         sensors=[
#             # Heizkreis Vorlauf
#             TemperatureSensor(address=b"\x00\x08\x01\xdd\x5c\xe2\x10"),
#         ]
#     ),
#     TemperatureSensorGroup(
#         sensors=[
#             # Heizkreis Rücklauf
#             TemperatureSensor(address=b"\x00\x08\x01\xe3\x8c\x7e\x10"),
#         ]
#     ),
# ]

# außentemperatur = [
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x01\xe1\x5e\x9b\x10"),
#         ]
#     ),
# ]

# oelofen = [
#     TemperatureSensorGroup(
#         sensors=[
#             TemperatureSensor(address=b"\x00\x08\x01\xe1\x8f\x5d\x10"),
#         ]
#     ),
# ]

# solar_panels = [
#     TemperatureSensorGroup(
#         sensors=[
#             # solar panel 6
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x21\x91\x10"),
#             # solar panel 5
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x68\x09\x10"),
#             # solar panel 4
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x39\x77\x10"),
#             # solar panel 3
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x79\x35\x10"),
#             # solar panel 2
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x9b\xed\x10"),
#             # solar panel 1
#             TemperatureSensor(address=b"\x00\x08\x02\x29\x11\xae\x10"),
#         ]
#     ),
# ]


# Relais_8IO Chip 2.1       \x00\x00\x00\x08\x67\x34\x29
# DCF77_8IO Chip 2.2        \x00\x00\x00\x08\x65\x8b\x29
# Solar_8IO Chip 2.3        \x00\x00\x00\x08\x60\xe5\x29
# not used _8IO Chip 2.4    \x00\x00\x00\x08\x6b\xb7\x29

# Ausgabe 2I Chip 3.1       \x00\x00\x00\x02\xae\xc4\x3A
