`timescale 1ns / 1ps

module tb_profile_g;

    parameter NUM_BURSTS = 1000;
    parameter TIMEOUT    = 5000000;

    reg clk;
    reg rst_n;

    reg  [63:0]  s_axi_awaddr;
    reg  [7:0]   s_axi_awlen;
    reg  [2:0]   s_axi_awsize;
    reg  [1:0]   s_axi_awburst;
    reg          s_axi_awvalid;
    wire         s_axi_awready;

    reg  [127:0] s_axi_wdata;
    reg  [15:0]  s_axi_wstrb;
    reg          s_axi_wlast;
    reg          s_axi_wvalid;
    wire         s_axi_wready;

    wire [1:0]   s_axi_bresp;
    wire         s_axi_bvalid;
    reg          s_axi_bready;

    wire         cxl_valid;
    reg          cxl_ready;
    wire [127:0] cxl_data;
    wire [15:0]  cxl_keep;
    wire [127:0] cxl_header;
    wire         cxl_header_valid;
    wire         cxl_last;
    wire         cxl_flit_last;
    wire         cxl_flit_start;
    wire         cxl_bank;
    wire [3:0]   cxl_word_index;

    integer burst_lengths [0:4];

    integer case_num;
    integer burst_num;
    integer beat_num;
    integer byte_num;

    integer burst_length;
    integer offset;
    integer rand_val;
    integer seed;

    integer input_bytes;
    integer output_bytes;

    integer backlog_bytes;
    integer max_backlog_bytes;
    integer max_backlog_words;

    integer wready_low_count;

    integer pack_block_cycles;
    integer max_pack_block_cycles;
    integer current_pack_block;

    integer protocol_errors;
    integer cycle_count;
    integer start_cycle;
    integer end_cycle;

    reg [127:0] word_data;

    top_flit_engine dut (
        .clk               (clk),
        .rst_n             (rst_n),

        .s_axi_awaddr      (s_axi_awaddr),
        .s_axi_awlen       (s_axi_awlen),
        .s_axi_awsize      (s_axi_awsize),
        .s_axi_awburst     (s_axi_awburst),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),

        .s_axi_wdata       (s_axi_wdata),
        .s_axi_wstrb       (s_axi_wstrb),
        .s_axi_wlast      (s_axi_wlast),
        .s_axi_wvalid      (s_axi_wvalid),
        .s_axi_wready      (s_axi_wready),

        .s_axi_bresp       (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (s_axi_bready),

        .cxl_valid         (cxl_valid),
        .cxl_ready         (cxl_ready),
        .cxl_data          (cxl_data),
        .cxl_keep          (cxl_keep),
        .cxl_header        (cxl_header),
        .cxl_header_valid  (cxl_header_valid),
        .cxl_last          (cxl_last),
        .cxl_flit_last     (cxl_flit_last),
        .cxl_flit_start    (cxl_flit_start),
        .cxl_bank          (cxl_bank),
        .cxl_word_index    (cxl_word_index)
    );

    always #5 clk = ~clk;

    function [127:0] make_word;
        input integer n;
        integer j;
        reg [31:0] x;

        begin
            x = 32'h9E37_79B9 ^ n;

            for (j = 0; j < 16; j = j + 1) begin
                x = {x[30:0],
                     x[31] ^ x[21] ^ x[1] ^ x[0]};

                make_word[j*8 +: 8] = x[7:0];
            end
        end
    endfunction

    task reset_case;
        begin
            rst_n = 1'b0;

            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;
            s_axi_wlast   = 1'b0;

            s_axi_bready = 1'b1;
            cxl_ready    = 1'b1;

            repeat (5)
                @(negedge clk);

            rst_n = 1'b1;

            repeat (3)
                @(negedge clk);

            input_bytes  = 0;
            output_bytes = 0;

            backlog_bytes     = 0;
            max_backlog_bytes = 0;
            max_backlog_words = 0;

            wready_low_count = 0;

            pack_block_cycles     = 0;
            max_pack_block_cycles = 0;
            current_pack_block    = 0;

            protocol_errors = 0;
            cycle_count     = 0;
        end
    endtask

    task send_aw;
        input integer aw_offset;
        input integer aw_beats;

        begin
            s_axi_awaddr =
                64'h0000_0000_3000_0000 + aw_offset;

            s_axi_awlen   = aw_beats - 1;
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
                protocol_errors = protocol_errors + 1;

            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task run_case;
        input integer test_burst_length;

        begin
            reset_case;

            burst_length = test_burst_length;
            start_cycle  = cycle_count;

            for (burst_num = 0;
                 burst_num < NUM_BURSTS;
                 burst_num = burst_num + 1) begin

                rand_val = $random(seed);

                if (rand_val < 0)
                    rand_val = -rand_val;

                offset = rand_val % 256;

                send_aw(
                    offset,
                    burst_length
                );

                for (beat_num = 0;
                     beat_num < burst_length;
                     beat_num = beat_num + 1) begin

                    word_data = make_word(
                        burst_num * 4096 +
                        beat_num * 37 +
                        offset
                    );

                    send_w(
                        word_data,
                        beat_num == burst_length - 1
                    );
                end

                wait_b;
            end

            $display("ALL INPUT BURSTS SENT");

            while ((output_bytes < input_bytes) &&
                   (cycle_count - start_cycle < TIMEOUT))
                @(negedge clk);

            repeat (100)
                @(negedge clk);

            end_cycle = cycle_count;

            if (output_bytes != input_bytes)
                protocol_errors = protocol_errors + 1;

            $display("");
            $display("========================================");
            $display("PROFILE G - BURST LENGTH = %0d", burst_length);
            $display("========================================");
            $display("BURSTS                  = %0d", NUM_BURSTS);
            $display("INPUT BYTES             = %0d", input_bytes);
            $display("OUTPUT BYTES            = %0d", output_bytes);
            $display("WREADY LOW COUNT        = %0d",
                     wready_low_count);
            $display("PACKER BLOCK CYCLES     = %0d",
                     pack_block_cycles);
            $display("MAX PACKER BLOCK        = %0d",
                     max_pack_block_cycles);
            $display("MAX BACKLOG BYTES       = %0d",
                     max_backlog_bytes);
            $display("MAX BACKLOG WORDS       = %0d",
                     max_backlog_words);
            $display("PROTOCOL ERRORS         = %0d",
                     protocol_errors);
            $display("TOTAL CYCLES            = %0d",
                     end_cycle - start_cycle);
            $display("========================================");
        end
    endtask

    initial begin

        burst_lengths[0] = 1;
        burst_lengths[1] = 2;
        burst_lengths[2] = 4;
        burst_lengths[3] = 8;
        burst_lengths[4] = 16;

        seed = 32'h51A7_D3C9;

        clk = 1'b0;
        rst_n = 1'b0;

        s_axi_awaddr  = 64'd0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'd4;
        s_axi_awburst = 2'b01;
        s_axi_awvalid = 1'b0;

        s_axi_wdata  = 128'd0;
        s_axi_wstrb  = 16'hffff;
        s_axi_wlast  = 1'b0;
        s_axi_wvalid = 1'b0;

        s_axi_bready = 1'b1;
        cxl_ready    = 1'b1;

        input_bytes  = 0;
        output_bytes = 0;

        #20;

        for (case_num = 0; case_num < 5; case_num = case_num + 1)
            run_case(burst_lengths[case_num]);

        $display("");
        $display("========================================");
        $display("PROFILE G COMPLETE");
        $display("========================================");

        $finish;
    end

    always @(posedge clk) begin
        if (rst_n)
            cycle_count = cycle_count + 1;
    end

    always @(negedge clk) begin
        if (rst_n) begin

            if (s_axi_wvalid && s_axi_wready)
                input_bytes = input_bytes + 16;

            if (cxl_valid && cxl_ready) begin
                for (byte_num = 0;
                     byte_num < 16;
                     byte_num = byte_num + 1) begin

                    if (cxl_keep[byte_num])
                        output_bytes = output_bytes + 1;
                end
            end

            if (s_axi_wvalid && !s_axi_wready)
                wready_low_count = wready_low_count + 1;

            if (dut.pack_valid && !dut.pack_ready) begin

                pack_block_cycles = pack_block_cycles + 1;
                current_pack_block = current_pack_block + 1;

                if (current_pack_block > max_pack_block_cycles)
                    max_pack_block_cycles =
                        current_pack_block;

            end
            else begin
                current_pack_block = 0;
            end

            backlog_bytes = input_bytes - output_bytes;

            if (backlog_bytes > max_backlog_bytes)
                max_backlog_bytes = backlog_bytes;

            max_backlog_words =
                (max_backlog_bytes + 15) / 16;
        end
    end

endmodule