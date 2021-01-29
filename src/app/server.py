#!/usr/bin/env python3

import contextlib
import fastapi
import logging
import os
import threading
import time
import uvicorn

from typing import Optional

logger = logging.getLogger(__name__)

app = fastapi.FastAPI()


# TODO has to be called from ./src: python3 server.py


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/log")
def read_item():
    return fastapi.responses.FileResponse('app.log')


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
    file_handler = logging.handlers.RotatingFileHandler('app.log', maxBytes=2000, backupCount=10)
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

