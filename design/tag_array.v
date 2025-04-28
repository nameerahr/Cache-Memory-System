`timescale 1ns/1ps

module tag_array #(
    parameter NUM_SETS = 8,
    parameter TAG_BITS,
    parameter NUM_WAYS = 2
)(
    input logic clk,
    input logic wr_en,
    input logic [($clog2(NUM_SETS))-1:0] index, // Selects the set
    input logic [($clog2(NUM_WAYS))-1:0] way, // Selects the way
    input logic [TAG_BITS-1:0] tag_in, // Tag to write
    input logic valid_in, // Valid bit to write

    output logic [TAG_BITS-1:0] tag_out_way0, // Contents of way 0 at the index
    output logic valid_out_way0,
    output logic [TAG_BITS-1:0] tag_out_way1, // Contents of way 1 at the index
    output logic valid_out_way1
);

    logic [TAG_BITS-1:0] tag_mem [NUM_SETS-1:0][NUM_WAYS-1:0]; // Memory array for tags 
    logic valid_mem [NUM_SETS-1:0][NUM_WAYS-1:0]; // Memory array for valid bits

    // On write enable, write the tag and valid bits to the set/way
    always_ff @(posedge clk) begin
        if (wr_en) begin
            tag_mem[index][way] <= tag_in;
            valid_mem[index][way] <= valid_in;
        end
    end

    // Always output the tags/valid bits for both ways in the current set (to check for cache hits)
    assign tag_out_way0 = tag_mem[index][0];
    assign valid_out_way0 = valid_mem[index][0];
    assign tag_out_way1 = tag_mem[index][1];
    assign valid_out_way1 = valid_mem[index][1];

endmodule
