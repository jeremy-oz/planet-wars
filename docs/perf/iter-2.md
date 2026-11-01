# Performance — 200-planet map, all effects on

Godot 4.7.2-stable (official) · Apple M3 Ultra · macOS
Map: huge (200 planets), 4 bot-driven seats, Sharp, 4× speed, vsync off, 20 s after a 3 s warm-up.

| metric | value |
|---|---|
| frames | 4879 |
| average fps | 244 |
| mean frame | 4.10 ms |
| p95 frame | 7.47 ms |
| p99 frame | 8.62 ms |
| worst frame | 9.46 ms |
| render CPU, mean | 1.20 ms |
| render GPU, mean | 0.00 ms |
| peak fleets in flight | 4774 |
| ticks simulated | 368 |
| sim step, mean | 1.15 ms |
| sim step, worst | 2.95 ms |
| sim share of frame time | 2% |

60 fps holds when p99 < 16.7 ms.
