`timescale 1ns / 1ps

module tb_packing;

    reg clk;
    reg rst_n;

    reg [127:0] in_data;
    reg [15:0]  in_keep;
    reg         in_valid;
    wire        in_ready;
    reg         in_last;

    reg         in_burst_start;
    reg [7:0]   in_burst_offset;
    reg [2:0]   in_burst_size;

    wire        out_valid;
    reg         out_ready;
    wire [127:0] out_data;
    wire [15:0]  out_keep;
    wire         out_last;
    wire         out_flit_last;
    wire [3:0]   out_word_index;
    wire [8:0]   out_flit_offset;

    integer out_count;

    packing dut (
        .clk             (clk),
        .rst_n           (rst_n),

        .in_data         (in_data),
        .in_keep         (in_keep),
        .in_valid        (in_valid),
        .in_ready        (in_ready),
        .in_last         (in_last),

        .in_burst_start  (in_burst_start),
        .in_burst_offset (in_burst_offset),
        .in_burst_size   (in_burst_size),

        .out_valid       (out_valid),
        .out_ready       (out_ready),
        .out_data        (out_data),
        .out_keep        (out_keep),
        .out_last        (out_last),
        .out_flit_last   (out_flit_last),
        .out_word_index  (out_word_index),
        .out_flit_offset (out_flit_offset)
    );

    always #5 clk = ~clk;

    task send_beat;
        input [127:0] data;
        input         last;
        input         start;
        begin
            @(negedge clk);

            in_data        = data;
            in_keep        = 16'hFFFF;
            in_last        = last;
            in_burst_start = start;

            in_valid = 1'b1;

            while (!in_ready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            in_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (out_valid && out_ready) begin

            $display(
                "%0t OUT %0d DATA=%h KEEP=%h WORD=%0d OFFSET=%0d FLIT_LAST=%b LAST=%b",
                $time,
                out_count,
                out_data,
                out_keep,
                out_word_index,
                out_flit_offset,
                out_flit_last,
                out_last
            );

            case (out_count)

                0: begin
                    if (out_data !== 128'h05040302010000000000000000000000)
                        $finish;

                    if (out_keep !== 16'hFC00)
                        $finish;

                    if (!out_flit_last)
                        $finish;

                    if (out_last)
                        $finish;
                end

                1: begin
                    if (out_data !== 128'h0504030201000F0E0D0C0B0A09080706)
                        $finish;

                    if (out_keep !== 16'hFFFF)
                        $finish;

                    if (out_flit_last)
                        $finish;

                    if (out_last)
                        $finish;
                end

                2: begin
                    if (out_data !== 128'h0000000000000F0E0D0C0B0A09080706)
                        $finish;

                    if (out_keep !== 16'h03FF)
                        $finish;

                    if (out_flit_last)
                        $finish;

                    if (!out_last)
                        $finish;
                end

                default:
                    $finish;

            endcase

            out_count = out_count + 1;
        end
    end

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        in_data        = 128'd0;
        in_keep        = 16'd0;
        in_valid       = 1'b0;
        in_last        = 1'b0;
        in_burst_start = 1'b0;
        in_burst_offset = 8'd250;
        in_burst_size   = 3'd4;

        out_ready = 1'b1;

        out_count = 0;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        // Start 6 bytes before the 256-byte boundary.
        send_beat(
            128'h0F0E0D0C0B0A09080706050403020100,
            1'b0,
            1'b1
        );

        send_beat(
            128'h1F1E1D1C1B1A19181716151413121110,
            1'b1,
            1'b0
        );

        repeat (5)
            @(posedge clk);

        if (out_count != 3) begin
            $display("PACKING TB FAILED");
            $finish;
        end

        $display("PACKING TB PASSED");
        $finish;
    end

endmodule