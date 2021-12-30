#!/usr/bin/env python3

import contextlib
import fastapi
import importlib
import logging
import os
import re
import subprocess
import threading
import time
import uvicorn

from typing import Optional

logger = logging.getLogger(__name__)

app = fastapi.FastAPI()

class ModuleStub:
    def __getattribute__(self, _attr):
        return self

    def __call__(self, *args):
        return self

try:
    import RPi.GPIO as gpio
except ModuleNotFoundError:
    gpio = ModuleStub()

# TODO PoC... only works as root
gpio.setmode(gpio.BCM)
gpio.setup(17, gpio.OUT)
gpio.output(17, gpio.HIGH)

# TODO overview here
@app.get("/")
def read_root():
    list_items = ''.join(
        # route.name
        f'<li><a href="{route.path}">{route.path}</li>\n'
        for route in app.routes
    )
    unordered_list = f"<ul>\n{list_items}</ul>\n"
    html = f"<!DOCTYPE html>\n<html>\n<body>\n{unordered_list}</body>\n</html>\n"
    return fastapi.Response(content=html, media_type='text/html')

@app.get("/sh")
def read_item():
    form = f"""
        <form action="/api/run" method="get" target="_blank">
            <label for="cmd">Command: </label>
            <input type="text" id="cmd" name="cmd">
            <input type="submit" value="Submit">
        </form>
    """
    html = f"<!DOCTYPE html>\n<html>\n<body>\n{form}</body>\n</html>\n"
    return fastapi.Response(content=html, media_type='text/html')

@app.get("/api/run")
def read_item(cmd: str):
    child = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = child.communicate()
    return {"stdout": stdout, "stderr": stderr, "return_code": child.returncode}

@app.get("/api/log")
def read_item():
    with open("app.log") as f:
        data = ''.join(f.readlines())

    return fastapi.Response(content=data, media_type='text/plain')

@app.get("/api/dmesg")
def read_item():
    syslog = subprocess.run(['dmesg'], stdout=subprocess.PIPE).stdout.decode('utf-8')
    return fastapi.Response(content=syslog, media_type='text/plain')

@app.get("/api/syslog")
def read_item():
    return fastapi.responses.RedirectResponse(url='/api/dmesg')

@app.get("/api/uptime")
def read_item():
    uptime = subprocess.run(['uptime'], stdout=subprocess.PIPE).stdout.decode('utf-8')
    return fastapi.Response(content=uptime, media_type='text/plain')

@app.get("/api/temp")
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
@app.get("/api/items/{item_id}")
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

    # TODO logs UTC, not local time
    format_str = '%(asctime)s UTC - %(name)s - %(levelname)s - %(message)s'
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
    module_name = os.path.splitext(os.path.basename(__file__))[0]
    config = uvicorn.Config(f"{module_name}:app", host="0.0.0.0", port=8000, reload=True, workers=3, log_config=log_config, loop="asyncio")
    server = Server(config=config)

    with server.run_in_thread():
        while True:
            root_logger.info("do stuff...")
            time.sleep(1)
