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

from ..onewire import OneWire

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


# TODO overview here
@app.get("/")
def read_root():
    list_items = "".join(
        # route.name
        f'<li><a href="{route.path}">{route.path}</li>\n'
        for route in app.routes
    )
    unordered_list = f"<ul>\n{list_items}</ul>\n"
    html = f"<!DOCTYPE html>\n<html>\n<body>\n{unordered_list}</body>\n</html>\n"
    return fastapi.Response(content=html, media_type="text/html")


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


@app.get("/api/log")
def read_item():
    with open("app.log") as f:
        data = "".join(f.readlines())

    return fastapi.Response(content=data, media_type="text/plain")


@app.get("/api/dmesg")
def read_item():
    syslog = subprocess.run(["dmesg"], stdout=subprocess.PIPE).stdout.decode("utf-8")
    return fastapi.Response(content=syslog, media_type="text/plain")


@app.get("/api/syslog")
def read_item():
    return fastapi.responses.RedirectResponse(url="/api/dmesg")


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
