`timescale 1ns / 1ps

module word_assembler (
    input         clk,
    input         rst_n,

    input         in_fire,
    input         in_last,
    input         in_burst_start,
    input  [7:0]  in_burst_offset,

    input  [5:0]   buf_count,
    input  [127:0] buf_data,
    input  [15:0]  buf_keep,

    output        allow_input,
    output [4:0]  pop_bytes,

    output        out_valid,
    input         out_ready,
    output [127:0] out_data,
    output [15:0]  out_keep,
    output        out_last,
    output        out_flit_last,
    output [3:0]  out_word_index,
    output [8:0]  out_flit_offset
);

    reg [8:0] flit_offset_reg;
    reg       burst_end_reg;

    wire [4:0] current_lane;
    wire [4:0] needed_bytes;

    reg [4:0] emit_bytes;

    reg [127:0] out_data_reg;
    reg [15:0]  out_keep_reg;

    integer i;

    assign current_lane =
        flit_offset_reg[3:0];

    assign needed_bytes =
        5'd16 - current_lane;

    assign allow_input =
        ~burst_end_reg;

    always @* begin

        emit_bytes = 5'd0;

        if (buf_count >= needed_bytes) begin
            emit_bytes = needed_bytes;
        end
        else if (burst_end_reg && (buf_count != 0)) begin
            emit_bytes = buf_count[4:0];
        end

        out_data_reg = 128'd0;
        out_keep_reg = 16'd0;

        for (i = 0; i < 16; i = i + 1) begin

            if ((i >= current_lane) &&
                (i < current_lane + emit_bytes)) begin

                out_data_reg[8*i +: 8] =
                    buf_data[8*(i-current_lane) +: 8];

                out_keep_reg[i] =
                    buf_keep[i-current_lane];
            end
        end
    end

    assign out_valid =
        (emit_bytes != 0);

    assign out_data =
        out_data_reg;

    assign out_keep =
        out_keep_reg;

    assign out_last =
        out_valid &&
        burst_end_reg &&
        (buf_count <= needed_bytes);

    assign out_flit_last =
        out_valid &&
        (
            (flit_offset_reg + emit_bytes == 9'd256) ||
            out_last
        );

    assign out_word_index =
        flit_offset_reg[7:4];

    assign out_flit_offset =
        flit_offset_reg;

    assign pop_bytes =
        (out_valid && out_ready) ?
        emit_bytes :
        5'd0;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            flit_offset_reg <= 9'd0;
            burst_end_reg   <= 1'b0;

        end
        else begin

            if (in_fire && in_burst_start) begin

                flit_offset_reg <=
                    {1'b0, in_burst_offset};

                burst_end_reg <=
                    in_last;
            end

            else if (in_fire && in_last) begin

                burst_end_reg <=
                    1'b1;
            end

            if (out_valid && out_ready) begin

                if (out_last) begin

                    flit_offset_reg <=
                        9'd0;

                    burst_end_reg <=
                        1'b0;
                end

                else if (out_flit_last) begin

                    flit_offset_reg <=
                        9'd0;
                end

                else begin

                    flit_offset_reg <=
                        flit_offset_reg + emit_bytes;
                end
            end
        end
    end

endmodule