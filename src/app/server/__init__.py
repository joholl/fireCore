#!/usr/bin/env python3

import contextlib
import importlib
import logging
import os
import re
import subprocess
import threading
import time
from typing import Optional

import fastapi
import uvicorn
from fastapi.staticfiles import StaticFiles
from starlette.responses import RedirectResponse

from ..control.devices import Control
from ..onewire import OneWire, W1Device

app = fastapi.FastAPI()


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


static_path = os.path.join(os.path.dirname(__file__), "../static")
app.mount("/static", StaticFiles(directory=static_path), name="static")


@app.get("/")
def read_root():
    return RedirectResponse(url="static/index.html")


@app.get("/api/w1-sensors")
def device_sensors_list_html_urls():
    return {
        name: f"/html/w1/{sensor.address_w1_string}"
        for name, sensor in Control().sensors.items()
    }


@app.get("/api/w1-actors")
def device_actors_list_html_urls():
    return {
        name: f"/html/w1/{actor.address_w1_string}"
        for name, actor in Control().actors.items()
    }


@app.get("/api/w1-unknown")
def device_unknown_list_html_urls():
    return {
        f"Unknown device": f"/html/w1/{dev.address_w1_string}"
        for dev in Control().unknown()
    }


@app.get("/html/w1/{address_w1_string}")
def device_get_html(address_w1_string: str, name: str = None):
    return fastapi.Response(
        content=OneWire.device_from_address(address_w1_string).__html__(name=name),
        media_type="text/html",
    )


@app.get("/api/w1/{address_w1_string}/switch")
def actor_switch_pin(address_w1_string: str, pin: int, state: int):
    OneWire.device_from_address(address_w1_string).write(pins={pin: state})
    return {pin: state}


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
    return fastapi.Response(content=html, media_type="text/html")


@app.get("/api/run")
def read_item(cmd: str):
    child = subprocess.Popen(
        cmd.split(" "), stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    stdout, stderr = child.communicate()
    return {"stdout": stdout, "stderr": stderr, "return_code": child.returncode}


# TODO rm?
@app.get("/api/log")
def read_item():
    with open("app.log") as f:
        data = "".join(f.readlines())

    return fastapi.Response(content=data, media_type="text/plain")


# TODO rm?
@app.get("/api/dmesg")
def read_item():
    syslog = subprocess.run(["dmesg"], stdout=subprocess.PIPE).stdout.decode("utf-8")
    return fastapi.Response(content=syslog, media_type="text/plain")


# TODO rm?
@app.get("/api/uptime")
def read_item():
    uptime = subprocess.run(["uptime"], stdout=subprocess.PIPE).stdout.decode("utf-8")
    return fastapi.Response(content=uptime, media_type="text/plain")


@app.get("/api/w1")
def read_item():
    return {dev.address_w1_string: str(dev) for dev in OneWire.get_devices()}


# TODO remove
@app.get("/api/items/{item_id}")
def read_item(item_id: int, q: Optional[str] = None):
    return {"item_id": item_id, "q": q}
