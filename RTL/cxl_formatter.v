`timescale 1ns / 1ps

module cxl_formatter (
    // From reader
    input         in_valid,
    output        in_ready,
    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input         in_last,
    input         in_flit_last,
    input         in_flit_start,
    input         in_bank,
    input  [3:0]   in_word_index,

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

    assign in_ready =
        cxl_ready;

    assign cxl_valid =
        in_valid;

    assign cxl_data =
        in_data;

    assign cxl_keep =
        in_keep;

    assign cxl_header =
        in_flit_start ?
        header_data :
        64'd0;

    assign cxl_header_valid =
        in_valid &&
        in_flit_start;

    assign cxl_last =
        in_last;

    assign cxl_flit_last =
        in_flit_last;

    assign cxl_flit_start =
        in_flit_start;

    assign cxl_bank =
        in_bank;

    assign cxl_word_index =
        in_word_index;

endmodule