`timescale 1ns/1ps

module top_cache #(
    parameter BLOCK_SIZE = 4,
    parameter NUM_SETS = 8,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_WAYS = 2
)(
    input logic clk,
    input logic rst,

    input logic read_en,
    input logic write_en,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data,

    output logic hit,
    output logic ready,
    input logic mem_ready,

    output logic mem_read,
    output logic mem_write,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wdata,
    input logic [DATA_WIDTH-1:0] mem_rdata,

    output logic [31:0] hit_count,
    output logic [31:0] miss_count
);

    // Decode the address
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;

    logic [OFFSET_BITS-1:0] offset;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0] tag;

    assign offset = addr[OFFSET_BITS-1:0];
    assign index = addr[OFFSET_BITS +: INDEX_BITS];
    assign tag = addr[ADDR_WIDTH-1 -: TAG_BITS];

    // Internal signals
    logic tag_wr_en;
    logic data_wr_en;
    logic [TAG_BITS-1:0] tag_in;
    logic valid_in;
    logic [DATA_WIDTH-1:0] data_in;
    logic dirty_clear;
    logic evict_way_ctrl;
    logic write_way;

    logic hit_way0;
    logic hit_way1;
    logic hit_way;
    logic hit_internal;
    logic hit_way_valid;
    logic hit_way_id;

    logic dirty_array [NUM_SETS-1:0][NUM_WAYS-1:0];

    // Instantiate tag and data arrays
    logic [TAG_BITS-1:0] tag_out_way0;
    logic [TAG_BITS-1:0] tag_out_way1;
    logic [DATA_WIDTH-1:0] data_out_way0;
    logic [DATA_WIDTH-1:0] data_out_way1;
    logic valid_out_way0;
    logic valid_out_way1;

    assign tag_in = tag;
    assign valid_in = 1;

    tag_array #(
        .NUM_SETS(NUM_SETS),
        .TAG_BITS(TAG_BITS),
        .NUM_WAYS(NUM_WAYS)
    ) tag_mem (
        .clk(clk),
        .wr_en(tag_wr_en),
        .index(index),
        .way(write_way),
        .tag_in(tag_in),
        .valid_in(valid_in),
        .tag_out_way0(tag_out_way0),
        .valid_out_way0(valid_out_way0),
        .tag_out_way1(tag_out_way1),
        .valid_out_way1(valid_out_way1)
    );

    data_array #(
        .NUM_SETS(NUM_SETS),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_WAYS(NUM_WAYS)
    ) data_mem (
        .clk(clk),
        .wr_en(data_wr_en),
        .index(index),
        .way(write_way),
        .data_in(data_in),
        .data_out_way0(data_out_way0),
        .data_out_way1(data_out_way1)
    );

    // Set evict tag and data based on evict_way_ctrl
    logic [TAG_BITS-1:0]  evict_tag;
    logic [DATA_WIDTH-1:0] evict_data;
    assign evict_tag  = (evict_way_ctrl == 0) ? tag_out_way0  : tag_out_way1;
    assign evict_data = (evict_way_ctrl == 0) ? data_out_way0 : data_out_way1;

    // Detect hit
    assign hit_way0 = valid_out_way0 && (tag_out_way0 == tag);
    assign hit_way1 = valid_out_way1 && (tag_out_way1 == tag);
    assign hit_internal = hit_way0 || hit_way1;
    assign hit = hit_internal;
    assign hit_way = hit_way1 ? 1 : 0;

    assign hit_way_valid = hit_internal;
    assign hit_way_id = hit_way;

    // Select way to write to
    always_comb begin
        if (hit_internal) begin
            write_way = hit_way; 
        end else begin
            write_way = evict_way_ctrl; // Otherwise write to the LRU way
        end
    end

    // Instantiate controller
    cache_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_SETS(NUM_SETS)
    ) controller (
        .clk(clk),
        .rst(rst),

        .read_en(read_en),
        .write_en(write_en),
        .hit_internal(hit_internal),
        .addr(addr),
        .write_data(write_data),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),

        .ready(ready),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),

        .tag_wr_en(tag_wr_en),
        .data_wr_en(data_wr_en),
        .data_in(data_in),

        .dirty_bit(dirty_array[index][write_way]),
        .dirty_clear(dirty_clear),

        .hit_count(hit_count),
        .miss_count(miss_count),

        .evict_way(evict_way_ctrl),
        .evict_tag    (evict_tag),
        .evict_data   (evict_data),
        .hit_way_valid(hit_way_valid),
        .hit_way_id(hit_way_id)
    );

    // Read data output
    always_comb begin
        if (hit_way0)
            read_data = data_out_way0;
        else if (hit_way1)
            read_data = data_out_way1;
        else
            read_data = 32'hFFFFFFFF;
    end

    // Set dirty bit if new data written to way
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    dirty_array[i][j] <= 0;
                end
            end
        end else begin
            if (dirty_clear) begin
                dirty_array[index][write_way] <= 0;
            end else if (data_wr_en) begin
                dirty_array[index][write_way] <= 1;
            end
        end
    end

endmodule
