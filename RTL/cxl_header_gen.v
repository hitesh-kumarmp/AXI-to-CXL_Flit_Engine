`timescale 1ns / 1ps

`include "cxl_common.vh"

module cxl_header_gen (
    input         valid,
    input  [3:0]  mem_opcode,
    input  [1:0]  meta_field,
    input  [1:0]  meta_value,
    input  [2:0]  snp_type,
    input  [15:0] tag,
    input  [63:0] address,
    input         poison,
    input         trp,
    input  [3:0]  ld_id,
    input  [12:0] ckid,
    input  [1:0]  tc,

    output [127:0] header
);

    reg [127:0] header_reg;

    always @* begin
        header_reg = 128'd0;

        // Byte 0
        header_reg[7:5] = mem_opcode[2:0];
        header_reg[4]   = valid;
        header_reg[3:0] = `CXL_SLOT_FMT_RWD;

        // Byte 1
        header_reg[15:14] = meta_value;
        header_reg[13:12] = meta_field;
        header_reg[11:9]  = snp_type;
        header_reg[8]     = mem_opcode[3];

        // Bytes 2-3
        header_reg[23:16] = tag[7:0];
        header_reg[31:24] = tag[15:8];

        // Bytes 4-8 + lower 6 bits of byte 9
        header_reg[77:32] = address[51:6];

        // Byte 9
        header_reg[78] = trp;
        header_reg[79] = poison;

        // Byte 10
        header_reg[87:84] = ckid[3:0];
        header_reg[83:80] = ld_id;

        // Byte 11
        header_reg[95:88] = ckid[11:4];

        // Byte 12
        header_reg[96] = ckid[12];

        // Byte 13
        header_reg[111:110] = tc;
    end

    assign header = header_reg;

endmodule