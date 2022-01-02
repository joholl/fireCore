import binascii
import logging
import os
import re
from enum import IntEnum
from typing import Any, Dict, List, Union

logger = logging.getLogger(__name__)


class W1Device:
    FAMILY_BYTE = None

    def __init__(self, address: Union[bytes, str]):
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

    def __repr__(self) -> str:
        """Debug string, e.g. W1Device(address=b'\x00\x08\x02\x29\x57\x89\x10')."""
        # convert bytes manually to avoid printable ascii chars
        addr_str = r"\x" + r"\x".join(f"{b:02x}" for b in self.address)
        return f"{type(self).__name__}(address=b'{addr_str}')"

    def __str__(self) -> str:
        try:
            value = self.value_info
        except Exception as error:
            value = f"{type(error).__name__}: {error}"
        return f"{self!r}: {value}"

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
