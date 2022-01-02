import binascii
import logging
import os
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
            str: Human readable info, e.g. e.g. 18.687 °C
        """
        return f"{self.temperature} °C"

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

    def read_kernel_device(self) -> str:
        """Read the temperature from the sensor, e.g. from /sys/bus/w1/devices/10-000802295789/w1_slave

        Raises:
            FileNotFoundError: If there is no communication file /sys/bus/w1
            IOError: E.g. invalid CRC

        Returns:
            str: raw contents of the device file, e.g. "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        """
        driver_path = "/sys/bus/w1"
        device_path = os.path.join(
            driver_path, "devices", self.address_w1_string, "w1_slave"
        )

        if not os.path.exists(driver_path):
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
        if not os.path.exists(device_path):
            logger.warning(
                f"Path {device_path} does not exist. Is the sensor connected?"
            )

        with open(device_path) as f:
            return "".join(f.readlines())

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
    def __init__(self, sensors: List[TemperatureSensor]):
        """Create a water buffer

        Args:
            sensors ([List[TemperatureSensor]]): Ordered list of sensors, from top to bottom
        """
        self.sensors = sensors

    @property
    def temperature(self) -> float:
        """Calculate the average temperature. Sensor which cannot be reached will be ignored."""
        temperatures_sum = 0
        temperatures_count = 0

        for sensor in self.sensors:
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
