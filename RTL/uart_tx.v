`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input clk,
    input rst_n,
    input [7:0] data,
    input valid,
    output ready,
    output reg tx
);

    reg busy;
    reg [15:0] clk_count;
    reg [3:0] bits_left;
    reg [9:0] shift_reg;

    assign ready = ~busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            clk_count <= 16'd0;
            bits_left <= 4'd0;
            shift_reg <= 10'h3ff;
            tx <= 1'b1;
        end else begin

            if (!busy) begin
                tx <= 1'b1;
                clk_count <= 16'd0;

                if (valid) begin
                    shift_reg <= {1'b1, data, 1'b0};
                    bits_left <= 4'd10;
                    busy <= 1'b1;
                    tx <= 1'b0;
                end

            end else if (clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 16'd0;

                if (bits_left == 4'd1) begin
                    bits_left <= 4'd0;
                    busy <= 1'b0;
                    tx <= 1'b1;
                end else begin
                    shift_reg <= {1'b1, shift_reg[9:1]};
                    bits_left <= bits_left - 1'b1;
                    tx <= shift_reg[1];
                end

            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end

endmodule