# Scratch

Throwaway probes from the build, kept for history. **None of these run in this
repository.** They were written against a different module layout, where
`hydraulics` was a Python module exposing `run()` and a no-argument
`topology()`. Here `jac/hydraulics.jac` is Jac and `topology()` takes an
`inp_path`, so every file in this folder fails at import.

Nothing in `jac/` or `web/` imports them. The live test suite is
`jac/test_pipetrace.jac`.
