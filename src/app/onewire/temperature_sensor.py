import binascii
import logging
import os
import random
import re
from enum import IntEnum
from typing import Any, Dict, List, Union

from .w1_device import W1Device

logger = logging.getLogger(__name__)


class TemperatureSensor(W1Device):
    """Maxim DS18*20, DS1825 sensor. Kernel driver: w1_therm, see https://www.kernel.org/doc/html/latest/w1/slaves/w1_therm.html."""

    FAMILY_BYTE = 0x10

    @property
    def value_info(self) -> str:
        """Return human readable info about the device value/state.

        Returns:
            str: Human readable info, e.g. 18.687 °C
        """
        return f"{self.temperature} °C"

    def __html__(self, name: str = None) -> str:
        """Return html-encoded info about the device value/state.

        Returns:
            str: html-encoded info, e.g. 18.687 °C
        """
        return f"{name}: {self}"

    @property
    def temperature(self) -> float:
        """Read the temperature from the sensor, e.g. from /sys/bus/w1/devices/10-000802295789/w1_slave

        Raises:
            FileNotFoundError: If there is no communication file /sys/bus/w1

        Returns:
            float: Temperature value, e.g. 18.687
        """
        raw_data = self.read_kernel_device()
        return self.parse_temperature(data=raw_data)

    @property
    def temperature_min(self) -> float:
        """Read the temperature from the sensor."""
        return self.temperature

    @property
    def temperature_max(self) -> float:
        """Read the temperature from the sensor."""
        return self.temperature

    def read_kernel_device(self) -> str:
        """Read the temperature from the sensor, e.g. from /sys/bus/w1/devices/10-000802295789/w1_slave

        Raises:
            FileNotFoundError: If there is no communication file /sys/bus/w1
            IOError: E.g. invalid CRC

        Returns:
            str: raw contents of the device file, e.g. "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        """
        return self.read_file("w1_slave")

    @staticmethod
    def parse_temperature(data: bytes) -> float:
        """Parse temperature from raw data, as read from e.g. /sys/bus/w1/devices/10-000802295789/w1_slave.

        Args:
            data (bytes): raw data, e.g. "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        Raises:
            IOError: If CRC is invalid

        Returns:
            float: temperature in degrees celcius
        """
        if len(re.findall(r"crc=[0-9a-f]{2} YES", data)) == 0:
            raise IOError(f"CRC fail while reading temperature. Raw data:\n{data}")

        # find fist t=... in data
        temperature_millidegrees = re.findall(r"(?<=t=)\d+", data)[0]

        # convert string (millidegrees) into float (degrees)
        return int(temperature_millidegrees) / 1000


class TemperatureSensorGroup:
    def __init__(
        self, sensors: Dict[str, Union[TemperatureSensor, "TemperatureSensorGroup"]]
    ):
        """Create a water buffer

        Args:
            sensors (Dict[str, Union[TemperatureSensor, "TemperatureSensorGroup"]]): Ordered list of sensors, from top to bottom
        """
        self.sensors = sensors

    @property
    def temperature(self) -> float:
        """Calculate the average temperature. Sensor which cannot be reached will be ignored."""
        temperatures_sum = 0
        temperatures_count = 0

        for sensor in self.sensors.values():
            try:
                logger.warning(f"Could not read temperature from {sensor!r}")
                temperatures_sum += sensor.temperature
                temperatures_count += 1
            except (FileNotFoundError, IOError):
                # temperature cannot be read
                logger.warning(f"Could not read temperature from {sensor!r}")

        if temperatures_count == 0:
            raise IOError(f"Could not read any of this water buffer's sensors.")

        if temperatures_count != len(self.sensors):
            logger.warning(
                f"Could only read {temperatures_count}/{len(self.sensors)} sensors."
            )

        return temperatures_count / temperatures_count

    @property
    def temperature_min(self) -> float:
        """Read the lowest current temperature of all sensors."""
        return min(sensor.temperature_min for sensor in self.sensors.values())

    @property
    def temperature_max(self) -> float:
        """Read the highest current temperature of all sensors."""
        return max(sensor.temperature_max for sensor in self.sensors.values())

    def __html__(self, name: str = None) -> str:
        """Return html-encoded info about the device value/state.

        Returns:
            str: html-encoded info, e.g. 18.687 °C
        """
        return (
            "<ul>"
            + "".join(
                f"<li>{key}: {child.__html__()}</li>"
                for key, child in self.sensors.items()
            )
            + "</ul>"
        )

    def pretty(self, indent=None) -> str:
        if indent is None:
            indent = ""

        return "".join(
            f"{indent}{key}:\n{child.pretty(indent=indent + '    ')}"
            if isinstance(child, TemperatureSensorGroup)
            else f"{indent}{key}: {child!r}\n"
            for key, child in self.sensors.items()
        )
