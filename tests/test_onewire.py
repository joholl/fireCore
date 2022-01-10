from typing import NamedTuple, Tuple
from unittest import mock

import pytest

from src.app.onewire import (
    EightPinIOSwitch,
    OneWire,
    State,
    TemperatureSensor,
    TwoPinIOSwitch,
)


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
        driver_data = b"22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            temperature = device.temperature
        assert temperature == 16.812

    def test_temperature_invalid_crc(self):
        driver_data = b"22 00 4b 46 ff ff 0f 10 6a : crc=6b NO"

        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            with pytest.raises(IOError):
                temperature = device.temperature

    def test_temperature_no_w1_driver(self):
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        with mock.patch("os.path.exists", lambda path: False) as mock_file:
            with pytest.raises(FileNotFoundError):
                temperature = device.temperature

    def test_temperature_no_device(self):
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"
        device = TemperatureSensor(address=device_addr)

        existing_paths = "/sys/bus/w1"

        with mock.patch(
            "os.path.exists", lambda path: path in existing_paths
        ) as mock_file:
            with pytest.raises(FileNotFoundError):
                temperature = device.temperature

    def test_str(self):
        driver_data = b"22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812"
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"

        device = TemperatureSensor(address=device_addr)
        with mock.patch(
            "builtins.open", mock.mock_open(read_data=driver_data)
        ) as mock_file:
            assert (
                str(device) == 'TemperatureSensor(address="10-000802295789"): 16.812 °C'
            )

    def test_str_err(self):
        device_addr = b"\x00\x08\x02\x29\x57\x89\x10"

        device = TemperatureSensor(address=device_addr)
        print(str(device))
        assert (
            str(device)
            == "TemperatureSensor(address=\"10-000802295789\"): FileNotFoundError: [Errno 2] No such file or directory: '/sys/bus/w1/devices/10-000802295789/w1_slave'"
        )


class TestTwoPinIOSwitch:
    # def test_read_kernel_device(self):
    #     driver_data = b"\x5a"

    #     device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
    #     device = TwoPinIOSwitch(address=device_addr)

    #     with mock.patch(
    #         "builtins.open", mock.mock_open(read_data=driver_data)
    #     ) as mock_file:
    #         value = device.read_kernel_device()
    #     assert value == 0x5A

    def test_write_kernel_device(self):
        # TODO
        ...

    def test_str(self):
        device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
        test_vectors = {
            b"\xf0": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 driving low',
            b"\xe1": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 driving low',  # not possible, state A cannot be set
            b"\xd2": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (low), P1 driving low',
            b"\xc3": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (high), P1 driving low',
            b"\xb4": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 driving low',  # not possible, state B cannot be set
            b"\xa5": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 driving low',  # not possible, state A and B cannot be set
            b"\x96": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (low), P1 driving low',  # not possible, state B cannot be set
            b"\x87": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (high), P1 driving low',  # not possible, state B cannot be set
            b"\x78": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 open drain (low)',
            b"\x69": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 open drain (low)',  # not possible, state A cannot be set
            b"\x5a": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (low), P1 open drain (low)',
            b"\x4b": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (high), P1 open drain (low)',
            b"\x3c": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 open drain (high)',
            b"\x2d": 'TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 open drain (high)',  # not possible, state A cannot be set
            b"\x1e": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (low), P1 open drain (high)',
            b"\x0f": 'TwoPinIOSwitch(address="3a-000000029895"): P0 open drain (high), P1 open drain (high)',
        }

        device = TwoPinIOSwitch(address=device_addr)

        for driver_data, expected_str in test_vectors.items():
            with mock.patch(
                "builtins.open", mock.mock_open(read_data=driver_data)
            ) as mock_file:
                assert str(device) == expected_str

    @mock.patch("os.path.exists", return_value=lambda _path: True)
    @mock.patch("builtins.open", new_callable=mock.mock_open)
    def test_write(self, mock_open, mock_exists):
        # device_addr = b"\x00\x00\x00\x02\x98\x95\x3a"
        # device = TwoPinIOSwitch(address=device_addr)

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
                    b"22 00 4b 46 ff ff 0f 10 6a : crc=6a YES\n22 00 4b 46 ff ff 0f 10 6a t=16812",
                ),
                info_str='TemperatureSensor(address="10-000802295789"): 16.812 °C',
            ),
            TestVectors(
                addr=b"\x00\x00\x00\x02\x98\x95\x3a",
                path="/sys/bus/w1/devices/3a-000000029895",
                data=(b"\xf0",),
                info_str='TwoPinIOSwitch(address="3a-000000029895"): P0 driving low, P1 driving low',
            ),
            TestVectors(
                addr=b"\x00\x00\x00\x02\x98\x97\x3a",
                path="/sys/bus/w1/devices/3a-000000029897",
                data=(b"\x1e",),
                info_str='TwoPinIOSwitch(address="3a-000000029897"): P0 open drain (low), P1 open drain (high)',
            ),
            TestVectors(
                addr=b"\x00\x08\x02\x29\x56\x90\x10",
                path="/sys/bus/w1/devices/10-000802295690",
                data=(
                    b"22 00 4b 46 ff ff 0f 10 5c : crc=5c YES\n22 00 4b 46 ff ff 0f 10 5c t=22123",
                ),
                info_str='TemperatureSensor(address="10-000802295690"): 22.123 °C',
            ),
            TestVectors(
                addr=b"\x99\xaa\xbb\xcc\xdd\xee\xff",
                path="/sys/bus/w1/devices/ff-99aabbccddee",
                data=(),
                info_str='W1Device(address="ff-99aabbccddee"): Generic onewire slave (family code 0xff)',
            ),
            TestVectors(
                addr=b"\x00\x00\x00\x02\x98\x97\x29",
                path="/sys/bus/w1/devices/29-000000029897",
                # reads state_control (is correct already), output, state
                data=(b"\x04", b"\xf0", b"\xc0"),
                info_str='EightPinIOSwitch(address="29-000000029897"): P0 driving low, P1 driving low, P2 driving low, P3 driving low, P4 open drain (low), P5 open drain (low), P6 open drain (high), P7 open drain (high)',
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
