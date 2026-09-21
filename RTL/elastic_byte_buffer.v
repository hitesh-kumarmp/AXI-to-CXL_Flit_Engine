`timescale 1ns / 1ps

module elastic_byte_buffer #(
    parameter DEPTH = 32
)(
    input         clk,
    input         rst_n,

    input         in_valid,
    output        in_ready,
    input  [127:0] in_data,
    input  [15:0]  in_keep,
    input  [4:0]   in_bytes,

    input  [4:0]   pop_bytes,

    output [5:0]   buf_count,
    output reg [127:0] buf_data,
    output reg [15:0]  buf_keep
);

    reg [7:0] data_mem [0:31];
    reg       keep_mem [0:31];

    reg [5:0] count_reg;

    reg [7:0] next_data [0:31];
    reg       next_keep [0:31];
    reg [5:0] next_count;

    integer i;

    wire pop_active;
    wire [5:0] count_after_pop;
    wire [5:0] count_after_push;
    wire push_fire;

    assign pop_active =
        (pop_bytes != 5'd0);

    assign count_after_pop =
        count_reg - pop_bytes;

    assign count_after_push =
        count_after_pop + (in_valid ? in_bytes : 5'd0);

    assign in_ready =
        (count_after_push <= DEPTH);

    assign push_fire =
        in_valid &&
        in_ready;

    assign buf_count =
        count_reg;

    always @* begin
        for (i = 0; i < 32; i = i + 1) begin
            buf_data[8*i +: 8] = data_mem[i];
            buf_keep[i] = keep_mem[i];
        end
    end

    always @* begin
        for (i = 0; i < 32; i = i + 1) begin
            next_data[i] = 8'd0;
            next_keep[i] = 1'b0;
        end

        if (pop_active) begin
            for (i = 0; i < 32; i = i + 1) begin
                if (i < count_after_pop) begin
                    next_data[i] = data_mem[i + pop_bytes];
                    next_keep[i] = keep_mem[i + pop_bytes];
                end
            end
        end
        else begin
            for (i = 0; i < 32; i = i + 1) begin
                if (i < count_reg) begin
                    next_data[i] = data_mem[i];
                    next_keep[i] = keep_mem[i];
                end
            end
        end

        if (push_fire) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (i < in_bytes) begin
                    next_data[count_after_pop + i] =
                        in_data[8*i +: 8];

                    next_keep[count_after_pop + i] =
                        in_keep[i];
                end
            end
        end

        next_count =
            count_after_pop +
            (push_fire ? in_bytes : 5'd0);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= 6'd0;

            for (i = 0; i < 32; i = i + 1) begin
                data_mem[i] <= 8'd0;
                keep_mem[i] <= 1'b0;
            end
        end
        else begin
            count_reg <= next_count;

            for (i = 0; i < 32; i = i + 1) begin
                data_mem[i] <= next_data[i];
                keep_mem[i] <= next_keep[i];
            end
        end
    end

endmodule