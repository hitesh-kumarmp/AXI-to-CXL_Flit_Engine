`timescale 1ns / 1ps

module board_top_tb;

    localparam integer CLKS_PER_BIT = 868;
    localparam integer BIT_NS = 10 * CLKS_PER_BIT;

    reg CLK;
    reg UART_RX;
    wire UART_TX;

    reg [3:0] SW;
    reg [3:0] btn;
    wire [3:0] LED;

    integer test_pass;

    board_top dut (
        .CLK     (CLK),
        .UART_RX (UART_RX),
        .UART_TX (UART_TX),
        .SW      (SW),
        .btn     (btn),
        .LED     (LED)
    );

    always #5 CLK = ~CLK;

    task uart_send_byte;
        input [7:0] data;
        integer k;
        begin
            UART_RX = 1'b0;
            #(BIT_NS);

            for (k = 0; k < 8; k = k + 1) begin
                UART_RX = data[k];
                #(BIT_NS);
            end

            UART_RX = 1'b1;
            #(BIT_NS);
        end
    endtask

    task send_burst;
        input [63:0] address;
        input integer beats;
        integer k;
        begin
            uart_send_byte(8'hA5);
            uart_send_byte(8'h5A);
            uart_send_byte(8'h01);

            uart_send_byte(address[7:0]);
            uart_send_byte(address[15:8]);
            uart_send_byte(address[23:16]);
            uart_send_byte(address[31:24]);
            uart_send_byte(address[39:32]);
            uart_send_byte(address[47:40]);
            uart_send_byte(address[55:48]);
            uart_send_byte(address[63:56]);

            uart_send_byte(beats[7:0]);

            for (k = 0; k < beats * 16; k = k + 1)
                uart_send_byte(k[7:0]);
        end
    endtask

    task check_test;
        input [63:0] address;
        input integer beats;
        input integer expected_bytes;
        input integer expected_words;
        input integer expected_flits;

        integer actual_bytes;
        integer actual_words;
        integer actual_flits;
        integer actual_stalls;
        integer actual_max_stall;

        begin

            test_pass = 1;

            actual_bytes =
                dut.u_uart_burst_bridge.output_bytes;

            actual_words =
                dut.u_uart_burst_bridge.output_words;

            actual_flits =
                dut.u_uart_burst_bridge.output_flits;

            actual_stalls =
                dut.u_uart_burst_bridge.stall_count;

            actual_max_stall =
                dut.u_uart_burst_bridge.max_stall_run;

            if (actual_bytes != expected_bytes)
                test_pass = 0;

            if (actual_words != expected_words)
                test_pass = 0;

            if (actual_flits != expected_flits)
                test_pass = 0;

            if (dut.u_uart_burst_bridge.error !== 1'b0)
                test_pass = 0;

            if (dut.u_uart_burst_bridge.cxl_done !== 1'b1)
                test_pass = 0;

            $display("");
            $display("================================================");
            $display("ADDRESS      = 0x%016h", address);
            $display("BEATS        = %0d", beats);
            $display("OUTPUT BYTES = %0d", actual_bytes);
            $display("OUTPUT WORDS = %0d", actual_words);
            $display("OUTPUT FLITS = %0d", actual_flits);
            $display("STALL COUNT  = %0d", actual_stalls);
            $display("MAX STALL    = %0d", actual_max_stall);
            $display("CXL DONE     = %0d", dut.u_uart_burst_bridge.cxl_done);
            $display("ERROR        = %0d", dut.u_uart_burst_bridge.error);

            if (test_pass)
                $display("RESULT       = PASS");
            else
                $display("RESULT       = FAIL");

            $display("================================================");
        end
    endtask

    task reset_bridge;
        begin
            btn[0] = 1'b1;
            repeat (100)
                @(posedge CLK);

            btn[0] = 1'b0;

            repeat (100)
                @(posedge CLK);
        end
    endtask

    initial begin

        CLK = 1'b0;
        UART_RX = 1'b1;

        SW = 4'b0000;
        btn = 4'b0000;

        reset_bridge;

        SW[0] = 1'b1;

        repeat (100)
            @(posedge CLK);

        $display("");
        $display("==============================================");
        $display(" AXI-TO-CXL BOARD TOP TESTBENCH");
        $display("==============================================");

        // 16 bytes ending exactly at the flit boundary.
        send_burst(
            64'h00000000000000F0,
            1
        );

        #5000000;

        check_test(
            64'h00000000000000F0,
            1,
            16,
            1,
            1
        );

        reset_bridge;

        // 16 bytes crossing the 256-byte boundary.
        send_burst(
            64'h00000000000000F8,
            1
        );

        #5000000;

        check_test(
            64'h00000000000000F8,
            1,
            16,
            2,
            2
        );

        reset_bridge;

        // Extreme boundary crossing.
        send_burst(
            64'h00000000000000FF,
            1
        );

        #5000000;

        check_test(
            64'h00000000000000FF,
            1,
            16,
            2,
            2
        );

        reset_bridge;

        // 256-byte burst beginning at offset F8.
        send_burst(
            64'h00000000000000F8,
            16
        );

        #30000000;

        check_test(
            64'h00000000000000F8,
            16,
            256,
            17,
            2
        );

        $display("");
        $display("==============================================");
        $display(" BOARD TOP TESTBENCH COMPLETE");
        $display("==============================================");

        $finish;
    end

endmodule