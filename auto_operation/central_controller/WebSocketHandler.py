import socket
import subprocess
import threading
import queue
from typing import IO


# WebSocket で Raspberry Pi と通信する。websocat が必要。
class WebSocketHandler:
    # サーバとして受信開始する
    @staticmethod
    def serve(port: int):
        process = subprocess.Popen(
            ["websocat", "-s", f"{port}"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            # stderr=subprocess.PIPE,
        )
        return WebSocketHandler(process)

    # クライアントとして接続する
    @staticmethod
    def connect(hostname: str, port: int):
        # raspberrypi.local だとエラーになる場合があるので、IP アドレスに変換する。
        raspi_ipaddr = socket.gethostbyname(hostname)
        process = subprocess.Popen(
            ["websocat", "-v", f"ws://{raspi_ipaddr}:{port}"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            # stderr=subprocess.PIPE,
        )
        return WebSocketHandler(process)

    def __init__(self, process: subprocess.Popen) -> None:
        self.process = process

        def enqueue_output(out: IO[bytes], queue: queue.Queue):
            while True:
                line = out.readline()
                queue.put(line)

        self.queue = queue.Queue()
        self.thread = threading.Thread(target=enqueue_output, args=(self.process.stdout, self.queue))
        self.thread.daemon = True  # 自プロセスが◯んだときにこいつも◯す
        self.thread.start()

    def available(self):
        return not self.queue.empty()

    def readline(self):
        return self.queue.get()

    def write(self, data: bytes):
        self.process.stdin.write(data + b"\n")
        self.process.stdin.flush()
