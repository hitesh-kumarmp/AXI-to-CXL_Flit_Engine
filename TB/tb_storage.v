`timescale 1ns / 1ps

module tb_storage;

    reg clk;
    reg rst_n;

    reg         in_valid;
    wire        in_ready;
    reg [127:0] in_data;
    reg [15:0]  in_keep;
    reg         in_last;
    reg         in_flit_last;
    reg [3:0]   in_word_index;

    wire        out_valid;
    reg         out_ready;
    wire [127:0] out_data;
    wire [15:0]  out_keep;
    wire         out_last;
    wire         out_flit_last;
    wire         out_bank;
    wire [3:0]   out_word_index;

    integer in_count;
    integer out_count;

    reg [7:0] expected_byte;

    storage dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .in_valid       (in_valid),
        .in_ready       (in_ready),
        .in_data        (in_data),
        .in_keep        (in_keep),
        .in_last        (in_last),
        .in_flit_last   (in_flit_last),
        .in_word_index  (in_word_index),

        .out_valid      (out_valid),
        .out_ready      (out_ready),
        .out_data       (out_data),
        .out_keep        (out_keep),
        .out_last       (out_last),
        .out_flit_last  (out_flit_last),
        .out_bank       (out_bank),
        .out_word_index (out_word_index)
    );

    always #5 clk = ~clk;

    task send_word;
        input [127:0] data;
        input [3:0]   word_index;
        input         flit_last;
        input         last;
        begin
            @(negedge clk);

            in_data       = data;
            in_keep       = 16'hFFFF;
            in_word_index = word_index;
            in_flit_last  = flit_last;
            in_last       = last;
            in_valid      = 1'b1;

            while (!in_ready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            in_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (out_valid && out_ready) begin

            expected_byte = out_count;

            $display(
                "%0t OUT=%0d BANK=%b WORD=%0d DATA=%h FLIT_LAST=%b LAST=%b",
                $time,
                out_count,
                out_bank,
                out_word_index,
                out_data,
                out_flit_last,
                out_last
            );

            if (out_data !== {120'd0, expected_byte}) begin
                $display("ERROR: DATA MISMATCH");
                $finish;
            end

            if (out_keep !== 16'hFFFF) begin
                $display("ERROR: KEEP MISMATCH");
                $finish;
            end

            out_count = out_count + 1;
        end
    end

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        in_valid      = 1'b0;
        in_data       = 128'd0;
        in_keep       = 16'h0000;
        in_last       = 1'b0;
        in_flit_last  = 1'b0;
        in_word_index = 4'd0;

        out_ready = 1'b1;

        in_count  = 0;
        out_count = 0;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        // First flit goes into bank 0.
        for (in_count = 0; in_count < 16; in_count = in_count + 1) begin

            send_word(
                {120'd0, in_count},
                in_count,
                (in_count == 15),
                1'b0
            );

        end

        // Second flit goes into bank 1.
        for (in_count = 16; in_count < 32; in_count = in_count + 1) begin

            send_word(
                {120'd0, in_count},
                in_count - 16,
                (in_count == 31),
                (in_count == 31)
            );

        end

        repeat (20)
            @(posedge clk);

        if (out_count != 32) begin
            $display(
                "STORAGE TB FAILED: expected 32, got %0d",
                out_count
            );
            $finish;
        end

        $display("STORAGE TB PASSED");
        $finish;

    end

endmodule