import argparse
import ssl
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class HTTPServer(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_my_headers()
        super().end_headers()

    def send_my_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Serve web export for LAN testing")
    parser.add_argument("--bind", default="0.0.0.0", help="Bind address")
    parser.add_argument("--port", type=int, default=8000, help="Port")
    parser.add_argument(
        "--https",
        action="store_true",
        help="Enable HTTPS (required for secure context on LAN)",
    )
    parser.add_argument(
        "--certfile",
        default="",
        help="Path to TLS certificate PEM file",
    )
    parser.add_argument(
        "--keyfile",
        default="",
        help="Path to TLS private key PEM file",
    )
    args = parser.parse_args()

    with ThreadingHTTPServer((args.bind, args.port), HTTPServer) as httpd:
        scheme = "http"
        if args.https:
            script_dir = Path(__file__).resolve().parent
            cert_path = (
                Path(args.certfile) if args.certfile else script_dir / "certs" / "lan-cert.pem"
            )
            key_path = Path(args.keyfile) if args.keyfile else script_dir / "certs" / "lan-key.pem"

            if not cert_path.exists():
                raise FileNotFoundError(f"Certificate file not found: {cert_path}")
            if not key_path.exists():
                raise FileNotFoundError(f"Key file not found: {key_path}")

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
            httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
            scheme = "https"

        print(f"[WEB] Serving on {scheme}://{args.bind}:{args.port}")
        httpd.serve_forever()
