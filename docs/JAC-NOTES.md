# Jac notes

Everything the build learned about jaclang the hard way. Versions in use were
jaclang 0.16.7 and byllm 0.6.19 on Windows and macOS.

## Running anything

- Windows needs `PYTHONIOENCODING=utf-8` set, or jac crashes printing its own
  startup banner.
- Run from the repo root with `PYTHONPATH=$PWD`, otherwise the Python modules
  under `py/` are not importable from the walkers.
- **Delete `.jac/` before every run.** Jac persists the graph to disk, so a
  second run silently stacks another copy of the network onto root and every
  count doubles. `rm -rf .jac` on macOS, `Remove-Item -Recurse -Force .jac` on
  Windows.
- Keep `with Root entry` idempotent for the same reason.
- `jac check` reports dozens of errors on files that run perfectly. Ignore it
  and trust `jac run`.
- `jac serve` is now `jac start`.

## Syntax traps, each worth about an hour if rediscovered

- Typed edges use single-dash arrows: `[->:Pipe:->]`, never `-->`.
- Backticks anywhere, including inside a docstring, break the lexer.
- A docstring inside a `def` or `can` body needs a trailing `;`, but an
  archetype-level docstring must not have one.
- Inside a walker, `can` declares an ability and `def` declares a method.
- Assigning to a `glob` inside a scope silently creates a local instead. Mutate
  a dict rather than rebinding the name.
- `disengage` kills the entire walker when you almost always want `skip`.
- Edges have no `.target`. Zip `[edge n ->:Pipe:->]` with `[n ->:Pipe:->]`
  positionally instead.
- `root()` is bare `root`.
- Watch the f-string colon trap: a colon inside an f-string expression is parsed
  as a format spec.

## byLLM

- The return type is always a typed object, never a bare `str`.
- Any tool-calling call needs `max_react_iterations=3`, or it runs hundreds of
  round trips and never returns.
- Wrap every call in try/except with a deterministic parse as the fallback. A
  typed return raises `OutputConversionError` after 3 retries, which is an
  unrecoverable crash at runtime.
