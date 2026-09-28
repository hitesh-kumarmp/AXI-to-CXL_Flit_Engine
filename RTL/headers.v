`timescale 1ns / 1ps

`include "cxl_common.vh"

module headers (
    input         valid,
    input         partial_write,

    input  [63:0]  address,
    input  [15:0]  tag,

    input  [1:0]   meta_field,
    input  [1:0]   meta_value,
    input  [2:0]   snp_type,

    input          poison,
    input          trp,
    input  [3:0]   ld_id,
    input  [12:0]  ckid,
    input  [1:0]   tc,

    output [127:0] header
);

    wire [3:0] mem_opcode;

    assign mem_opcode =
        partial_write ? `CXL_MEMWRPTL :
                         `CXL_MEMWR;

    cxl_header_gen u_cxl_header_gen (
        .valid      (valid),
        .mem_opcode (mem_opcode),
        .meta_field (meta_field),
        .meta_value (meta_value),
        .snp_type   (snp_type),
        .tag        (tag),
        .address    (address),
        .poison     (poison),
        .trp        (trp),
        .ld_id      (ld_id),
        .ckid       (ckid),
        .tc         (tc),
        .header     (header)
    );

endmodule