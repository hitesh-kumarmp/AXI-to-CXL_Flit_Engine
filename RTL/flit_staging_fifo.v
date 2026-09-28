`timescale 1ns / 1ps

module flit_staging_fifo #(
    parameter DEPTH = 32
)(
    input         clk,
    input         rst_n,

    input         in_valid,
    output        in_ready,
    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input          in_last,
    input          in_flit_last,
    input  [3:0]   in_word_index,

    output        out_valid,
    input         out_ready,
    output [127:0] out_data,
    output [15:0]  out_keep,
    output         out_last,
    output         out_flit_last,
    output [3:0]   out_word_index
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH + 1);

    reg [127:0] data_mem [0:DEPTH-1];
    reg [15:0]  keep_mem [0:DEPTH-1];
    reg         last_mem [0:DEPTH-1];
    reg         flit_last_mem [0:DEPTH-1];
    reg [3:0]   word_index_mem [0:DEPTH-1];

    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [COUNT_WIDTH-1:0] count;

    wire push;
    wire pop;

    assign out_valid =
        (count != 0);

    assign in_ready =
        (count < DEPTH) ||
        (out_valid && out_ready);

    assign push =
        in_valid &&
        in_ready;

    assign pop =
        out_valid &&
        out_ready;

    assign out_data =
        data_mem[rd_ptr];

    assign out_keep =
        keep_mem[rd_ptr];

    assign out_last =
        last_mem[rd_ptr];

    assign out_flit_last =
        flit_last_mem[rd_ptr];

    assign out_word_index =
        word_index_mem[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            rd_ptr <= 0;
            wr_ptr <= 0;
            count  <= 0;

        end
        else begin

            if (push) begin

                data_mem[wr_ptr] <= in_data;
                keep_mem[wr_ptr] <= in_keep;
                last_mem[wr_ptr] <= in_last;
                flit_last_mem[wr_ptr] <= in_flit_last;
                word_index_mem[wr_ptr] <= in_word_index;

                if (wr_ptr == DEPTH-1)
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            if (pop) begin

                if (rd_ptr == DEPTH-1)
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            case ({push, pop})
                2'b10:
                    count <= count + 1'b1;

                2'b01:
                    count <= count - 1'b1;

                default:
                    count <= count;
            endcase
        end
    end

endmodule