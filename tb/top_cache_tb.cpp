#include <systemc.h>
#include <verilated.h>
#include <verilated_vcd_sc.h>
#include "Vtop_cache.h"
#include <iostream>
#include <unordered_map>
#include <memory>
#include <cstdint>

void waitForReady(
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
);

void performRead(
    uint32_t addr_val,
    uint32_t expected_data,
    const char* msg,
    sc_signal<uint32_t>& addr,
    sc_signal<bool>& read_en,
    sc_signal<uint32_t>& read_data,
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
);

void performWrite(
    uint32_t addr_val,
    uint32_t data_val,
    const char* msg,
    sc_signal<uint32_t>& addr,
    sc_signal<uint32_t>& write_data,
    sc_signal<bool>& write_en,
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
);

int sc_main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    // Signals
    sc_clock clk{"clk", 10, SC_NS}; // 10ns period clock
    sc_signal<bool> rst;
    sc_signal<bool> read_en;
    sc_signal<bool> write_en;
    sc_signal<uint32_t> addr;
    sc_signal<uint32_t> write_data;
    sc_signal<uint32_t> read_data;
    sc_signal<bool> hit;
    sc_signal<bool> ready;
    sc_signal<bool> mem_read;
    sc_signal<bool> mem_write;
    sc_signal<uint32_t> mem_addr;
    sc_signal<uint32_t> mem_wdata;
    sc_signal<uint32_t> mem_rdata;
    sc_signal<bool> mem_ready; // Memory ready to do a read/write
    sc_signal<uint32_t> hit_count;
    sc_signal<uint32_t> miss_count;

    // Instantiate Verilated model
    auto cache = std::make_unique<Vtop_cache>("cache");
    std::unordered_map<uint32_t, uint32_t> memory;

    // Connect signals to ports in top_cache module
    cache->clk(clk);
    cache->rst(rst);
    cache->read_en(read_en);
    cache->write_en(write_en);
    cache->addr(addr);
    cache->write_data(write_data);
    cache->read_data(read_data);
    cache->hit(hit);
    cache->ready(ready);
    cache->mem_read(mem_read);
    cache->mem_write(mem_write);
    cache->mem_addr(mem_addr);
    cache->mem_wdata(mem_wdata);
    cache->mem_rdata(mem_rdata);
    cache->mem_ready(mem_ready);
    cache->hit_count(hit_count);
    cache->miss_count(miss_count);

    // Reset signals
    rst = 1; 
    read_en = 0; 
    write_en = 0;
    addr = 0; 
    write_data = 0;
    mem_rdata = 0;
    mem_ready = 0;
    sc_start(0, SC_NS); // Push initial values

    // Enable waveform tracing
    VerilatedVcdSc* trace = new VerilatedVcdSc();
    cache->trace(trace, 99);
    trace->open("Vtop_cache_tb.vcd");

    // Apply reset for one cycle, then release
    sc_start(10, SC_NS); 
    rst = 0; 
    sc_start(10, SC_NS);

    // Tests
    // Preload main memory at 0x1000 then read the contents to verify
    memory[0x1000] = 0xAAAA1111;
    performRead(0x1000, 0xAAAA1111, "Read 0x1000 after fetch", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    // Hit on re-read
    performRead(0x1000, 0xAAAA1111, "Read 0x1000 re-read", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // Write hit
    performWrite(0x1000, 0xAAAAFFFF, "Write 0x1000 updated", addr, write_data, write_en, ready,
                 mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    performRead(0x1000, 0xAAAAFFFF, "Read 0x1000 updated value", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // Write miss
    performWrite(0x2000, 0xBBBB2222, "Write 0x2000 (miss)", addr, write_data, write_en, ready,
                 mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    performRead(0x2000, 0xBBBB2222, "Read 0x2000 after write", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // 0x1000 should still remain in cache since write/read to 0x2000 would take up the second way in the set
    performRead(0x1000, 0xAAAAFFFF, "Read 0x1000 after read/write to other way in its set", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // Fill new block in same set and cause eviction
    memory[0x3000] = 0xCCCC3333;
    performRead(0x3000, 0xCCCC3333, "Read 0x3000 (fill set and evict based on lru)", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    // Check LRU victim still holds 0xBBBB2222
    performRead(0x2000, 0xBBBB2222, "Read 0x2000 (check LRU victim)", addr, read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // Test a different set, no conflict
    performWrite(0x4000, 0xCCCC4444, "Write 0x4000 (new set)", addr,
                 write_data, write_en, ready,
                 mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    performRead(0x4000, 0xCCCC4444, "Read 0x4000 (should hit)", addr,
                read_en, read_data, ready,
                mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);

    // Cleanup
    cache->final();
    trace->flush();
    trace->close();
    delete trace;

    // Summarize results
    std::cout << "\n Cache Statistics" << std::endl;
    std::cout << "Total Hits   : " << hit_count.read() << std::endl;
    std::cout << "Total Misses : " << miss_count.read() << std::endl;
    uint32_t total = hit_count.read() + miss_count.read();
    double hitrate = (total > 0) ? (100.0 * hit_count.read() / total) : 0.0;
    std::cout << "Cache Hit Rate: " << hitrate << "%" << std::endl;

    if (hitrate < 50) {
        std::cerr << "FAIL: Cache hit rate too low... (" << hitrate << "%)" << std::endl;
        return 1;
    } else {
        std::cout << "PASS: Cache hit rate acceptable" << std::endl;
    }

    return 0;
}

void waitForReady(
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
) {
    while (!ready.read()) {
        if (mem_read.read()) {
            mem_rdata = memory[mem_addr.read()];
            mem_ready = 1;
        }
        if (mem_write.read()) {
            memory[mem_addr.read()] = mem_wdata.read();
            mem_ready = 1;
        }
        sc_start(10, SC_NS);
        mem_ready = 0;
        sc_start(10, SC_NS);
    }
}

void performRead(
    uint32_t addr_val,
    uint32_t expected_data,
    const char* msg,
    sc_signal<uint32_t>& addr,
    sc_signal<bool>& read_en,
    sc_signal<uint32_t>& read_data,
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
) {
    addr = addr_val;
    read_en = 1;
    sc_start(10, SC_NS);
    waitForReady(ready, mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    read_en = 0;
    sc_start(10, SC_NS);
    uint32_t actual = read_data.read();
    if (actual != expected_data) {
        std::cerr << msg << " FAILED: expected 0x" << std::hex << expected_data
                  << ", got 0x" << actual << std::dec << std::endl;
        exit(1);
    } else {
        std::cout << msg << " (PASSED: data = 0x" << std::hex << actual << std::dec << ")" << std::endl;
    }
}

void performWrite(
    uint32_t addr_val,
    uint32_t data_val,
    const char* msg,
    sc_signal<uint32_t>& addr,
    sc_signal<uint32_t>& write_data,
    sc_signal<bool>& write_en,
    sc_signal<bool>& ready,
    sc_signal<bool>& mem_read,
    sc_signal<bool>& mem_write,
    sc_signal<uint32_t>& mem_addr,
    sc_signal<uint32_t>& mem_wdata,
    sc_signal<uint32_t>& mem_rdata,
    sc_signal<bool>& mem_ready,
    std::unordered_map<uint32_t,uint32_t>& memory
) {
    addr = addr_val;
    write_data = data_val;
    write_en = 1;
    sc_start(10, SC_NS);
    waitForReady(ready, mem_read, mem_write, mem_addr, mem_wdata, mem_rdata, mem_ready, memory);
    write_en = 0;
    sc_start(10, SC_NS);
    std::cout << msg << std::endl;
}
