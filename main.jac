"""Rivus, hosted entrypoint.

JacHammer's supervisor runs `main.jac` from the project root. The investigation lives at
jac/main.jac, which the platform never looks at, so this is the file it boots.

What ships is the static site in `web/`: six pages emitted by jac/pages.jac with the
measured run inlined as replay.js. Nothing is computed per request, so this serves that
directory and nothing else. Regenerating the pages stays an offline step, because a
preview container should not re-solve hydraulics on boot.

The platform's startup probe polls /docs, which a plain file server would 404 on, and a
failed startup probe gets the container killed and restarted until it backs off. So the
probe paths answer 200 here and everything else falls through to the files.
"""

import os;
import from functools { partial }
import from http.server { SimpleHTTPRequestHandler, ThreadingHTTPServer }


class Handler(SimpleHTTPRequestHandler) {
    def do_GET(self: any) -> None {
        # Kept local rather than a module-level glob: a glob does not resolve from inside
        # a class body here, and the lookup failure only shows up as a reset connection.
        probes = ["/docs", "/docs/", "/health", "/healthz", "/_health", "/openapi.json"];
        if self.path in probes {
            body = b"ok";
            self.send_response(200);
            self.send_header("Content-Type", "text/plain; charset=utf-8");
            self.send_header("Content-Length", str(len(body)));
            self.end_headers();
            self.wfile.write(body);
            return;
        }
        SimpleHTTPRequestHandler.do_GET(self);
    }

    def log_message(self: any, fmt: str, *args: any) -> None {
        # Quiet: the default writes a line per asset to stderr and buries the startup
        # output the platform surfaces. Jac has no bare `pass`, so this returns instead.
        return;
    }
}


with entry {
    # The platform hands the port in the environment; 8000 is only the local default.
    port = int(os.environ.get("PORT", "8000"));

    here = os.path.dirname(os.path.abspath(__file__));
    # Not named `root`: that is Jac's graph root reference and cannot be assigned to.
    web_dir = os.path.join(here, "web");
    if not os.path.isdir(web_dir) {
        web_dir = os.path.join(os.getcwd(), "web");
    }

    handler = partial(Handler, directory=web_dir);
    server = ThreadingHTTPServer(("0.0.0.0", port), handler);
    print(f"[rivus] serving {web_dir} on 0.0.0.0:{port}", flush=True);
    server.serve_forever();
}
