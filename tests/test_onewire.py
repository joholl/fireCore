from typing import NamedTuple, Tuple
from unittest import mock

import pytest

from src.app.onewire import PIO, IOSwitch, OneWire, State, TemperatureSensor

# @pytest.fixture()
# def w1_():
#     temperature_sensor.driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
#     temperature_sensor.addr = b'\x00\x08\x02\x29\x57\x89\x10'

#     with mock.patch("builtins.open", mock.mock_open(read_data=temperature_sensor.driver_data)) as mock_file:
#         existing_paths = ("/sys/bus/w1", "/sys/bus/w1/devices/10-000802295789")
#         with mock.patch("os.path.exists", lambda path: path in existing_paths) as mock_file:
#             yield TemperatureSensor(address=temperature_sensor.addr)


class TestOneWire:
    def test_address_bytes_to_w1_static(self):
        address_bytes = b"\x00\x08\x02\x29\x57\x89\x10"
        address_w1_str = "10-000802295789"

        assert (
            TemperatureSensor.address_bytes_to_w1_string(address_bytes)
            == address_w1_str
        )

    def test_address_w1_to_bytes_static(self):
        address_bytes = b"\x00\x08\x02\x29\x57\x89\x10"
        address_w1_str = "10-000802295789"

        assert (
            TemperatureSensor.address_w1_string_to_bytes(address_w1_str)
            == address_bytes
        )

    def test_address_bytes_to_w1(self):
        address_bytes = b"\x00\x08\x02\x29\x57\x89\x10"
        address_w1_str = "10-000802295789"

        device = TemperatureSensor(address=address_bytes)
        assert device.address == address_bytes
        assert device.address_w1_string == address_w1_str

    def test_address_w1_to_bytes(self):
        address_bytes = b"\x00\x08\x02\x29\x57\x89\x10"
        address_w1_str = "10-000802295789"

        device = TemperatureSensor(address=address_w1_str)
        assert device.address == address_bytes
        assert device.address_w1_string == address_w1_str

    def test_invalid_address_bytes(self):
        address_bytes = b"\x11\x22\x33"

        with pytest.raises(ValueError):
            TemperatureSensor(address=address_bytes)

    def test_invalid_address_w1(self):
        address_w1_str = "abc"

        with pytest.raises(ValueError):
            TemperatureSensor(address=address_w1_str)

    def test_repr(self):
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device_repr = r"TemperatureSensor(address=b'\x00\x08\x02\x29\x57\x89\x10')"

        device = TemperatureSensor(address=device_addr)
        assert f"{device!r}" == device_repr

    def test_eq(self):
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"

        device_a = TemperatureSensor(address=device_addr)
        device_b = TemperatureSensor(address=device_addr)
        assert device_a == device_b

    def test_ne(self):
        device_addr_a = b"\x00\x08\x02\x29\x57\x88\x10"
        device_addr_b = b"\x00\x08\x02\x29\x57\x89\x10"

        device_a = TemperatureSensor(address=device_addr_a)
        device_b = TemperatureSensor(address=device_addr_b)
        assert device_a != device_b


class TestTemperatureSensor:
    def test_parse_temperature(self):
        raw_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        assert TemperatureSensor.parse_temperature(raw_data) == 16.812

    def test_parse_temperature_invalid_crc(self):
        raw_data = (
            "22 00 4b 46 ff ff 0f 10 6b : crc=6b NO\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        )

        with pytest.raises(IOError):
            TemperatureSensor.parse_temperature(raw_data)

    def test_parse_temperature_garbage(self):
        raw_data = "Lorem\nipsum"

        with pytest.raises(IOError):
            TemperatureSensor.parse_temperature(raw_data)

    def test_temperature(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            temperature = device.temperature
        assert temperature == 16.812

    def test_temperature_invalid_crc(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6b NO"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            with pytest.raises(IOError):
                temperature = device.temperature

    def test_temperature_no_w1_driver(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch("os.path.exists", lambda path: False) as mock_file:
            with pytest.raises(FileNotFoundError):
                temperature = device.temperature

    def test_temperature_no_device(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        existing_paths = "/sys/bus/w1"

        with mock.patch(
            "os.path.exists", lambda path: path in existing_paths
        ) as mock_file:
            with pytest.raises(FileNotFoundError):
                temperature = device.temperature

    def test_str(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"

        device = TemperatureSensor(address=device_addr)
        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            assert (
                str(device)
                == r"TemperatureSensor(address=b'\x00\x08\x02\x29\x57\x89\x10'): 16.812 °C"
            )

    def test_str_err(self):
        driver_data = "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"

        device = TemperatureSensor(address=device_addr)
        assert (
            str(device)
            == r"TemperatureSensor(address=b'\x00\x08\x02\x29\x57\x89\x10'): FileNotFoundError: [Errno 2] No such file or directory: '/sys/bus/w1/devices/10-000802295789/w1_slave'"
        )


class TestIOSwitch:
    def test_read_kernel_device(self):
        driver_data = b"\x5a"

        device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
        device = IOSwitch(address=device_addr)

        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            value = device.read_kernel_device()
        assert value == 0x5A

    def test_write_kernel_device(self):
        # TODO
        ...

    def test_str(self):
        device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
        test_vectors = {
            b"\xf0": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB driving low",
            b"\xe1": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB driving low",  # not possible, state A cannot be set
            b"\xd2": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (low), PIOB driving low",
            b"\xc3": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (high), PIOB driving low",
            b"\xb4": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB driving low",  # not possible, state B cannot be set
            b"\xa5": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB driving low",  # not possible, state A and B cannot be set
            b"\x96": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (low), PIOB driving low",  # not possible, state B cannot be set
            b"\x87": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (high), PIOB driving low",  # not possible, state B cannot be set
            b"\x78": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB open drain (low)",
            b"\x69": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB open drain (low)",  # not possible, state A cannot be set
            b"\x5a": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (low), PIOB open drain (low)",
            b"\x4b": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (high), PIOB open drain (low)",
            b"\x3c": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB open drain (high)",
            b"\x2d": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB open drain (high)",  # not possible, state A cannot be set
            b"\x1e": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (low), PIOB open drain (high)",
            b"\x0f": r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA open drain (high), PIOB open drain (high)",
        }

        device = IOSwitch(address=device_addr)

        for driver_data, expected_str in test_vectors.items():
            with mock.patch(
                "builtins.open", mock.mock_open(read_data=driver_data)
            ) as mock_file:
                assert str(device) == expected_str

    @mock.patch("os.path.exists", return_value=lambda _path: True)
    @mock.patch("builtins.open", new_callable=mock.mock_open)
    def test_write(self, mock_class):
        # device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
        # device = IOSwitch(address=device_addr)

        # device.write(pin_a=State.LOW, pin_b=State.HIGH)

        # TODO
        ...


class TestOneWire:
    @mock.patch("os.path.exists", return_value=lambda _path: True)
    @mock.patch("builtins.open", new_callable=mock.mock_open)
    def test_get_devices(self, mock_open, mock_exists):
        class TestVectors(NamedTuple):
            addr: str
            path: str
            data: Tuple[str]
            info_str: str

        test_vectors = (
            TestVectors(
                addr=b"\x00\x08\x02\x29\x57\x89\x10",
                path="/sys/bus/w1/devices/10-000802295789",
                data=(
                    "22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812",
                ),
                info_str=r"TemperatureSensor(address=b'\x00\x08\x02\x29\x57\x89\x10'): 16.812 °C",
            ),
            TestVectors(
                addr=b"\x00\x00\x00\x02\x98\x95\x3a",
                path="/sys/bus/w1/devices/3a-000000029895",
                data=(b"\xf0",),
                info_str=r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x95\x3a'): PIOA driving low, PIOB driving low",
            ),
            TestVectors(
                addr=b"\x00\x00\x00\x02\x98\x97\x3a",
                path="/sys/bus/w1/devices/3a-000000029897",
                # read outputs -> both open drain; then for both PIOA and PIOB: read inputs (read output to assert open drain, read input)
                data=(b"\x1e", b"\x1e", b"\x1e", b"\x1e", b"\x1e"),
                info_str=r"IOSwitch(address=b'\x00\x00\x00\x02\x98\x97\x3a'): PIOA open drain (low), PIOB open drain (high)",
            ),
            TestVectors(
                addr=b"\x00\x08\x02\x29\x56\x90\x10",
                path="/sys/bus/w1/devices/10-000802295690",
                data=(
                    "22 00 4b 46 ff ff 0f 10 5c : crc=5c YES\n22 00 4b 46 ff ff 0f 10 5c t=22123",
                ),
                info_str=r"TemperatureSensor(address=b'\x00\x08\x02\x29\x56\x90\x10'): 22.123 °C",
            ),
            TestVectors(
                addr=b"\x99\xaa\xbb\xcc\xdd\xee\xff",
                path="/sys/bus/w1/devices/ff-99aabbccddee",
                data=(),
                info_str=r"W1Device(address=b'\x99\xaa\xbb\xcc\xdd\xee\xff'): Generic onewire slave (family code 0xff)",
            ),
        )

        # read file system to get all onewire devices
        with mock.patch(
            "os.listdir", lambda _: [t.path.split("/")[-1] for t in test_vectors]
        ) as mock_file:
            devices = OneWire.get_devices()

        # set list of mock values for open/read
        side_effects = []
        for t in test_vectors:
            side_effects.extend(
                mock.mock_open(read_data=d).return_value for d in t.data
            )
        mock_open.side_effect = side_effects

        # read from every device to print info string
        for dev, t in zip(devices, test_vectors):
            assert str(dev) == t.info_str
