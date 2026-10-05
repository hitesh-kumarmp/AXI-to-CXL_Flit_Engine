`timescale 1ns / 1ps

module axi_hw_traffic_gen #(
    parameter NUM_BURSTS  = 10000,
    parameter BURST_BEATS = 16
)(
    input         clk,
    input         rst_n,
    input         start,

    output reg [63:0] axi_awaddr,
    output reg [7:0]  axi_awlen,
    output reg [2:0]  axi_awsize,
    output reg [1:0]  axi_awburst,
    output reg        axi_awvalid,
    input             axi_awready,

    output reg [127:0] axi_wdata,
    output reg [15:0]  axi_wstrb,
    output reg         axi_wlast,
    output reg         axi_wvalid,
    input              axi_wready,

    input             axi_bvalid,
    input      [1:0]  axi_bresp,
    output            axi_bready,

    input             cxl_valid,
    input      [15:0] cxl_keep,
    input             cxl_flit_last,
    

    output            running,
    output reg        done,
    output reg        stall_seen,
    output reg        error,

    output reg [31:0] stall_count,
    output reg [31:0] max_stall_run,
    output reg [31:0] output_byte_count,
    output reg [31:0] output_word_count,
    output reg [31:0] output_flit_count
);

    localparam S_IDLE  = 3'd0;
    localparam S_AW    = 3'd1;
    localparam S_W     = 3'd2;
    localparam S_B     = 3'd3;
    localparam S_DRAIN = 3'd4;
    localparam S_DONE  = 3'd5;

    localparam EXPECTED_BYTES =
        NUM_BURSTS * BURST_BEATS * 16;

    reg [2:0] state;

    reg [31:0] burst_count;
    reg [7:0]  beat_count;

    reg [7:0]  current_offset;

    reg [31:0] current_stall_run;

    integer i;

    function [127:0] make_word;
        input [31:0] burst_id;
        input [7:0]  beat_id;
        input [7:0]  offset_id;

        reg [31:0] x;
        integer j;

        begin

            x =
                32'h1ACE_B00C ^
                burst_id ^
                {24'd0, beat_id} ^
                {24'd0, offset_id};

            for (j = 0; j < 16; j = j + 1) begin

                x = {
                    x[30:0],
                    x[31] ^ x[21] ^ x[1] ^ x[0]
                };

                make_word[j*8 +: 8] =
                    x[7:0];

            end
        end
    endfunction

    function [5:0] keep_bytes;
        input [15:0] keep;
        integer k;
        begin

            keep_bytes = 6'd0;

            for (k = 0; k < 16; k = k + 1) begin

                if (keep[k])
                    keep_bytes = keep_bytes + 1'b1;

            end
        end
    endfunction

    assign running =
        (state != S_IDLE) &&
        (state != S_DONE);

    assign axi_bready =
        1'b1;

    assign cxl_ready =
        1'b1;

    always @* begin

        axi_awaddr  = 64'd0;
        axi_awlen   = BURST_BEATS - 1;
        axi_awsize  = 3'd4;
        axi_awburst = 2'b01;
        axi_awvalid = 1'b0;

        axi_wdata  = 128'd0;
        axi_wstrb  = 16'hffff;
        axi_wlast  = 1'b0;
        axi_wvalid = 1'b0;

        if (state == S_AW) begin

            axi_awaddr =
                64'h0000_0000_1000_0000 +
                (burst_count << 8) +
                current_offset;

            axi_awvalid =
                1'b1;

        end

        if (state == S_W) begin

            axi_wdata =
                make_word(
                    burst_count,
                    beat_count,
                    current_offset
                );

            axi_wstrb =
                16'hffff;

            axi_wlast =
                (beat_count == BURST_BEATS - 1);

            axi_wvalid =
                1'b1;

        end
    end

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state =
                S_IDLE;

            burst_count =
                32'd0;

            beat_count =
                8'd0;

            current_offset =
                8'd0;

            done =
                1'b0;

            stall_seen =
                1'b0;

            error =
                1'b0;

            stall_count =
                32'd0;

            max_stall_run =
                32'd0;

            current_stall_run =
                32'd0;

            output_byte_count =
                32'd0;

            output_word_count =
                32'd0;

            output_flit_count =
                32'd0;

        end
        else begin

            // Measure real AXI backpressure.
            if (axi_wvalid && !axi_wready) begin

                stall_seen <= 1'b1;

                stall_count <=
                    stall_count + 1'b1;

                current_stall_run <=
                    current_stall_run + 1'b1;

                if (current_stall_run + 1'b1 >
                    max_stall_run)

                    max_stall_run <=
                        current_stall_run + 1'b1;

            end
            else begin

                current_stall_run <=
                    32'd0;

            end

            // Count CXL output.
            if (cxl_valid && cxl_ready) begin

                output_word_count <=
                    output_word_count + 1'b1;

                output_byte_count <=
                    output_byte_count +
                    keep_bytes(cxl_keep);

                if (cxl_flit_last)
                    output_flit_count <=
                        output_flit_count + 1'b1;

                if (
                    output_byte_count +
                    keep_bytes(cxl_keep) >
                    EXPECTED_BYTES
                )
                    error <= 1'b1;

            end

            case (state)

                S_IDLE: begin

                    if (start) begin

                        burst_count <=
                            32'd0;

                        beat_count <=
                            8'd0;

                        current_offset <=
                            8'd0;

                        done <=
                            1'b0;

                        stall_seen <=
                            1'b0;

                        error <=
                            1'b0;

                        stall_count <=
                            32'd0;

                        max_stall_run <=
                            32'd0;

                        current_stall_run <=
                            32'd0;

                        output_byte_count <=
                            32'd0;

                        output_word_count <=
                            32'd0;

                        output_flit_count <=
                            32'd0;

                        state <=
                            S_AW;

                    end
                end

                S_AW: begin

                    if (axi_awvalid &&
                        axi_awready) begin

                        beat_count <=
                            8'd0;

                        state <=
                            S_W;

                    end
                end

                S_W: begin

                    if (axi_wvalid &&
                        axi_wready) begin

                        if (beat_count ==
                            BURST_BEATS - 1) begin

                            state <=
                                S_B;

                        end
                        else begin

                            beat_count <=
                                beat_count + 1'b1;

                        end
                    end
                end

                S_B: begin

                    if (axi_bvalid) begin

                        if (axi_bresp != 2'b00)
                            error <= 1'b1;

                        if (burst_count ==
                            NUM_BURSTS - 1) begin

                            state <=
                                S_DRAIN;

                        end
                        else begin

                            burst_count <=
                                burst_count + 1'b1;

                            current_offset <=
                                burst_count[7:0] + 1'b1;

                            state <=
                                S_AW;

                        end
                    end
                end

                S_DRAIN: begin

                    if (output_byte_count >=
                        EXPECTED_BYTES) begin

                        done <=
                            1'b1;

                        state <=
                            S_DONE;

                    end
                end

                S_DONE: begin

                    // Drop the start switch to re-arm the test.
                    if (!start)
                        state <=
                            S_IDLE;
                end

                default: begin
                    state <=
                        S_IDLE;
                end

            endcase
        end
    end

endmodule