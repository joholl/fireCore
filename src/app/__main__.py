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

from . import server

logger = logging.getLogger(__name__)

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
    config = uvicorn.Config(f"{server.__name__}:app", host="0.0.0.0", port=8000, reload=True, workers=3, log_config=log_config, loop="asyncio")
    webserver = server.Server(config=config)

    with webserver.run_in_thread():
        while True:
            root_logger.info("do stuff...")
            time.sleep(1)
