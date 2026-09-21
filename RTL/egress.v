`timescale 1ns / 1ps

module egress (
    input         clk,
    input         rst_n,

    // From storage
    input         in_valid,
    output        in_ready,
    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input         in_last,
    input         in_flit_last,
    input         in_bank,
    input  [3:0]   in_word_index,

    // Transaction header from the higher layer
    input  [63:0]  header_data,

    // CXL output
    output        cxl_valid,
    input         cxl_ready,
    output [127:0] cxl_data,
    output [15:0]  cxl_keep,
    output [63:0]  cxl_header,
    output        cxl_header_valid,
    output        cxl_last,
    output        cxl_flit_last,
    output        cxl_flit_start,
    output        cxl_bank,
    output [3:0]   cxl_word_index
);

    wire         reader_valid;
    wire         reader_ready;

    wire [127:0] reader_data;
    wire [15:0]  reader_keep;
    wire         reader_last;
    wire         reader_flit_last;
    wire         reader_flit_start;
    wire         reader_bank;
    wire [3:0]   reader_word_index;

    egress_reader u_egress_reader (
        .clk             (clk),
        .rst_n           (rst_n),

        .in_valid        (in_valid),
        .in_ready        (in_ready),
        .in_data         (in_data),
        .in_keep         (in_keep),
        .in_last         (in_last),
        .in_flit_last    (in_flit_last),
        .in_bank         (in_bank),
        .in_word_index   (in_word_index),

        .out_valid       (reader_valid),
        .out_ready       (reader_ready),
        .out_data        (reader_data),
        .out_keep        (reader_keep),
        .out_last        (reader_last),
        .out_flit_last   (reader_flit_last),
        .out_flit_start  (reader_flit_start),
        .out_bank        (reader_bank),
        .out_word_index  (reader_word_index)
    );

    cxl_formatter u_cxl_formatter (
        .in_valid        (reader_valid),
        .in_ready        (reader_ready),
        .in_data         (reader_data),
        .in_keep         (reader_keep),
        .in_last         (reader_last),
        .in_flit_last    (reader_flit_last),
        .in_flit_start   (reader_flit_start),
        .in_bank         (reader_bank),
        .in_word_index   (reader_word_index),

        .header_data     (header_data),

        .cxl_valid       (cxl_valid),
        .cxl_ready       (cxl_ready),
        .cxl_data        (cxl_data),
        .cxl_keep        (cxl_keep),
        .cxl_header     (cxl_header),
        .cxl_header_valid(cxl_header_valid),
        .cxl_last        (cxl_last),
        .cxl_flit_last   (cxl_flit_last),
        .cxl_flit_start  (cxl_flit_start),
        .cxl_bank        (cxl_bank),
        .cxl_word_index  (cxl_word_index)
    );

endmodule