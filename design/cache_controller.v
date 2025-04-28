`timescale 1ns/1ps

module cache_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BLOCK_SIZE = 4,
    parameter NUM_SETS   = 8
)(
    input logic clk,
    input logic rst,

    input logic read_en,
    input logic write_en,
    input logic hit_internal,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] write_data,

    input logic hit_way_valid, // Hit occurred
    input logic hit_way_id, // Which way hit

    input logic mem_ready,
    input logic [DATA_WIDTH-1:0] mem_rdata,

    output logic ready, // Data available? 
    output logic mem_read,
    output logic mem_write,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wdata,

    output logic tag_wr_en,
    output logic data_wr_en,
    output logic [DATA_WIDTH-1:0] data_in,

    output logic [31:0] hit_count,
    output logic [31:0] miss_count,

    input logic dirty_bit,
    output logic dirty_clear,

    output logic evict_way,
    // tag bits = ADDR_WIDTH – clog2(BLOCK_SIZE) – clog2(NUM_SETS)
    input  logic [ADDR_WIDTH - $clog2(BLOCK_SIZE) - $clog2(NUM_SETS) - 1 : 0] evict_tag,
    input  logic [DATA_WIDTH-1:0]  evict_data
);

    typedef enum logic [1:0] {
        IDLE,
        WRITEBACK,
        MISS
    } cache_state;

    cache_state state, next_state;

    logic [ADDR_WIDTH-1:0] saved_addr;
    logic [DATA_WIDTH-1:0] saved_write_data;
    logic saved_write_en;

    logic [31:0] hit_counter;
    logic [31:0] miss_counter;

    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);

    // LRU for curr set (actual least recently used way)
    logic [0:0] lru_array [NUM_SETS-1:0];

    wire [$clog2(NUM_SETS)-1:0] set_index;
    assign set_index = addr[OFFSET_BITS +: $clog2(NUM_SETS)];

    // Sequential Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            hit_counter <= 0;
            miss_counter <= 0;
            saved_addr <= 0;
            saved_write_data <= 0;
            saved_write_en <= 0;
            for (int i = 0; i < NUM_SETS; i++) begin
                lru_array[i] <= 0;
            end
        end else begin
            state <= next_state;

            if ((read_en || write_en) && !hit_internal && state == IDLE) begin
                saved_addr <= addr;
                saved_write_data <= write_data;
                saved_write_en <= write_en;
            end

            if (ready && hit_internal)
                hit_counter <= hit_counter + 1;
            else if (ready && !hit_internal)
                miss_counter <= miss_counter + 1;

            // Update LRU when there is a hit
            if (ready && hit_internal && hit_way_valid) begin
                lru_array[set_index] <= ~hit_way_id;
            end

            // Update LRU when a new block was brought into cache - when in MISS state and memory responded and updated LRU with new block
            if (state == MISS && mem_ready) begin
                lru_array[set_index] <= ~lru_array[set_index];
            end
        end
    end

    always_comb begin
        next_state = state;

        ready = 0;
        mem_read = 0;
        mem_write = 0;
        mem_addr = 0;
        mem_wdata = 0;
        tag_wr_en = 0;
        data_wr_en = 0;
        data_in = mem_rdata;
        dirty_clear = 0;

        case (state)
            IDLE: begin
                if (read_en || write_en) begin
                    // If hit, write data, otherwise check if block is dirty (will need to be written back before an update), otherwise it is just a MISS
                    if (hit_internal) begin
                        ready = 1;
                        if (write_en) begin
                            data_wr_en = 1;
                            data_in = write_data;
                        end
                    end else begin
                        if (dirty_bit) begin
                            next_state = WRITEBACK;
                        end else begin
                            next_state = MISS;
                        end
                    end
                end
            end

            // Write back dirty block to memory
            WRITEBACK: begin
                // Write back victim block
                mem_write = 1;
                mem_addr  = { evict_tag, set_index, {OFFSET_BITS{1'b0}} };
                mem_wdata = evict_data;

                if (mem_ready) begin
                    dirty_clear = 1;
                    next_state = MISS;
                end
            end

            MISS: begin
                mem_read = 1;
                mem_addr = {saved_addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}}; // Align address by zeroing offset bits

                if (mem_ready) begin
                    tag_wr_en = 1;
                    data_wr_en = 1;

                    if (saved_write_en) begin
                        data_in = saved_write_data;
                    end else begin
                        data_in = mem_rdata;
                    end

                    ready = 1;
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    assign hit_count = hit_counter;
    assign miss_count = miss_counter;

    // Always evict the LRU way
    assign evict_way = lru_array[set_index];

endmodule
