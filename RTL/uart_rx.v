`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input clk,
    input rst_n,
    input rx,
    output reg [7:0] data,
    output reg valid
);

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;

    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    reg rx_meta;
    reg rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            data_reg <= 8'd0;
            data <= 8'd0;
            valid <= 1'b0;
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
            valid <= 1'b0;

            case (state)

                S_IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;

                    if (!rx_sync)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_count == (CLKS_PER_BIT/2)-1) begin
                        clk_count <= 16'd0;

                        if (!rx_sync)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 16'd0;

                        data_reg[bit_index] <= rx_sync;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= 16'd0;
                        data <= data_reg;
                        valid <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule