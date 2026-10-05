`timescale 1ns / 1ps

module tb_profile_d;

    parameter NUM_BURSTS = 10000;
    parameter MAX_BEATS  = 16;
    parameter MAX_BYTES  = 3000000;
    parameter TIMEOUT    = 5000000;

    reg clk;
    reg rst_n;

    reg         s_axi_awvalid;
    reg [31:0]  s_axi_awaddr;
    reg [7:0]   s_axi_awlen;
    reg [2:0]   s_axi_awsize;
    reg [1:0]   s_axi_awburst;
    wire        s_axi_awready;

    reg         s_axi_wvalid;
    reg [127:0] s_axi_wdata;
    reg [15:0]  s_axi_wstrb;
    reg         s_axi_wlast;
    wire        s_axi_wready;

    wire        s_axi_bvalid;
    wire [1:0]  s_axi_bresp;
    reg         s_axi_bready;

    wire         cxl_valid;
    wire [127:0] cxl_data;
    wire [15:0]  cxl_keep;
    wire         cxl_flit_last;
    reg          cxl_ready;

    reg [7:0] expected_mem [0:MAX_BYTES-1];

    integer expected_count;
    integer output_count;
    integer output_word_count;
    integer output_flit_count;

    integer wready_low_count;

    integer protocol_errors;
    integer response_errors;
    integer completion_errors;
    integer data_errors;
    integer unexpected_bytes;

    integer burst_num;
    integer beat_num;
    integer byte_num;
    integer beats;
    integer offset;
    integer gap;
    integer rand_val;
    integer seed;
    integer cycle_count;

    reg [127:0] word_data;

    reg         first_error_seen;
    integer     first_error_byte;
    integer     first_error_word;
    integer     first_error_lane;
    reg [7:0]   first_expected;
    reg [7:0]   first_actual;

    // W-channel stall tracking
    reg         w_stall_active;
    reg [127:0] w_stall_data;
    reg [15:0]  w_stall_strb;
    reg         w_stall_last;

    integer stall_log_count;
    integer current_stall_run;
    integer max_stall_run;

    top_flit_engine dut (
        .clk           (clk),
        .rst_n         (rst_n),

        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awlen   (s_axi_awlen),
        .s_axi_awsize  (s_axi_awsize),
        .s_axi_awburst (s_axi_awburst),
        .s_axi_awready (s_axi_awready),

        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),
        .s_axi_wready  (s_axi_wready),

        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bready  (s_axi_bready),

        .cxl_valid     (cxl_valid),
        .cxl_ready     (cxl_ready),
        .cxl_data      (cxl_data),
        .cxl_keep      (cxl_keep),
        .cxl_flit_last (cxl_flit_last)
    );

    always #5 clk = ~clk;

    function [127:0] make_word;
        input integer s;
        integer j;
        reg [31:0] x;

        begin
            x = 32'h1ACE_B00C ^ s;

            for (j = 0; j < 16; j = j + 1) begin

                x = {
                    x[30:0],
                    x[31] ^ x[21] ^ x[1] ^ x[0]
                };

                make_word[j*8 +: 8] = x[7:0];

            end
        end
    endfunction

    task send_aw;
        input [31:0] addr;
        input integer burst_beats;

        begin

            s_axi_awaddr  = addr;
            s_axi_awlen   = burst_beats - 1;
            s_axi_awsize  = 3'd4;
            s_axi_awburst = 2'b01;
            s_axi_awvalid = 1'b1;

            while (!s_axi_awready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            s_axi_awvalid = 1'b0;

        end
    endtask

    task send_w;
        input [127:0] data_in;
        input          last_in;

        begin

            s_axi_wdata  = data_in;
            s_axi_wstrb  = 16'hffff;
            s_axi_wlast  = last_in;
            s_axi_wvalid = 1'b1;

            // Hold the transaction until the actual handshake.
            while (!s_axi_wready)
                @(negedge clk);

            @(posedge clk);

            @(negedge clk);

            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;

        end
    endtask

    task wait_b;
        begin

            while (!s_axi_bvalid)
                @(negedge clk);

            if (s_axi_bresp != 2'b00)
                response_errors = response_errors + 1;

            @(posedge clk);
            @(negedge clk);

        end
    endtask

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        s_axi_awvalid = 1'b0;
        s_axi_awaddr  = 32'd0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'd4;
        s_axi_awburst = 2'b01;

        s_axi_wvalid = 1'b0;
        s_axi_wdata  = 128'd0;
        s_axi_wstrb  = 16'hffff;
        s_axi_wlast  = 1'b0;

        s_axi_bready = 1'b1;
        cxl_ready    = 1'b1;

        expected_count    = 0;
        output_count      = 0;
        output_word_count = 0;
        output_flit_count = 0;

        wready_low_count  = 0;

        protocol_errors   = 0;
        response_errors   = 0;
        completion_errors = 0;
        data_errors       = 0;
        unexpected_bytes  = 0;

        cycle_count = 0;

        first_error_seen = 1'b0;
        first_error_byte = 0;
        first_error_word = 0;
        first_error_lane = 0;
        first_expected   = 8'h00;
        first_actual     = 8'h00;

        w_stall_active   = 1'b0;
        w_stall_data     = 128'd0;
        w_stall_strb     = 16'd0;
        w_stall_last     = 1'b0;

        stall_log_count  = 0;
        current_stall_run = 0;
        max_stall_run     = 0;

        seed = 32'h13579BDF;

        #50;
        rst_n = 1'b1;

        for (
            burst_num = 0;
            burst_num < NUM_BURSTS;
            burst_num = burst_num + 1
        ) begin

            rand_val = $random(seed);

            if (rand_val < 0)
                rand_val = -rand_val;

            offset = rand_val % 256;

            rand_val = $random(seed);

            if (rand_val < 0)
                rand_val = -rand_val;

            beats = 1 + (rand_val % MAX_BEATS);

            send_aw(
                32'h1000_0000 +
                offset +
                (burst_num << 8),
                beats
            );

            for (
                beat_num = 0;
                beat_num < beats;
                beat_num = beat_num + 1
            ) begin

                word_data = make_word(
                    burst_num * 257 +
                    beat_num * 31 +
                    offset
                );

                for (
                    byte_num = 0;
                    byte_num < 16;
                    byte_num = byte_num + 1
                ) begin

                    expected_mem[expected_count] =
                        word_data[byte_num*8 +: 8];

                    expected_count =
                        expected_count + 1;

                end

                send_w(
                    word_data,
                    (beat_num == beats - 1)
                );

            end

            wait_b;

            rand_val = $random(seed);

            if (rand_val < 0)
                rand_val = -rand_val;

            gap = rand_val % 4;

            repeat (gap)
                @(negedge clk);

        end

        $display("ALL INPUT BURSTS SENT");

        while (
            (output_count < expected_count) &&
            (cycle_count < TIMEOUT)
        )
            @(negedge clk);

        repeat (100)
            @(negedge clk);

        if (output_count != expected_count)
            completion_errors = completion_errors + 1;

        $display("");
        $display("========================================");
        $display("PROFILE D - RANDOMIZED DATA INTEGRITY");
        $display("========================================");

        $display("BURSTS              = %0d", NUM_BURSTS);
        $display("EXPECTED BYTES      = %0d", expected_count);
        $display("OUTPUT BYTES        = %0d", output_count);
        $display("OUTPUT WORDS        = %0d", output_word_count);
        $display("OUTPUT FLITS        = %0d", output_flit_count);

        $display("");
        $display("AXI W-CHANNEL");
        $display("WREADY LOW COUNT    = %0d", wready_low_count);
        $display("MAX STALL RUN       = %0d", max_stall_run);
        $display("STALLS LOGGED       = %0d", stall_log_count);

        $display("");
        $display("CHECKS");
        $display("DATA ERRORS         = %0d", data_errors);
        $display("UNEXPECTED BYTES    = %0d", unexpected_bytes);
        $display("PROTOCOL ERRORS     = %0d", protocol_errors);
        $display("RESPONSE ERRORS     = %0d", response_errors);
        $display("COMPLETION ERRORS   = %0d", completion_errors);

        $display(
            "FIFO DEPTH          = %0d",
            dut.u_flit_staging_fifo.DEPTH
        );

        if (first_error_seen) begin

            $display("");
            $display("========== FIRST REAL ERROR ==========");
            $display("BYTE        = %0d", first_error_byte);
            $display("WORD        = %0d", first_error_word);
            $display("LANE        = %0d", first_error_lane);
            $display("EXPECTED    = %02h", first_expected);
            $display("ACTUAL      = %02h", first_actual);
            $display(
                "FIFO DEPTH  = %0d",
                dut.u_flit_staging_fifo.DEPTH
            );
            $display("======================================");

        end

        $display("");
        $display("========== STALL SUMMARY ==========");

        if (stall_log_count == 0) begin
            $display("NO AXI W-CHANNEL STALLS OBSERVED");
        end
        else begin
            $display(
                "FIRST %0d STALL STARTS SHOWN ABOVE",
                stall_log_count
            );
        end

        $display("====================================");

        $display("");

        if ((data_errors == 0) &&
            (unexpected_bytes == 0) &&
            (protocol_errors == 0) &&
            (response_errors == 0) &&
            (completion_errors == 0)) begin

            $display("DATA INTEGRITY / AXI CHECK PASSED");

        end
        else begin

            $display("DATA INTEGRITY / AXI CHECK FAILED");

        end

        if (wready_low_count == 0)
            $display("ZERO-STALL REQUIREMENT PASSED");
        else
            $display("ZERO-STALL REQUIREMENT FAILED");

        $display("========================================");

        $finish;

    end

    // Cycle counter
    always @(posedge clk) begin

        if (rst_n)
            cycle_count = cycle_count + 1;

    end

    // AXI W-channel monitor
    always @(posedge clk) begin

        if (!rst_n) begin

            w_stall_active    = 1'b0;
            current_stall_run = 0;

        end
        else begin

            if (s_axi_wvalid && !s_axi_wready) begin

                wready_low_count =
                    wready_low_count + 1;

                current_stall_run =
                    current_stall_run + 1;

                if (current_stall_run > max_stall_run)
                    max_stall_run =
                        current_stall_run;

                // First cycle of a new continuous stall.
                if (!w_stall_active) begin

                    w_stall_active = 1'b1;

                    w_stall_data =
                        s_axi_wdata;

                    w_stall_strb =
                        s_axi_wstrb;

                    w_stall_last =
                        s_axi_wlast;

                    if (stall_log_count < 20) begin

                        stall_log_count =
                            stall_log_count + 1;

                        $display("");
                        $display(
                            "========== W STALL #%0d ==========",
                            stall_log_count
                        );
                        $display(
                            "TIME       = %0t ns",
                            $time
                        );
                        $display(
                            "BURST      = %0d",
                            burst_num
                        );
                        $display(
                            "BEAT       = %0d",
                            beat_num
                        );
                        $display(
                            "ADDR       = %08h",
                            s_axi_awaddr
                        );
                        $display(
                            "WLAST      = %b",
                            s_axi_wlast
                        );
                        $display(
                            "DATA       = %032h",
                            s_axi_wdata
                        );
                        $display(
                            "STALL RUN  = %0d",
                            current_stall_run
                        );
                        $display(
                            "================================="
                        );

                    end

                end
                else begin

                    // WDATA must remain stable while stalled.
                    if (s_axi_wdata !== w_stall_data) begin

                        protocol_errors =
                            protocol_errors + 1;

                        $display(
                            "PROTOCOL ERROR: WDATA changed while stalled at %0t ns",
                            $time
                        );

                    end

                    // WSTRB must remain stable while stalled.
                    if (s_axi_wstrb !== w_stall_strb) begin

                        protocol_errors =
                            protocol_errors + 1;

                        $display(
                            "PROTOCOL ERROR: WSTRB changed while stalled at %0t ns",
                            $time
                        );

                    end

                    // WLAST must remain stable while stalled.
                    if (s_axi_wlast !== w_stall_last) begin

                        protocol_errors =
                            protocol_errors + 1;

                        $display(
                            "PROTOCOL ERROR: WLAST changed while stalled at %0t ns",
                            $time
                        );

                    end

                end

            end
            else begin

                if (w_stall_active) begin

                    w_stall_active =
                        1'b0;

                    current_stall_run =
                        0;

                end

            end

        end

    end

    // CXL output scoreboard
    always @(negedge clk) begin

        if (rst_n) begin

            if (cxl_valid && cxl_ready) begin

                output_word_count =
                    output_word_count + 1;

                if (cxl_flit_last)
                    output_flit_count =
                        output_flit_count + 1;

                for (
                    byte_num = 0;
                    byte_num < 16;
                    byte_num = byte_num + 1
                ) begin

                    if (cxl_keep[byte_num]) begin

                        if (output_count < expected_count) begin

                            if (
                                cxl_data[byte_num*8 +: 8] !=
                                expected_mem[output_count]
                            ) begin

                                data_errors =
                                    data_errors + 1;

                                if (!first_error_seen) begin

                                    first_error_seen = 1'b1;

                                    first_error_byte =
                                        output_count;

                                    first_error_word =
                                        output_word_count;

                                    first_error_lane =
                                        byte_num;

                                    first_expected =
                                        expected_mem[
                                            output_count
                                        ];

                                    first_actual =
                                        cxl_data[
                                            byte_num*8 +: 8
                                        ];

                                end

                            end

                            output_count =
                                output_count + 1;

                        end
                        else begin

                            unexpected_bytes =
                                unexpected_bytes + 1;

                        end

                    end

                end

            end

        end

    end

endmodule