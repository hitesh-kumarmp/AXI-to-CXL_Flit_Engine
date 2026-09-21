`timescale 1ns / 1ps

module ping_pong_bram #(
    parameter WORD_WIDTH = 128,
    parameter KEEP_WIDTH = 16,
    parameter WORDS      = 16
)(
    input                     clk,

    input                     wr_en,
    input                     wr_bank,
    input  [3:0]              wr_addr,
    input  [WORD_WIDTH-1:0]   wr_data,
    input  [KEEP_WIDTH-1:0]   wr_keep,

    input                     rd_en,
    input                     rd_bank,
    input  [3:0]              rd_addr,

    output reg [WORD_WIDTH-1:0] rd_data,
    output reg [KEEP_WIDTH-1:0] rd_keep
);

    reg [WORD_WIDTH-1:0] bank0_data [0:WORDS-1];
    reg [WORD_WIDTH-1:0] bank1_data [0:WORDS-1];

    reg [KEEP_WIDTH-1:0] bank0_keep [0:WORDS-1];
    reg [KEEP_WIDTH-1:0] bank1_keep [0:WORDS-1];

    integer i;

    always @(posedge clk) begin
        if (wr_en) begin
            if (!wr_bank) begin
                bank0_data[wr_addr] <= wr_data;
                bank0_keep[wr_addr] <= wr_keep;
            end
            else begin
                bank1_data[wr_addr] <= wr_data;
                bank1_keep[wr_addr] <= wr_keep;
            end
        end

        if (rd_en) begin
            if (!rd_bank) begin
                rd_data <= bank0_data[rd_addr];
                rd_keep <= bank0_keep[rd_addr];
            end
            else begin
                rd_data <= bank1_data[rd_addr];
                rd_keep <= bank1_keep[rd_addr];
            end
        end
    end

    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            bank0_data[i] = {WORD_WIDTH{1'b0}};
            bank1_data[i] = {WORD_WIDTH{1'b0}};
            bank0_keep[i] = {KEEP_WIDTH{1'b0}};
            bank1_keep[i] = {KEEP_WIDTH{1'b0}};
        end
    end

endmodule