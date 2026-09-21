`timescale 1ns / 1ps

module storage (
    input         clk,
    input         rst_n,

    // From packing
    input         in_valid,
    output        in_ready,
    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input         in_last,
    input         in_flit_last,
    input  [3:0]   in_word_index,

    // To egress
    output        out_valid,
    input         out_ready,
    output [127:0] out_data,
    output [15:0]  out_keep,
    output        out_last,
    output        out_flit_last,
    output        out_bank,
    output [3:0]   out_word_index
);

    wire        write_bank;
    wire        rd_issue;
    wire        rd_bank;
    wire [3:0]  rd_addr;
    wire        rd_issue_last;
    wire        rd_issue_flit_last;

    wire [127:0] bram_rd_data;
    wire [15:0]  bram_rd_keep;

    wire wr_fire;

    reg         out_valid_reg;
    reg         out_last_reg;
    reg         out_flit_last_reg;
    reg         out_bank_reg;
    reg [3:0]   out_word_index_reg;

    assign wr_fire =
        in_valid &&
        in_ready;

    ping_pong_bank_ctrl u_ping_pong_bank_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),

        .in_valid           (in_valid),
        .in_word_index      (in_word_index),
        .in_flit_last       (in_flit_last),
        .in_last            (in_last),
        .in_ready           (in_ready),
        .write_bank         (write_bank),

        .out_valid          (out_valid_reg),
        .out_ready          (out_ready),
        .out_flit_last      (out_flit_last_reg),
        .out_word_index     (out_word_index_reg),

        .rd_issue           (rd_issue),
        .rd_bank            (rd_bank),
        .rd_addr            (rd_addr),
        .rd_issue_last      (rd_issue_last),
        .rd_issue_flit_last (rd_issue_flit_last)
    );

    ping_pong_bram u_ping_pong_bram (
        .clk        (clk),

        .wr_en      (wr_fire),
        .wr_bank    (write_bank),
        .wr_addr    (in_word_index),
        .wr_data    (in_data),
        .wr_keep    (in_keep),

        .rd_en      (rd_issue),
        .rd_bank    (rd_bank),
        .rd_addr    (rd_addr),

        .rd_data    (bram_rd_data),
        .rd_keep    (bram_rd_keep)
    );

    assign out_valid =
        out_valid_reg;

    assign out_data =
        bram_rd_data;

    assign out_keep =
        bram_rd_keep;

    assign out_last =
        out_last_reg;

    assign out_flit_last =
        out_flit_last_reg;

    assign out_bank =
        out_bank_reg;

    assign out_word_index =
        out_word_index_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid_reg       <= 1'b0;
            out_last_reg        <= 1'b0;
            out_flit_last_reg   <= 1'b0;
            out_bank_reg        <= 1'b0;
            out_word_index_reg  <= 4'd0;
        end
        else begin
            if (rd_issue) begin
                out_valid_reg      <= 1'b1;
                out_last_reg       <= rd_issue_last;
                out_flit_last_reg <= rd_issue_flit_last;
                out_bank_reg       <= rd_bank;
                out_word_index_reg <= rd_addr;
            end
            else if (out_valid_reg && out_ready) begin
                out_valid_reg <= 1'b0;
            end
        end
    end

endmodule