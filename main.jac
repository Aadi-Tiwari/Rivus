"""Rivus, hosted entrypoint.

JacHammer's supervisor runs `main.jac` from the project root, which is why it crash
looped: the investigation lives at `jac/main.jac` and nothing answered at the root.

What ships is the static site in `web/`: six pages emitted by `jac/pages.jac`, with the
measured run inlined as `replay.js`. None of it needs a server to compute anything, so
this serves that directory and nothing else. Regenerating the pages is a separate,
offline step (`jac run jac/pages.jac` and `jac run jac/export_web.jac`), deliberately not
run here, because a preview container should not be re-solving hydraulics on boot.
"""

import os;
import from functools { partial }
import from http.server { SimpleHTTPRequestHandler, ThreadingHTTPServer }


with entry {
    # The platform hands the port in the environment; 8000 is only the local default.
    port = int(os.environ.get("PORT", "8000"));

    here = os.path.dirname(os.path.abspath(__file__));
    # Not named `root`: that is Jac's graph root reference and cannot be assigned to.
    web_dir = os.path.join(here, "web");
    if not os.path.isdir(web_dir) {
        web_dir = os.path.join(os.getcwd(), "web");
    }

    handler = partial(SimpleHTTPRequestHandler, directory=web_dir);
    server = ThreadingHTTPServer(("0.0.0.0", port), handler);
    print(f"[rivus] serving {web_dir} on 0.0.0.0:{port}");
    server.serve_forever();
}
