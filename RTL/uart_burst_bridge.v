`timescale 1ns / 1ps

module uart_burst_bridge (
    input clk,
    input rst_n,
    input enable,

    input [7:0] rx_data,
    input rx_valid,

    output reg [7:0] tx_data,
    output tx_valid,
    input tx_ready,

    output [63:0] axi_awaddr,
    output [7:0] axi_awlen,
    output [2:0] axi_awsize,
    output [1:0] axi_awburst,
    output axi_awvalid,
    input axi_awready,

    output [127:0] axi_wdata,
    output [15:0] axi_wstrb,
    output axi_wlast,
    output axi_wvalid,
    input axi_wready,

    input [1:0] axi_bresp,
    input axi_bvalid,
    output axi_bready,

    input cxl_valid,
    input [127:0] cxl_data,
    input [15:0] cxl_keep,
    input [127:0] cxl_header,
    input cxl_header_valid,
    input cxl_last,
    input cxl_flit_last,
    input cxl_flit_start,
    input cxl_bank,
    input [3:0] cxl_word_index,

    output busy,
    output reg done,
    output reg stall_seen,
    output reg error
);

    localparam S_IDLE     = 4'd0;
    localparam S_MAGIC2   = 4'd1;
    localparam S_CMD      = 4'd2;
    localparam S_ADDR     = 4'd3;
    localparam S_BEATS    = 4'd4;
    localparam S_PAYLOAD  = 4'd5;
    localparam S_SEND_AW  = 4'd6;
    localparam S_SEND_W   = 4'd7;
    localparam S_WAIT     = 4'd8;
    localparam S_RESPONSE = 4'd9;

    reg [3:0] state;

    reg [63:0] addr_reg;
    reg [7:0] beats_reg;

    reg [2:0] addr_byte_count;
    reg [3:0] rx_beat_index;
    reg [3:0] rx_byte_index;
    reg [3:0] beat_index;

    reg [127:0] wdata_reg;
    reg [127:0] payload_words [0:15];

    reg b_seen;
    reg cxl_done;
    reg [1:0] bresp_reg;

    reg [7:0] tx_index;

    reg [31:0] output_bytes;
    reg [15:0] output_words;
    reg [15:0] output_flits;

    reg [31:0] stall_count;
    reg [31:0] current_stall_run;
    reg [31:0] max_stall_run;

    integer i;

    assign busy = (state != S_IDLE);

    assign axi_awaddr  = addr_reg;
    assign axi_awlen   = beats_reg - 1'b1;
    assign axi_awsize  = 3'd4;
    assign axi_awburst = 2'b01;
    assign axi_awvalid = (state == S_SEND_AW);

    assign axi_wdata  = wdata_reg;
    assign axi_wstrb  = 16'hFFFF;
    assign axi_wlast  = (beat_index == beats_reg - 1'b1);
    assign axi_wvalid = (state == S_SEND_W);

    assign axi_bready = 1'b1;

    assign tx_valid = (state == S_RESPONSE);

    function [4:0] count_keep;
        input [15:0] keep;
        integer k;
        begin
            count_keep = 5'd0;
            for (k = 0; k < 16; k = k + 1)
                count_keep = count_keep + keep[k];
        end
    endfunction

    always @* begin
        tx_data = 8'h00;

        case (tx_index)
            8'd0:  tx_data = 8'h5A;
            8'd1:  tx_data = 8'hA5;

            8'd2:
                tx_data = (!error && bresp_reg == 2'b00) ? 8'h00 : 8'h01;

            8'd3:  tx_data = output_bytes[7:0];
            8'd4:  tx_data = output_bytes[15:8];
            8'd5:  tx_data = output_bytes[23:16];
            8'd6:  tx_data = output_bytes[31:24];

            8'd7:  tx_data = output_words[7:0];
            8'd8:  tx_data = output_words[15:8];

            8'd9:  tx_data = output_flits[7:0];
            8'd10: tx_data = output_flits[15:8];

            8'd11: tx_data = stall_count[7:0];
            8'd12: tx_data = stall_count[15:8];
            8'd13: tx_data = stall_count[23:16];
            8'd14: tx_data = stall_count[31:24];

            8'd15: tx_data = max_stall_run[7:0];
            8'd16: tx_data = max_stall_run[15:8];
            8'd17: tx_data = max_stall_run[23:16];
            8'd18: tx_data = max_stall_run[31:24];

            8'd19: tx_data = {7'd0, stall_seen};
            8'd20: tx_data = {7'd0, cxl_done};

            default: tx_data = 8'h00;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;

            addr_reg <= 64'd0;
            beats_reg <= 8'd0;

            addr_byte_count <= 3'd0;
            rx_beat_index <= 4'd0;
            rx_byte_index <= 4'd0;
            beat_index <= 4'd0;

            wdata_reg <= 128'd0;

            b_seen <= 1'b0;
            cxl_done <= 1'b0;
            bresp_reg <= 2'b00;

            tx_index <= 8'd0;

            output_bytes <= 32'd0;
            output_words <= 16'd0;
            output_flits <= 16'd0;

            stall_count <= 32'd0;
            current_stall_run <= 32'd0;
            max_stall_run <= 32'd0;

            done <= 1'b0;
            stall_seen <= 1'b0;
            error <= 1'b0;

            for (i = 0; i < 16; i = i + 1)
                payload_words[i] <= 128'd0;

        end else begin

            if (!enable) begin
                state <= S_IDLE;

                done <= 1'b0;
                error <= 1'b0;
                stall_seen <= 1'b0;

                b_seen <= 1'b0;
                cxl_done <= 1'b0;

                stall_count <= 32'd0;
                current_stall_run <= 32'd0;
                max_stall_run <= 32'd0;

                output_bytes <= 32'd0;
                output_words <= 16'd0;
                output_flits <= 16'd0;

                tx_index <= 8'd0;

            end else begin

                if (axi_wvalid && !axi_wready) begin
                    stall_seen <= 1'b1;
                    stall_count <= stall_count + 1'b1;
                    current_stall_run <= current_stall_run + 1'b1;

                    if ((current_stall_run + 1'b1) > max_stall_run)
                        max_stall_run <= current_stall_run + 1'b1;
                end else begin
                    current_stall_run <= 32'd0;
                end

                if (axi_bvalid) begin
                    b_seen <= 1'b1;
                    bresp_reg <= axi_bresp;
                end

                if (cxl_valid) begin
                    output_bytes <= output_bytes + count_keep(cxl_keep);
                    output_words <= output_words + 1'b1;

                    if (cxl_flit_last)
                        output_flits <= output_flits + 1'b1;

                    if (cxl_last)
                        cxl_done <= 1'b1;
                end

                case (state)

                    S_IDLE: begin
                        done <= 1'b0;

                        if (rx_valid && rx_data == 8'hA5) begin
                            error <= 1'b0;
                            stall_seen <= 1'b0;

                            stall_count <= 32'd0;
                            current_stall_run <= 32'd0;
                            max_stall_run <= 32'd0;

                            output_bytes <= 32'd0;
                            output_words <= 16'd0;
                            output_flits <= 16'd0;

                            b_seen <= 1'b0;
                            cxl_done <= 1'b0;

                            addr_byte_count <= 3'd0;

                            state <= S_MAGIC2;
                        end
                    end

                    S_MAGIC2: begin
                        if (rx_valid) begin
                            if (rx_data == 8'h5A)
                                state <= S_CMD;
                            else
                                state <= S_IDLE;
                        end
                    end

                    S_CMD: begin
                        if (rx_valid) begin
                            if (rx_data == 8'h01) begin
                                addr_byte_count <= 3'd0;
                                state <= S_ADDR;
                            end else begin
                                error <= 1'b1;
                                tx_index <= 8'd0;
                                state <= S_RESPONSE;
                            end
                        end
                    end

                    S_ADDR: begin
                        if (rx_valid) begin
                            addr_reg[8*addr_byte_count +: 8] <= rx_data;

                            if (addr_byte_count == 3'd7)
                                state <= S_BEATS;
                            else
                                addr_byte_count <= addr_byte_count + 1'b1;
                        end
                    end

                    S_BEATS: begin
                        if (rx_valid) begin
                            if ((rx_data >= 8'd1) &&
                                (rx_data <= 8'd16)) begin

                                beats_reg <= rx_data;
                                rx_beat_index <= 4'd0;
                                rx_byte_index <= 4'd0;

                                for (i = 0; i < 16; i = i + 1)
                                    payload_words[i] <= 128'd0;

                                state <= S_PAYLOAD;

                            end else begin
                                error <= 1'b1;
                                tx_index <= 8'd0;
                                state <= S_RESPONSE;
                            end
                        end
                    end

                    S_PAYLOAD: begin
                        if (rx_valid) begin

                            payload_words[rx_beat_index]
                                [8*rx_byte_index +: 8] <= rx_data;

                            if (rx_byte_index == 4'd15) begin

                                rx_byte_index <= 4'd0;

                                if (rx_beat_index == beats_reg - 1'b1) begin
                                    beat_index <= 4'd0;
                                    state <= S_SEND_AW;
                                end else begin
                                    rx_beat_index <= rx_beat_index + 1'b1;
                                end

                            end else begin
                                rx_byte_index <= rx_byte_index + 1'b1;
                            end
                        end
                    end

                    S_SEND_AW: begin
                        if (axi_awvalid && axi_awready) begin
                            wdata_reg <= payload_words[0];
                            beat_index <= 4'd0;
                            state <= S_SEND_W;
                        end
                    end

                    S_SEND_W: begin
                        if (axi_wvalid && axi_wready) begin

                            if (axi_wlast) begin
                                state <= S_WAIT;
                            end else begin
                                beat_index <= beat_index + 1'b1;
                                wdata_reg <= payload_words[beat_index + 1'b1];
                            end

                        end
                    end

                    S_WAIT: begin
                        if (b_seen && cxl_done) begin
                            tx_index <= 8'd0;
                            state <= S_RESPONSE;
                        end
                    end

                    S_RESPONSE: begin
                        if (tx_ready) begin
                            if (tx_index == 8'd20) begin
                                done <= 1'b1;
                                state <= S_IDLE;
                            end else begin
                                tx_index <= tx_index + 1'b1;
                            end
                        end
                    end

                    default:
                        state <= S_IDLE;

                endcase
            end
        end
    end

endmodule
