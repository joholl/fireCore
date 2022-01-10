from typing import List

from ..onewire import (
    EightPinIOSwitch,
    OneWire,
    TemperatureSensor,
    TemperatureSensorGroup,
    TwoPinIOSwitch,
    W1Device,
)

# Finden im csv: (?<=16,).*,0
# Umwandeln csv zu python bytes: fn = lambda *args: print(''.join(r"\x" + f"{b:02x}" for b in args[::-1]))


WOOD_FURNACE_CIRCUIT = "Holzofen Heizkreis"
WOOD_FURNACE_SUPPLY_FLOW = "Holzofen Vorlauf"
WOOD_FURNACE_RETURN_FLOW = "Holzofen Rücklauf"

BUFFERS = "Puffer"
BUFFER_1 = "Puffer 1"
BUFFER_1_1 = "Puffer 1.1"
BUFFER_1_2 = "Puffer 1.2"
BUFFER_1_3 = "Puffer 1.3"
BUFFER_1_4 = "Puffer 1.4"
BUFFER_2 = "Puffer 2"
BUFFER_2_1 = "Puffer 2.1"
BUFFER_2_2 = "Puffer 2.2"
BUFFER_2_3 = "Puffer 2.3"
BUFFER_2_4 = "Puffer 2.4"
# BUFFER_3 = "Puffer 3"

BOILERS = "Boiler"
BOILERS_1 = "Boiler 1"
BOILERS_1_1 = "Boiler 1.1"
BOILERS_2 = "Boiler 2"
BOILERS_2_1 = "Boiler 2.1"
BOILERS_2_2 = "Boiler 2.2"

HEATING_CIRCUIT = "Heizkreis"
HEATING_CIRCUIT_SUPPLY_FLOW = "Heizkreis Vorlauf"
HEATING_CIRCUIT_SUPPLY_FLOW_1 = "Heizkreis Vorlauf 1"
HEATING_CIRCUIT_RETURN_FLOW = "Heizkreis Rücklauf"
HEATING_CIRCUIT_RETURN_FLOW_2 = "Heizkreis Rücklauf 2"

OUTSIDE_TEMPERATURE = "Außenfühler"
OUTSIDE_TEMPERATURE_1 = "Außenfühler 1"

OIL_FURNACE = "Ölofen"
OIL_FURNACE_1 = "Ölofen 1"

SOLAR_PANELS = "Solar Panels"
SOLAR_PANELS_1 = "Solar Panels 1"
SOLAR_PANELS_2 = "Solar Panels 2"
SOLAR_PANELS_3 = "Solar Panels 3"
SOLAR_PANELS_4 = "Solar Panels 4"
SOLAR_PANELS_5 = "Solar Panels 5"
SOLAR_PANELS_6 = "Solar Panels 6"


class Control:
    def __init__(self):
        self.sensors = {
            OUTSIDE_TEMPERATURE_1: TemperatureSensor(
                address=b"\x00\x08\x02\x29\x57\x89\x10"
            ),
        }

        self.actors = {
            "My EightPinIOSwitch": EightPinIOSwitch(
                address=b"\x00\x00\x00\x08\x69\xe8\x29"
            ),
            "My TwoPinIOSwitch": TwoPinIOSwitch(
                address=b"\x00\x00\x00\x02\x98\x95\x3a"
            ),
        }

        # self.sensors = TemperatureSensorGroup(
        #     sensors={
        #         WOOD_FURNACE_CIRCUIT: TemperatureSensorGroup(
        #             sensors={
        #                 WOOD_FURNACE_SUPPLY_FLOW: TemperatureSensor(
        #                     address=b"\x00\x08\x01\xe1\xaa\x1a\x10"
        #                 ),
        #                 WOOD_FURNACE_RETURN_FLOW: TemperatureSensor(
        #                     address=b"\x00\x08\x01\xe1\xa3\x5d\x10"
        #                 ),
        #             }
        #         ),
        #         BUFFERS: TemperatureSensorGroup(
        #             sensors={
        #                 BUFFER_1: TemperatureSensorGroup(
        #                     sensors={
        #                         BUFFER_1_1: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe3\x7b\x0d\x10"
        #                         ),
        #                         BUFFER_1_2: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe3\x75\x96\x10"
        #                         ),
        #                         BUFFER_1_3: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe3\x9c\x76\x10"
        #                         ),
        #                         BUFFER_1_4: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe3\x54\x81\x10"
        #                         ),
        #                         # BUFFER_1_5: TemperatureSensor(address=),
        #                     }
        #                 ),
        #                 BUFFER_2: TemperatureSensorGroup(
        #                     sensors={
        #                         BUFFER_2_1: TemperatureSensor(
        #                             address=b"\x00\x08\x02\xc3\x91\xa5\x10"
        #                         ),
        #                         BUFFER_2_2: TemperatureSensor(
        #                             address=b"\x00\x08\x02\xc3\xe1\xf3\x10"
        #                         ),
        #                         BUFFER_2_3: TemperatureSensor(
        #                             address=b"\x00\x08\x02\xc3\x46\x6a\x10"
        #                         ),
        #                         BUFFER_2_4: TemperatureSensor(
        #                             address=b"\x00\x08\x02\xc3\xa9\xe0\x10"
        #                         ),
        #                         # BUFFER_2_5: TemperatureSensor(address=),
        #                     }
        #                 ),
        #                 # BUFFER_3: TemperatureSensorGroup(
        #                 #     sensors={
        #                 #         # TODO
        #                 #     }
        #                 # ),
        #             }
        #         ),
        #         BOILERS: TemperatureSensorGroup(
        #             sensors={
        #                 BOILERS_1: TemperatureSensorGroup(
        #                     sensors={
        #                         BOILERS_1_1: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe1\x82\xf6\x10"
        #                         ),
        #                     }
        #                 ),
        #                 BOILERS_2: TemperatureSensorGroup(
        #                     sensors={
        #                         BOILERS_2_1: TemperatureSensor(
        #                             address=b"\x00\x08\x02\x1d\x84\x73\x10"
        #                         ),
        #                         BOILERS_2_2: TemperatureSensor(
        #                             address=b"\x00\x08\x02\xc3\x8f\x52\x10"
        #                         ),
        #                     }
        #                 ),
        #             }
        #         ),
        #         HEATING_CIRCUIT: TemperatureSensorGroup(
        #             sensors={
        #                 HEATING_CIRCUIT_SUPPLY_FLOW: TemperatureSensorGroup(
        #                     sensors={
        #                         HEATING_CIRCUIT_SUPPLY_FLOW_1: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xdd\x5c\xe2\x10"
        #                         ),
        #                     }
        #                 ),
        #                 HEATING_CIRCUIT_RETURN_FLOW: TemperatureSensorGroup(
        #                     sensors={
        #                         HEATING_CIRCUIT_RETURN_FLOW_2: TemperatureSensor(
        #                             address=b"\x00\x08\x01\xe3\x8c\x7e\x10"
        #                         ),
        #                     }
        #                 ),
        #             }
        #         ),
        #         OUTSIDE_TEMPERATURE: TemperatureSensorGroup(
        #             sensors={
        #                 OUTSIDE_TEMPERATURE_1: TemperatureSensor(
        #                     address=b"\x00\x08\x01\xe1\x5e\x9b\x10"
        #                 ),
        #             }
        #         ),
        #         OIL_FURNACE: TemperatureSensorGroup(
        #             sensors={
        #                 OIL_FURNACE_1: TemperatureSensor(
        #                     address=b"\x00\x08\x01\xe1\x8f\x5d\x10"
        #                 ),
        #             }
        #         ),
        #         SOLAR_PANELS: TemperatureSensorGroup(
        #             sensors={
        #                 SOLAR_PANELS_1: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x21\x91\x10"
        #                 ),
        #                 SOLAR_PANELS_2: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x68\x09\x10"
        #                 ),
        #                 SOLAR_PANELS_3: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x39\x77\x10"
        #                 ),
        #                 SOLAR_PANELS_4: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x79\x35\x10"
        #                 ),
        #                 SOLAR_PANELS_5: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x9b\xed\x10"
        #                 ),
        #                 SOLAR_PANELS_6: TemperatureSensor(
        #                     address=b"\x00\x08\x02\x29\x11\xae\x10"
        #                 ),
        #             }
        #         ),
        #     }
        # )

        # Relais_8IO Chip 2.1       \x00\x00\x00\x08\x67\x34\x29
        # DCF77_8IO Chip 2.2        \x00\x00\x00\x08\x65\x8b\x29
        # Solar_8IO Chip 2.3        \x00\x00\x00\x08\x60\xe5\x29
        # not used _8IO Chip 2.4    \x00\x00\x00\x08\x6b\xb7\x29

        # Ausgabe 2I Chip 3.1       \x00\x00\x00\x02\xae\xc4\x3A

    def unknown(self) -> List[W1Device]:
        devices = OneWire.get_devices()
        return [
            dev
            for dev in devices
            if dev not in self.sensors.values() and dev not in self.actors.values()
        ]
