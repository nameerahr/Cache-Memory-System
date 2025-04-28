`timescale 1ns/1ps

module data_array #(
    parameter NUM_SETS = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WAYS = 2
)(
    input  logic clk,
    input  logic wr_en,
    input  logic [($clog2(NUM_SETS))-1:0] index, // Selects the set
    input  logic [($clog2(NUM_WAYS))-1:0] way, // Selects the way
    input  logic [DATA_WIDTH-1:0] data_in, // Data to write

    output logic [DATA_WIDTH-1:0] data_out_way0, // Data of way 0 at the index
    output logic [DATA_WIDTH-1:0] data_out_way1 // Data of way 1 at the index
);

    logic [DATA_WIDTH-1:0] data_mem [NUM_SETS-1:0][NUM_WAYS-1:0];

    // On write enable, write the data to the set/way
    always_ff @(posedge clk) begin
        if (wr_en) begin
            data_mem[index][way] <= data_in;
        end
    end

    // Always output the data for both ways in the current set (to check for cache hits)
    assign data_out_way0 = data_mem[index][0];
    assign data_out_way1 = data_mem[index][1];

endmodule
