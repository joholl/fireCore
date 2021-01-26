#!/usr/bin/env python3

import contextlib
import os
import uvicorn

from fastapi import FastAPI
import threading
import time
from typing import Optional

app = FastAPI()


# TODO has to be called from ./src: python3 server.py


@app.get("/")
def read_root():
    return {"Hello": "World"}


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
    module_name = os.path.splitext(__file__)[0]
    config = uvicorn.Config(f"{module_name}:app", host="0.0.0.0", port=8000, reload=True, debug=True, workers=3, log_level="info")
    server = Server(config=config)

    with server.run_in_thread():
        while True:
            print("do stuff...")
            time.sleep(1)

