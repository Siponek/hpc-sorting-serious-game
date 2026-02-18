import argparse
import ssl
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class ExportRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    cross_origin_isolation = False
    asset_cache_seconds = 3600

    def end_headers(self):
        self.send_my_headers()
        super().end_headers()

    def send_my_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Accept-Ranges", "bytes")
        if self.cross_origin_isolation:
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")

        request_path = self.path.split("?", 1)[0]
        if request_path.endswith((".wasm", ".pck", ".js", ".css", ".png", ".jpg", ".webp")):
            self.send_header("Cache-Control", f"public, max-age={self.asset_cache_seconds}")
        else:
            self.send_header("Cache-Control", "no-cache")


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
    parser.add_argument(
        "--cross-origin-isolation",
        action="store_true",
        help="Send COEP/COOP headers (only required for threaded SharedArrayBuffer builds)",
    )
    parser.add_argument(
        "--asset-cache-seconds",
        type=int,
        default=3600,
        help="Cache lifetime for large static assets like .pck/.wasm",
    )
    args = parser.parse_args()

    ExportRequestHandler.cross_origin_isolation = args.cross_origin_isolation
    ExportRequestHandler.asset_cache_seconds = max(0, args.asset_cache_seconds)

    with ThreadingHTTPServer((args.bind, args.port), ExportRequestHandler) as httpd:
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
