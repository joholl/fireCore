#!/usr/bin/env python3

import contextlib
import fastapi
import logging
import os
import re
import RPi.GPIO as gpio
import subprocess
import threading
import time
import uvicorn

from typing import Optional

logger = logging.getLogger(__name__)

app = fastapi.FastAPI()

# TODO has to be called from ./src: python3 server.py

# TODO PoC... only works as root
gpio.setmode(gpio.BCM)
gpio.setup(17, gpio.OUT)
gpio.output(17, gpio.HIGH)

# TODO overview here?
@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/log")
def read_item():
    with open("app.log") as f:
        data = ''.join(f.readlines())

    return fastapi.Response(content=data, media_type='text/plain')

@app.get("/dmesg")
def read_item():
    syslog = subprocess.run(['dmesg'], stdout=subprocess.PIPE).stdout.decode('utf-8')
    return fastapi.Response(content=syslog, media_type='text/plain')

@app.get("/syslog")
def read_item():
    return fastapi.responses.RedirectResponse(url='/dmesg')

@app.get("/temp")
def read_item():
    devices_path = '/sys/bus/w1/devices/'
    devices_exclude = ['w1_bus_master1']
    sensors = [device for device in os.listdir(devices_path) if device not in devices_exclude]

    response = {}
    raw_data = {}
    for sensor in sensors:
        with open(os.path.join(devices_path, sensor, 'w1_slave')) as f:
            # read data file
            raw_data[sensor] = ''.join(f.readlines())

            # find fist t=... in data and shift comma by three digits
            response[sensor] = int(re.findall('(?<=t=)\d+', raw_data[sensor])[0]) / 1000

    return response


# TODO remove
@app.get("/items/{item_id}")
def read_item(item_id: int, q: Optional[str] = None):
    return {"item_id": item_id, "q": q}


class Server(uvicorn.Server):
    def install_signal_handlers(self):
        pass

    @contextlib.contextmanager
    def run_in_thread(self):
        thread = threading.Thread(target=self.run)
        thread.start()
        try:
            while not self.started:
                time.sleep(1e-3)
            yield
        finally:
            self.should_exit = True
            thread.join()


if __name__ == "__main__":
    # setup logging
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.NOTSET)

    format_str = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    formatter = logging.Formatter(format_str)

    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(logging.NOTSET)
    stream_handler.setFormatter(formatter)
    root_logger.addHandler(stream_handler)

    # TODO /var/log/app.log
    file_handler = logging.handlers.RotatingFileHandler('app.log', delay=True, maxBytes=20000, backupCount=1)
    file_handler.setLevel(logging.NOTSET)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)

    # prepare logging for uvicorn
    log_config = uvicorn.config.LOGGING_CONFIG
    for k, v in log_config["loggers"].items():
        log_config["loggers"][k]["handlers"] = []
        log_config["loggers"][k]["level"] = logging.NOTSET
        log_config["loggers"][k]["propagate"] = True

    # setup http server
    module_name = os.path.splitext(__file__)[0]
    config = uvicorn.Config(f"{module_name}:app", host="0.0.0.0", port=8000, reload=True, workers=3, log_config=log_config)
    server = Server(config=config)

    with server.run_in_thread():
        while True:
            root_logger.info("do stuff...")
            time.sleep(1)

