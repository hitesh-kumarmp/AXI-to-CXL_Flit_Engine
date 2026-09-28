`timescale 1ns / 1ps

module tb_profile_e;

    parameter DATA_WIDTH = 128;
    parameter BEATS      = 64;
    parameter TIMEOUT    = 200000;

    reg clk;
    reg rst_n;

    reg  [63:0]  s_axi_awaddr;
    reg  [7:0]   s_axi_awlen;
    reg  [2:0]   s_axi_awsize;
    reg  [1:0]   s_axi_awburst;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

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

    integer offsets [0:4];

    integer case_num;
    integer beat_num;
    integer byte_num;

    integer input_words;
    integer output_words;
    integer output_bytes;

    integer ready_low_count;
    integer cycles_elapsed;

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
        .s_axi_wlast       (s_axi_wlast),
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
            x = 32'h1357_9BDF ^ n;

            for (j = 0; j < 16; j = j + 1) begin
                x = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
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
            s_axi_bready  = 1'b1;
            cxl_ready     = 1'b1;

            repeat (5)
                @(negedge clk);

            rst_n = 1'b1;

            repeat (3)
                @(negedge clk);

            input_words   = 0;
            output_words  = 0;
            output_bytes  = 0;
            ready_low_count = 0;
            cycles_elapsed = 0;
        end
    endtask

    task send_aw;
        input integer offset;

        begin
            s_axi_awaddr  = 64'h0000_0000_1000_0000 + offset;
            s_axi_awlen   = BEATS - 1;
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

            input_words = input_words + 1;
        end
    endtask

    task wait_b;
        begin
            while (!s_axi_bvalid)
                @(negedge clk);

            if (s_axi_bresp != 2'b00)
                $display("BRESP ERROR = %b", s_axi_bresp);

            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task run_case;
        input integer offset;

        begin
            reset_case;

            start_cycle = cycles_elapsed;

            send_aw(offset);

            for (beat_num = 0; beat_num < BEATS; beat_num = beat_num + 1) begin

                word_data = make_word(
                    offset * 1000 + beat_num
                );

                send_w(
                    word_data,
                    (beat_num == BEATS - 1)
                );
            end

            wait_b;

            while (!cxl_flit_last &&
                   (cycles_elapsed - start_cycle < TIMEOUT))
                @(negedge clk);

            repeat (100)
                @(negedge clk);

            end_cycle = cycles_elapsed;

            $display("");
            $display("----------------------------------------");
            $display("PROFILE E OFFSET = %0d", offset);
            $display("----------------------------------------");
            $display("INPUT WORDS       = %0d", input_words);
            $display("OUTPUT WORDS      = %0d", output_words);
            $display("OUTPUT BYTES      = %0d", output_bytes);
            $display("WREADY LOW COUNT  = %0d", ready_low_count);
            $display("ACTIVE CYCLES     = %0d",
                     end_cycle - start_cycle);

            if (input_words != 0)
                $display("WORD RATIO x1000  = %0d",
                         (output_words * 1000) / input_words);

            if ((end_cycle - start_cycle) != 0)
                $display("INPUT WORDS/CYCLE  = %0d",
                         (input_words * 1000) /
                         (end_cycle - start_cycle));

            $display("----------------------------------------");
        end
    endtask

    initial begin
        offsets[0] = 0;
        offsets[1] = 1;
        offsets[2] = 15;
        offsets[3] = 128;
        offsets[4] = 255;

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

        input_words  = 0;
        output_words = 0;
        output_bytes = 0;

        ready_low_count = 0;
        cycles_elapsed  = 0;

        #20;

        for (case_num = 0; case_num < 5; case_num = case_num + 1)
            run_case(offsets[case_num]);

        $display("");
        $display("========================================");
        $display("PROFILE E COMPLETE");
        $display("========================================");

        $finish;
    end

    always @(posedge clk) begin
        if (rst_n)
            cycles_elapsed = cycles_elapsed + 1;
    end

    always @(negedge clk) begin
        if (rst_n) begin

            if (s_axi_wvalid && !s_axi_wready)
                ready_low_count = ready_low_count + 1;

            if (cxl_valid && cxl_ready) begin

                output_words = output_words + 1;

                for (byte_num = 0; byte_num < 16; byte_num = byte_num + 1) begin
                    if (cxl_keep[byte_num])
                        output_bytes = output_bytes + 1;
                end
            end
        end
    end

endmodule