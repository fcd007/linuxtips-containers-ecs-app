from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import math
import os
import socket

HOST = "0.0.0.0"
PORT = 8080

CPU_ITERATIONS = 50_000_000

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        result = 0.0

        for i in range(1, CPU_ITERATIONS + 1):
            result += math.sqrt(i) * math.sin(i) * math.cos(i)

        body = (
            f"ECS Linuxtips ativo recurso UP\n"
            f"hostname={socket.gethostname()}\n"
            f"pid={os.getpid()}\n"
            f"cpu_iterations={CPU_ITERATIONS}\n"
        ).encode()

        self.send_response(200)
        self.send_header(
            "Content-Type",
            "text/plain; charset=utf-8"
        )
        self.send_header(
            "Content-Length",
            str(len(body))
        )
        self.send_header(
            "Connection",
            "close"
        )

        self.end_headers()

        self.wfile.write(body)

    def log_message(self, format, *args):
        print(format % args, flush=True)


server = ThreadingHTTPServer(
    (HOST, PORT),
    Handler
)

print(
    f"CPU intensive server listening on {HOST}:{PORT}",
    flush=True
)

server.serve_forever()