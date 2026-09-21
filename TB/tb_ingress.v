`timescale 1ns / 1ps

module tb_ingress;

    reg         clk;
    reg         rst_n;

    reg  [63:0] s_axi_awaddr;
    reg  [7:0]  s_axi_awlen;
    reg  [2:0]  s_axi_awsize;
    reg  [1:0]  s_axi_awburst;
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

    wire         out_valid;
    reg          out_ready;
    wire [127:0] out_data;
    wire [15:0]  out_keep;
    wire         out_last;
    wire         out_burst_start;

    wire [63:0]  out_burst_addr;
    wire [7:0]   out_burst_len;
    wire [2:0]   out_burst_size;
    wire [1:0]   out_burst_type;
    wire [31:0]  out_burst_bytes;
    wire [7:0]   out_burst_offset;

    wire         burst_active;
    wire         burst_done;
    wire         burst_error;

    integer out_count;
    reg [127:0] expected_data [0:3];

    ingress dut (
        .clk                (clk),
        .rst_n              (rst_n),

        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awlen        (s_axi_awlen),
        .s_axi_awsize       (s_axi_awsize),
        .s_axi_awburst      (s_axi_awburst),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),

        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wlast        (s_axi_wlast),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),

        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),

        .out_valid          (out_valid),
        .out_ready          (out_ready),
        .out_data           (out_data),
        .out_keep           (out_keep),
        .out_last           (out_last),
        .out_burst_start    (out_burst_start),

        .out_burst_addr     (out_burst_addr),
        .out_burst_len      (out_burst_len),
        .out_burst_size     (out_burst_size),
        .out_burst_type     (out_burst_type),
        .out_burst_bytes    (out_burst_bytes),
        .out_burst_offset   (out_burst_offset),

        .burst_active       (burst_active),
        .burst_done         (burst_done),
        .burst_error        (burst_error)
    );

    always #5 clk = ~clk;

    task send_aw;
        input [63:0] addr;
        input [7:0]  len;
        input [2:0]  size;
        input [1:0]  burst;
        begin
            @(negedge clk);

            s_axi_awaddr  = addr;
            s_axi_awlen   = len;
            s_axi_awsize  = size;
            s_axi_awburst = burst;
            s_axi_awvalid = 1'b1;

            while (!s_axi_awready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            s_axi_awvalid = 1'b0;
        end
    endtask

    task send_w;
        input [127:0] data;
        input [15:0]  strb;
        input         last;
        begin
            @(negedge clk);

            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wlast  = last;
            s_axi_wvalid = 1'b1;

            while (!s_axi_wready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);

            s_axi_wvalid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (out_valid && out_ready) begin
            $display(
                "%0t OUT beat=%0d data=%h keep=%h start=%b last=%b addr=%h",
                $time,
                out_count,
                out_data,
                out_keep,
                out_burst_start,
                out_last,
                out_burst_addr
            );

            if (out_data !== expected_data[out_count]) begin
                $display("ERROR: data mismatch");
                $finish;
            end

            if (out_keep !== 16'hFFFF) begin
                $display("ERROR: keep mismatch");
                $finish;
            end

            if (out_count == 0 && !out_burst_start) begin
                $display("ERROR: first beat not marked");
                $finish;
            end

            if (out_count == 3 && !out_last) begin
                $display("ERROR: last beat not marked");
                $finish;
            end

            if (out_burst_addr !== 64'h0000_0000_0000_00F0) begin
                $display("ERROR: burst address mismatch");
                $finish;
            end

            out_count = out_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        s_axi_awaddr  = 64'd0;
        s_axi_awlen   = 8'd0;
        s_axi_awsize  = 3'd0;
        s_axi_awburst = 2'd0;
        s_axi_awvalid = 1'b0;

        s_axi_wdata   = 128'd0;
        s_axi_wstrb   = 16'd0;
        s_axi_wlast   = 1'b0;
        s_axi_wvalid  = 1'b0;

        s_axi_bready  = 1'b1;
        out_ready     = 1'b1;

        out_count = 0;

        expected_data[0] = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        expected_data[1] = 128'h9999_AAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000;
        expected_data[2] = 128'h1234_5678_9ABC_DEF0_1111_2222_3333_4444;
        expected_data[3] = 128'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        // W cannot start before a burst context exists.
        @(negedge clk);
        s_axi_wdata  = expected_data[0];
        s_axi_wstrb  = 16'hFFFF;
        s_axi_wlast  = 1'b0;
        s_axi_wvalid = 1'b1;

        @(posedge clk);

        if (s_axi_wready !== 1'b0) begin
            $display("ERROR: WREADY should be low before AW");
            $finish;
        end

        @(negedge clk);
        s_axi_wvalid = 1'b0;

        // Four-beat burst.
        send_aw(
            64'h0000_0000_0000_00F0,
            8'd3,
            3'd4,
            2'b01
        );

        send_w(expected_data[0], 16'hFFFF, 1'b0);

        // Stall the downstream side for one beat.
        out_ready = 1'b0;

        send_w(expected_data[1], 16'hFFFF, 1'b0);

        if (s_axi_wready !== 1'b0) begin
            $display("ERROR: adapter should stop when its buffer is full");
            $finish;
        end

        out_ready = 1'b1;

        send_w(expected_data[2], 16'hFFFF, 1'b0);
        send_w(expected_data[3], 16'hFFFF, 1'b1);

        repeat (4)
            @(posedge clk);

        if (out_count != 4) begin
            $display("ERROR: expected 4 output beats, got %0d", out_count);
            $finish;
        end

        if (!s_axi_bvalid) begin
            @(posedge clk);
        end

        if (s_axi_bresp !== 2'b00) begin
            $display("ERROR: unexpected BRESP");
            $finish;
        end

        @(posedge clk);

        $display("INGRESS TB PASSED");
        $finish;
    end

endmodule