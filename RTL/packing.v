`timescale 1ns / 1ps

module packing (
    input         clk,
    input         rst_n,

    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input          in_valid,
    output         in_ready,
    input          in_last,

    input          in_burst_start,
    input  [7:0]   in_burst_offset,
    input  [2:0]   in_burst_size,

    output         out_valid,
    input          out_ready,
    output [127:0] out_data,
    output [15:0]  out_keep,
    output         out_last,
    output         out_flit_last,
    output [3:0]   out_word_index,
    output [8:0]   out_flit_offset
);

    wire [4:0] beat_bytes;

    wire [5:0]   buf_count;
    wire [127:0] buf_data;
    wire [15:0]  buf_keep;

    wire         buf_in_ready;
    wire [4:0]   buf_pop_bytes;

    wire         allow_input;
    wire         in_fire;

    assign beat_bytes =
        5'd1 << in_burst_size;

    assign in_ready =
        buf_in_ready &&
        allow_input;

    assign in_fire =
        in_valid &&
        in_ready;

    elastic_byte_buffer u_elastic_byte_buffer (
        .clk            (clk),
        .rst_n          (rst_n),

        .in_valid       (in_fire),
        .in_ready       (buf_in_ready),
        .in_data        (in_data),
        .in_keep        (in_keep),
        .in_bytes       (beat_bytes),

        .pop_bytes      (buf_pop_bytes),

        .buf_count      (buf_count),
        .buf_data       (buf_data),
        .buf_keep       (buf_keep)
    );

    word_assembler u_word_assembler (
        .clk             (clk),
        .rst_n           (rst_n),

        .in_fire         (in_fire),
        .in_last         (in_last),
        .in_burst_start  (in_burst_start),
        .in_burst_offset (in_burst_offset),

        .buf_count       (buf_count),
        .buf_data        (buf_data),
        .buf_keep        (buf_keep),

        .allow_input     (allow_input),
        .pop_bytes       (buf_pop_bytes),

        .out_valid       (out_valid),
        .out_ready       (out_ready),
        .out_data        (out_data),
        .out_keep        (out_keep),
        .out_last        (out_last),
        .out_flit_last   (out_flit_last),
        .out_word_index  (out_word_index),
        .out_flit_offset (out_flit_offset)
    );

endmodule