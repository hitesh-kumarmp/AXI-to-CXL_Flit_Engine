`timescale 1ns / 1ps

module tb_boundary_sweep;

    reg clk;
    reg rst_n;

    reg [63:0]  s_axi_awaddr;
    reg [7:0]   s_axi_awlen;
    reg [2:0]   s_axi_awsize;
    reg [1:0]   s_axi_awburst;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg [127:0] s_axi_wdata;
    reg [15:0]  s_axi_wstrb;
    reg         s_axi_wlast;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    wire [127:0] cxl_data;
    wire [15:0]  cxl_keep;
    wire [127:0] cxl_header;

    wire         cxl_valid;
    wire         cxl_header_valid;
    wire         cxl_last;
    wire         cxl_flit_last;
    wire         cxl_flit_start;
    wire         cxl_bank;
    wire [3:0]   cxl_word_index;

    reg         cxl_ready;

    reg         sb_start;
    reg [7:0]   sb_offset;

    wire        sb_done;
    wire        sb_error;
    wire [7:0]  sb_received_count;

    integer offset;
    integer timeout_count;
    integer byte_index;

    reg [7:0] current_offset;
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

        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),

        .cxl_valid        (cxl_valid),
        .cxl_ready        (cxl_ready),
        .cxl_data         (cxl_data),
        .cxl_keep         (cxl_keep),
        .cxl_header       (cxl_header),
        .cxl_header_valid (cxl_header_valid),
        .cxl_last         (cxl_last),
        .cxl_flit_last    (cxl_flit_last),
        .cxl_flit_start   (cxl_flit_start),
        .cxl_bank         (cxl_bank),
        .cxl_word_index   (cxl_word_index)
    );

    scoreboard u_scoreboard (
        .clk              (clk),
        .rst_n             (rst_n),

        .start_burst      (sb_start),
        .start_offset     (sb_offset),

        .cxl_valid        (cxl_valid),
        .cxl_ready        (cxl_ready),
        .cxl_data         (cxl_data),
        .cxl_keep         (cxl_keep),
        .cxl_last         (cxl_last),
        .cxl_flit_last    (cxl_flit_last),
        .cxl_flit_start   (cxl_flit_start),

        .burst_done       (sb_done),
        .error            (sb_error),
        .received_count   (sb_received_count)
    );

    always #5 clk = ~clk;

    task send_aw;
        input [63:0] addr;

        begin
            @(negedge clk);

            s_axi_awaddr  = addr;
            s_axi_awlen   = 8'd1;
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

    task send_w_word;
        input [7:0] start_byte;
        input        last_word;

        begin
            word_data = 128'd0;

            for (byte_index = 0;
                 byte_index < 16;
                 byte_index = byte_index + 1) begin

                word_data[8*byte_index +: 8] =
                    start_byte + byte_index;

            end

            @(negedge clk);

            s_axi_wdata  = word_data;
            s_axi_wstrb  = 16'hFFFF;
            s_axi_wlast  = last_word;
            s_axi_wvalid = 1'b1;

            while (!s_axi_wready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            s_axi_wvalid = 1'b0;
        end
    endtask

    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        s_axi_awaddr  = 64'd0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'd0;
        s_axi_awburst = 2'd0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata  = 128'd0;
        s_axi_wstrb  = 16'd0;
        s_axi_wlast  = 1'b0;
        s_axi_wvalid = 1'b0;

        s_axi_bready = 1'b1;
        cxl_ready    = 1'b1;

        sb_start  = 1'b0;
        sb_offset = 8'd0;

        current_offset = 8'd0;
        word_data      = 128'd0;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        for (offset = 0; offset < 256; offset = offset + 1) begin

            current_offset = offset;

            // Tell the scoreboard which alignment starts here.
            @(negedge clk);

            sb_offset = current_offset;
            sb_start  = 1'b1;

            @(posedge clk);
            @(negedge clk);

            sb_start = 1'b0;

            // Start a 32-byte burst.
            send_aw({56'd0, current_offset});

            send_w_word(8'd0, 1'b0);
            send_w_word(8'd16, 1'b1);

            timeout_count = 0;

            while (!sb_done && timeout_count < 1000) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 1000) begin

                $display(
                    "TIMEOUT at offset %0d",
                    current_offset
                );

                $finish;

            end

            if (sb_error) begin

                $display(
                    "ERROR at offset %0d",
                    current_offset
                );

                $finish;

            end

            if (sb_received_count != 8'd32) begin

                $display(
                    "BYTE COUNT ERROR at offset %0d: got %0d",
                    current_offset,
                    sb_received_count
                );

                $finish;

            end

            if (s_axi_bresp !== 2'b00) begin

                $display(
                    "BRESP ERROR at offset %0d",
                    current_offset
                );

                $finish;

            end

            $display(
                "OFFSET %0d PASS",
                current_offset
            );

        end

        $display("--------------------------------");
        $display("256-OFFSET SWEEP PASSED");
        $display("--------------------------------");

        $finish;

    end

endmodule