# sim/

The pure, deterministic game simulation. **No rendering, no I/O, no unseeded randomness.**
Same inputs → same outputs, byte for byte, on every platform. This directory is shared verbatim
by the client (`game/`) and the dedicated server (`server/`).

Populated in Iteration 1. See `docs/SPEC.md` for the rules it implements.
