# 2‑Way Set‑Associative Cache (SystemVerilog + SystemC Testbench)

This project implements a configurable 2‑way set‑associative cache in SystemVerilog with a SystemC/Verilator-based testbench. You can simulate the cache’s behavior, visualize waveforms, and measure hit/miss statistics.

---

## Features

* **Configurable parameters**:

  * `BLOCK_SIZE` (bytes per block)
  * `NUM_SETS` (number of cache sets)
  * `NUM_WAYS` (associativity)
  * `ADDR_WIDTH`, `DATA_WIDTH`
* **Write‑back, write‑allocate** policy with dirty bits.
* **LRU replacement**.
* **Testbench** in C++/SystemC using Verilator:

  * C++ memory model (unordered\_map)
  * Automatic checking of data, hit/miss counts
  * VCD waveform dump for GTKWave

---

## Build & Run

1. **Create build directory**:

   ```bash
   mkdir build
   cd build
   ```

2. **Configure with CMake**:

   ```bash
   cmake -G Ninja ..
   ```

3. **Compile**:

   ```bash
   ninja
   ```

4. **Run the testbench**:

   ```bash
   ./Vtop_cache_tb    # runs SystemC/Verilator simulation
   ```

   * Will print pass/fail messages and cache statistics.
   * Generates `Vtop_cache_tb.vcd` for viewing waveform.

5. **View waveforms** (in GTKWave):

   ```bash
   gtkwave Vtop_cache_tb.vcd
   ```

---

---

## How It Works

1. **Address decoding**: split `addr` into `tag | index | offset`.
2. **Tag and data arrays** store two ways per set.
3. **Controller** handles:

   * `IDLE` (decide if servicing memory needed for cache request)
   * `WRITEBACK` (evict dirty block)
   * `MISS` (fetch new block)
4. **LRU**: one bit per set to pick eviction candidate.
5. **SystemC testbench** drives read/write, services memory, and verifies data and hit/miss behavior.