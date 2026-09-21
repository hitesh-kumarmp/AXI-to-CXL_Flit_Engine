`timescale 1ns / 1ps

module tb_egress;

    reg clk;
    reg rst_n;

    reg         in_valid;
    wire        in_ready;
    reg [127:0] in_data;
    reg [15:0]  in_keep;
    reg         in_last;
    reg         in_flit_last;
    reg         in_bank;
    reg [3:0]   in_word_index;

    reg [63:0]  header_data;

    wire         cxl_valid;
    reg          cxl_ready;
    wire [127:0] cxl_data;
    wire [15:0]  cxl_keep;
    wire [63:0]  cxl_header;
    wire         cxl_header_valid;
    wire         cxl_last;
    wire         cxl_flit_last;
    wire         cxl_flit_start;
    wire         cxl_bank;
    wire [3:0]   cxl_word_index;

    integer out_count;

    egress dut (
        .clk              (clk),
        .rst_n            (rst_n),

        .in_valid         (in_valid),
        .in_ready         (in_ready),
        .in_data          (in_data),
        .in_keep          (in_keep),
        .in_last          (in_last),
        .in_flit_last     (in_flit_last),
        .in_bank          (in_bank),
        .in_word_index    (in_word_index),

        .header_data      (header_data),

        .cxl_valid        (cxl_valid),
        .cxl_ready        (cxl_ready),
        .cxl_data         (cxl_data),
        .cxl_keep         (cxl_keep),
        .cxl_header      (cxl_header),
        .cxl_header_valid (cxl_header_valid),
        .cxl_last         (cxl_last),
        .cxl_flit_last    (cxl_flit_last),
        .cxl_flit_start   (cxl_flit_start),
        .cxl_bank         (cxl_bank),
        .cxl_word_index   (cxl_word_index)
    );

    always #5 clk = ~clk;

    task send_word;
        input [127:0] data;
        input [15:0]  keep;
        input         last;
        input         flit_last;
        input         bank;
        input [3:0]   word_index;

        begin
            @(negedge clk);

            in_data       = data;
            in_keep       = keep;
            in_last       = last;
            in_flit_last  = flit_last;
            in_bank       = bank;
            in_word_index = word_index;
            in_valid      = 1'b1;

            while (!in_ready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            in_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (cxl_valid && cxl_ready) begin

            $display(
                "%0t CXL=%0d BANK=%b WORD=%0d DATA=%h KEEP=%h START=%b FLIT_LAST=%b LAST=%b HEADER=%h",
                $time,
                out_count,
                cxl_bank,
                cxl_word_index,
                cxl_data,
                cxl_keep,
                cxl_flit_start,
                cxl_flit_last,
                cxl_last,
                cxl_header
            );

            if (out_count == 0) begin

                if (!cxl_flit_start) begin
                    $display("ERROR: first flit start missing");
                    $finish;
                end

                if (!cxl_header_valid) begin
                    $display("ERROR: first header missing");
                    $finish;
                end

                if (cxl_bank != 1'b0) begin
                    $display("ERROR: first bank wrong");
                    $finish;
                end

                if (cxl_flit_last != 1'b1) begin
                    $display("ERROR: first flit last missing");
                    $finish;
                end

                if (cxl_keep != 16'hFC00) begin
                    $display("ERROR: first keep wrong");
                    $finish;
                end

            end

            if (out_count == 1) begin

                if (!cxl_flit_start) begin
                    $display("ERROR: second flit start missing");
                    $finish;
                end

                if (!cxl_header_valid) begin
                    $display("ERROR: second header missing");
                    $finish;
                end

                if (cxl_bank != 1'b1) begin
                    $display("ERROR: second bank wrong");
                    $finish;
                end

                if (cxl_word_index != 4'd0) begin
                    $display("ERROR: second word index wrong");
                    $finish;
                end

            end

            if (out_count == 2) begin

                if (cxl_flit_start) begin
                    $display("ERROR: false flit start");
                    $finish;
                end

                if (cxl_header_valid) begin
                    $display("ERROR: unexpected header");
                    $finish;
                end

                if (cxl_keep != 16'h03FF) begin
                    $display("ERROR: final keep wrong");
                    $finish;
                end

                if (!cxl_last) begin
                    $display("ERROR: final last missing");
                    $finish;
                end

            end

            if (cxl_valid &&
                cxl_ready)
                out_count = out_count + 1;
        end
    end

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        in_valid      = 1'b0;
        in_data       = 128'd0;
        in_keep       = 16'd0;
        in_last       = 1'b0;
        in_flit_last  = 1'b0;
        in_bank       = 1'b0;
        in_word_index = 4'd0;

        header_data = 64'h1122_3344_5566_7788;

        cxl_ready = 1'b1;

        out_count = 0;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        // First flit contains the final word of bank 0.
        send_word(
            128'hAA00_BB11_CC22_DD33_EE44_FF55_6677_8899,
            16'hFC00,
            1'b0,
            1'b1,
            1'b0,
            4'hF
        );

        // Next flit starts in bank 1.
        send_word(
            128'h0011_2233_4455_6677_8899_AABB_CCDD_EEFF,
            16'hFFFF,
            1'b0,
            1'b0,
            1'b1,
            4'h0
        );

        send_word(
            128'h1020_3040_5060_7080_90A0_B0C0_D0E0_F000,
            16'h03FF,
            1'b1,
            1'b1,
            1'b1,
            4'h1
        );

        repeat (5)
            @(posedge clk);

        if (out_count != 3) begin
            $display("EGRESS TB FAILED: got %0d outputs", out_count);
            $finish;
        end

        $display("EGRESS TB PASSED");
        $finish;

    end

endmodule