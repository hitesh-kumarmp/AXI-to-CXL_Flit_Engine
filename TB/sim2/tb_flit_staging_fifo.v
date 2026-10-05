`timescale 1ns / 1ps

module tb_flit_staging_fifo;

    parameter DEPTH = 4;
    parameter TOTAL_WORDS = 40;
    parameter MAX_CYCLES = 10000;

    reg         clk;
    reg         rst_n;

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
    wire [3:0]   out_word_index;

    reg [127:0] queue_data  [0:127];
    reg [15:0]  queue_keep  [0:127];
    reg         queue_last  [0:127];
    reg         queue_flit  [0:127];
    reg [3:0]   queue_index [0:127];

    integer q_head;
    integer q_tail;
    integer q_count;

    integer sent_count;
    integer recv_count;
    integer errors;

    integer i;
    integer accepted;
    integer cycle_count;
    integer stall_count;

    flit_staging_fifo #(
        .DEPTH(DEPTH)
    ) dut (
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
        .out_keep       (out_keep),
        .out_last       (out_last),
        .out_flit_last  (out_flit_last),
        .out_word_index (out_word_index)
    );

    always #5 clk = ~clk;

    function [127:0] make_data;
        input integer n;
        begin
            make_data = 128'h1000_0000_0000_0000 + n;
        end
    endfunction

    task reset_test;
        begin
            in_valid       = 1'b0;
            in_data        = 128'd0;
            in_keep        = 16'h0000;
            in_last        = 1'b0;
            in_flit_last   = 1'b0;
            in_word_index  = 4'd0;
            out_ready      = 1'b0;

            rst_n = 1'b0;

            repeat (4)
                @(negedge clk);

            rst_n = 1'b1;

            @(negedge clk);

            q_head = 0;
            q_tail = 0;
            q_count = 0;

            sent_count = 0;
            recv_count = 0;
        end
    endtask

    task send_word;
        input integer n;
        input         last_flag;
        input         flit_last_flag;

        begin
            @(negedge clk);

            in_data       = make_data(n);
            in_keep       = 16'hffff;
            in_last       = last_flag;
            in_flit_last  = flit_last_flag;
            in_word_index = n & 4'hf;
            in_valid      = 1'b1;

            accepted = 0;

            while (accepted == 0) begin
                @(posedge clk);

                if (in_ready == 1'b1)
                    accepted = 1;
            end

            @(negedge clk);

            in_valid = 1'b0;
        end
    endtask

    task send_word_backpressure;
        input integer n;
        input         last_flag;
        input         flit_last_flag;

        begin
            @(negedge clk);

            in_data       = make_data(n);
            in_keep       = 16'hffff;
            in_last       = last_flag;
            in_flit_last  = flit_last_flag;
            in_word_index = n & 4'hf;
            in_valid      = 1'b1;

            accepted = 0;
            stall_count = 0;

            out_ready = 1'b0;

            while (accepted == 0) begin

                @(posedge clk);

                if (in_ready == 1'b1) begin
                    accepted = 1;
                end
                else begin
                    stall_count = stall_count + 1;
                end

                if (accepted == 0) begin
                    @(negedge clk);

                    if ((stall_count % 4) == 0)
                        out_ready = 1'b0;
                    else
                        out_ready = 1'b1;
                end
            end

            @(negedge clk);

            in_valid = 1'b0;
        end
    endtask

    task check_output;
        begin

            if (q_count == 0) begin

                $display(
                    "UNEXPECTED OUTPUT: DATA=%h",
                    out_data
                );

                errors = errors + 1;

            end
            else begin

                if (out_data !== queue_data[q_head]) begin
                    $display(
                        "DATA ERROR: expected=%h got=%h",
                        queue_data[q_head],
                        out_data
                    );
                    errors = errors + 1;
                end

                if (out_keep !== queue_keep[q_head]) begin
                    $display(
                        "KEEP ERROR: expected=%h got=%h",
                        queue_keep[q_head],
                        out_keep
                    );
                    errors = errors + 1;
                end

                if (out_last !== queue_last[q_head]) begin
                    $display(
                        "LAST ERROR: expected=%b got=%b",
                        queue_last[q_head],
                        out_last
                    );
                    errors = errors + 1;
                end

                if (out_flit_last !== queue_flit[q_head]) begin
                    $display(
                        "FLIT LAST ERROR: expected=%b got=%b",
                        queue_flit[q_head],
                        out_flit_last
                    );
                    errors = errors + 1;
                end

                if (out_word_index !== queue_index[q_head]) begin
                    $display(
                        "WORD INDEX ERROR: expected=%0d got=%0d",
                        queue_index[q_head],
                        out_word_index
                    );
                    errors = errors + 1;
                end

                q_head = q_head + 1;

                if (q_head == 128)
                    q_head = 0;

                q_count = q_count - 1;
                recv_count = recv_count + 1;
            end
        end
    endtask

    always @(posedge clk) begin

        if (rst_n) begin

            cycle_count = cycle_count + 1;

            if (in_valid && in_ready) begin

                queue_data[q_tail]  = in_data;
                queue_keep[q_tail]  = in_keep;
                queue_last[q_tail]  = in_last;
                queue_flit[q_tail]  = in_flit_last;
                queue_index[q_tail] = in_word_index;

                q_tail = q_tail + 1;

                if (q_tail == 128)
                    q_tail = 0;

                q_count = q_count + 1;
                sent_count = sent_count + 1;
            end

            if (out_valid && out_ready)
                check_output;

            if (cycle_count > MAX_CYCLES) begin
                $display("");
                $display("========================================");
                $display("FIFO TEST TIMEOUT");
                $display("CYCLES = %0d", cycle_count);
                $display("QUEUE  = %0d", q_count);
                $display("SENT   = %0d", sent_count);
                $display("RECV   = %0d", recv_count);
                $display("========================================");
                $finish;
            end
        end
    end

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        in_valid       = 1'b0;
        in_data        = 128'd0;
        in_keep        = 16'h0000;
        in_last        = 1'b0;
        in_flit_last   = 1'b0;
        in_word_index  = 4'd0;

        out_ready = 1'b0;

        q_head = 0;
        q_tail = 0;
        q_count = 0;

        sent_count = 0;
        recv_count = 0;
        errors = 0;

        accepted = 0;
        stall_count = 0;
        cycle_count = 0;

        $display("");
        $display("========================================");
        $display("FLIT STAGING FIFO TEST");
        $display("DEPTH = %0d", DEPTH);
        $display("========================================");

        // Test 1: Fill and full

        reset_test;

        for (i = 0; i < DEPTH; i = i + 1) begin
            send_word(
                i,
                (i == 1),
                (i == 3)
            );
        end

        @(negedge clk);

        if (in_ready !== 1'b0) begin
            $display(
                "FULL ERROR: expected in_ready=0 got=%b",
                in_ready
            );
            errors = errors + 1;
        end

        if (out_valid !== 1'b1) begin
            $display(
                "VALID ERROR: expected out_valid=1 got=%b",
                out_valid
            );
            errors = errors + 1;
        end

        out_ready = 1'b1;

        while (q_count != 0)
            @(negedge clk);

        $display("FILL/FULL TEST COMPLETE");

        // Test 2: Simultaneous push/pop

        reset_test;

        out_ready = 1'b0;

        for (i = 0; i < DEPTH; i = i + 1) begin
            send_word(
                100 + i,
                (i == 3),
                (i == 3)
            );
        end

        out_ready = 1'b1;

        for (i = DEPTH; i < 24; i = i + 1) begin
            send_word(
                100 + i,
                ((i % 5) == 4),
                ((i % 7) == 6)
            );
        end

        while (q_count != 0)
            @(negedge clk);

        $display("SIMULTANEOUS PUSH/POP TEST COMPLETE");

        // Test 3: Backpressure

        reset_test;

        for (i = 0; i < TOTAL_WORDS; i = i + 1) begin
            send_word_backpressure(
                200 + i,
                ((i % 5) == 4),
                ((i % 7) == 6)
            );
        end

        in_valid = 1'b0;
        out_ready = 1'b1;

        while (q_count != 0)
            @(negedge clk);

        $display("BACKPRESSURE TEST COMPLETE");

        $display("");
        $display("========================================");
        $display("FIFO TEST RESULTS");
        $display("WORDS SENT          = %0d", sent_count);
        $display("WORDS RECEIVED      = %0d", recv_count);
        $display("QUEUE COUNT         = %0d", q_count);
        $display("ERRORS              = %0d", errors);
        $display("========================================");

        if ((errors == 0) &&
            (sent_count == TOTAL_WORDS) &&
            (recv_count == TOTAL_WORDS) &&
            (q_count == 0))

            $display("FLIT STAGING FIFO PASSED");

        else

            $display("FLIT STAGING FIFO FAILED");

        $display("========================================");

        $finish;
    end

endmodule