# Performance — 200-planet map, all effects on

Godot 4.7.2-stable (official) · Apple M3 Ultra · macOS
Map: huge (200 planets), 4 bot-driven seats, Sharp, 4× speed, vsync off, 20 s after a 3 s warm-up.

| metric | value |
|---|---|
| frames | 4887 |
| average fps | 244 |
| mean frame | 4.09 ms |
| p95 frame | 7.47 ms |
| p99 frame | 8.57 ms |
| worst frame | 8.97 ms |
| render CPU, mean | 1.22 ms |
| render GPU, mean | 0.00 ms |
| peak fleets in flight | 4774 |
| ticks simulated | 368 |
| sim step, mean | 1.15 ms |
| sim step, worst | 2.29 ms |
| sim share of frame time | 2% |

60 fps holds when p99 < 16.7 ms. Frame times are wall clock, so they include waiting on the GPU;
the GL Compatibility renderer on macOS does not report GPU time separately (it reads 0).
This is a stress test: four Sharp bots at 4× keep thousands of fleets in flight, far more than a human game.
