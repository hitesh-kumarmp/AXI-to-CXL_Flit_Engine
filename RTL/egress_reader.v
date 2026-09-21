`timescale 1ns / 1ps

module egress_reader (
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

    // To formatter
    output        out_valid,
    input         out_ready,
    output [127:0] out_data,
    output [15:0]  out_keep,
    output        out_last,
    output        out_flit_last,
    output        out_flit_start,
    output        out_bank,
    output [3:0]   out_word_index
);

    reg         buffer_valid;
    reg [127:0] buffer_data;
    reg [15:0]  buffer_keep;
    reg         buffer_last;
    reg         buffer_flit_last;
    reg         buffer_flit_start;
    reg         buffer_bank;
    reg [3:0]   buffer_word_index;

    reg         next_flit_start;

    wire buffer_can_accept;
    wire in_fire;

    assign buffer_can_accept =
        (~buffer_valid) ||
        out_ready;

    assign in_ready =
        buffer_can_accept;

    assign in_fire =
        in_valid &&
        in_ready;

    assign out_valid =
        buffer_valid;

    assign out_data =
        buffer_data;

    assign out_keep =
        buffer_keep;

    assign out_last =
        buffer_last;

    assign out_flit_last =
        buffer_flit_last;

    assign out_flit_start =
        buffer_flit_start;

    assign out_bank =
        buffer_bank;

    assign out_word_index =
        buffer_word_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            buffer_valid      <= 1'b0;
            buffer_data       <= 128'd0;
            buffer_keep       <= 16'd0;
            buffer_last       <= 1'b0;
            buffer_flit_last  <= 1'b0;
            buffer_flit_start <= 1'b0;
            buffer_bank       <= 1'b0;
            buffer_word_index <= 4'd0;

            next_flit_start   <= 1'b1;

        end
        else begin

            if (buffer_valid && out_ready)
                buffer_valid <= 1'b0;

            if (in_fire) begin

                buffer_valid      <= 1'b1;
                buffer_data       <= in_data;
                buffer_keep       <= in_keep;
                buffer_last       <= in_last;
                buffer_flit_last  <= in_flit_last;
                buffer_flit_start <= next_flit_start;
                buffer_bank       <= in_bank;
                buffer_word_index <= in_word_index;

                if (in_flit_last)
                    next_flit_start <= 1'b1;
                else
                    next_flit_start <= 1'b0;
            end

        end
    end

endmodule