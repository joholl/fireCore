import binascii
import logging
import os
import platform
import re
from enum import IntEnum
from typing import Any, Dict, List, Optional, Union

from ..util.cache import cached

logger = logging.getLogger(__name__)


class W1DeviceSimulator:
    def read(self, path: str) -> bytes:
        ...

    def write(self, path: str, value: bytes) -> None:
        ...


class W1Device:
    FAMILY_BYTE = None

    def __init__(
        self, address: Union[bytes, str], simulator: Optional[W1DeviceSimulator] = None
    ):
        """Create a onewire device.

        Args:
            address (bytes): 7-byte address without CRC
        """
        if isinstance(address, str):
            address = self.address_w1_string_to_bytes(address)
        if len(address) != 7:
            raise ValueError(f"Passed an address with a length != 7 bytes: {address}")
        if type(self) != W1Device and address[-1] != self.FAMILY_BYTE:
            raise ValueError(
                f"Passed address with invalid family byte: address[-1] is {address[-1]} but expected {self.FAMILY_BYTE}"
            )
        self.address = address
        self.simulator = simulator

    @property
    def address_w1_string(self) -> str:
        """Get onewire address as a w1 string, e.g. "10-000802295789."

        Returns:
            str: Address as a w1 string, e.g. "10-000802295789"
        """
        return self.address_bytes_to_w1_string(self.address)

    @property
    def value_info(self) -> str:
        """Return human readable info about the device value/state.

        Returns:
            str: Human readable info
        """
        return f"Generic onewire slave (family code 0x{self.address[-1]:02x})"

    def __eq__(self, other: Any) -> bool:
        """Devices are equal if their addresses are equal."""
        if not isinstance(other, W1Device):
            return False
        return self.address == other.address

    def __hash__(self) -> int:
        """Devices are equal if their addresses are equal."""
        return hash(self.address)

    def __repr__(self) -> str:
        """Debug string, e.g. W1Device(address=b'\x00\x08\x02\x29\x57\x89\x10')."""
        # convert bytes manually to avoid printable ascii chars
        # alternative: addr_str = r"\x" + r"\x".join(f"{b:02x}" for b in self.address)
        return f'{type(self).__name__}(address="{self.address_w1_string}")'

    def __str__(self) -> str:
        try:
            value = self.value_info
        except Exception as error:
            logger.exception("Exception during str(<onewire device>)")
            value = f"{type(error).__name__}: {error}"
        return f"{self!r}: {value}"

    def __html__(self, name: str = None) -> str:
        return str(self)

    @cached(from_cache_by_default=False)
    def read_file(self, filename: str) -> Union[str, bytes]:
        """Read from a driver file, e.g. from /sys/bus/w1/devices/10-000802295789/w1_slave

        Raises:
            FileNotFoundError: If there is no communication file /sys/bus/w1
            IOError: E.g. invalid CRC

        Returns:
            Union[int, bytes str]: Contents of the device file. If only one byte, converted to an int. If unicode, str, else bytes.
        """
        driver_path = "/sys/bus/w1"
        device_path = os.path.join(
            driver_path, "devices", self.address_w1_string, filename
        )

        if not os.path.exists(driver_path) and not self.simulator:
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module loaded?"
            )
        if not os.path.exists(device_path) and not self.simulator:
            logger.warning(
                f"Path {device_path} does not exist. Is the device connected?"
            )

        logger.debug(f"Read from driver file {device_path}...")
        if not self.simulator:
            with open(device_path, "rb") as f:
                result = f.read()
        else:
            result = self.simulator.read(path=device_path)

        if len(result) == 1:
            return result[0]

        try:
            result = result.decode()
        except UnicodeDecodeError:
            pass

        return result

    @cached(from_cache_by_default=False)
    def write_file(self, value: Union[int, bytes, str], filename: str) -> None:
        """Write to a driver file, e.g. to /sys/bus/w1/devices/3a-000000029895/output

        Args:
            value (Union[int, bytes, str]): value to write (int is converted to a single byte)

        Raises:
            FileNotFoundError: If there is no such file
        """
        driver_path = "/sys/bus/w1"
        device_path = os.path.join(
            driver_path, "devices", self.address_w1_string, filename
        )

        if not os.path.exists(driver_path) and not self.simulator:
            logger.warning(
                f"Path {driver_path} does not exist. Is the kernel module w1-gpio loaded?"
            )
        if not os.path.exists(device_path) and not self.simulator:
            logger.warning(
                f"Path {device_path} does not exist. Is the switch connected?"
            )

        if isinstance(value, int):
            if not 0 <= value <= 255:
                raise ValueError(f"Single-byte int to write out of range: {value}")
            value = bytes([value])

        if isinstance(value, str):
            value = value.encode()

        logger.debug(f"Write to driver file {device_path}: {value}")
        if not self.simulator:
            with open(device_path, "wb") as f:
                f.write(value)
        else:
            result = self.simulator.write(path=device_path, value=value)

    @staticmethod
    def address_bytes_to_w1_string(address: bytes) -> str:
        """Convert a 7-bytes onewire address to its w1 string, e.g. "10-000802295789"

        Args:
            address (bytes): 6-bytes onewire address, e.g. b'\x00\x08\x02\x29\x57\x89\x10'

        Returns:
            str: Address as w1 string, e.g. "10-000802295789"
        """
        address_hex = binascii.hexlify(address).decode()
        return f"{address_hex[-2:]}-{address_hex[0:-2]}"

    @staticmethod
    def address_w1_string_to_bytes(address: str) -> bytes:
        """Convert a w1 onewire address to its 6-bytes representation, e.g. b'\x00\x08\x02\x29\x57\x89\x10'

        Args:
            address (bytes): 7-bytes onewire address, e.g. "10-000802295789"

        Returns:
            str: Address as w1 string, e.g. b'\x00\x08\x02\x29\x57\x89\x10'
        """
        return binascii.unhexlify(address[3:]) + binascii.unhexlify(address[0:2])
