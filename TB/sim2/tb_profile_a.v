`timescale 1ns / 1ps

module tb_profile_a;

    reg clk;
    reg rst_n;

    reg [63:0] s_axi_awaddr;
    reg [7:0]  s_axi_awlen;
    reg [2:0]  s_axi_awsize;
    reg [1:0]  s_axi_awburst;
    reg        s_axi_awvalid;
    wire       s_axi_awready;

    reg [127:0] s_axi_wdata;
    reg [15:0]  s_axi_wstrb;
    reg         s_axi_wlast;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [1:0] s_axi_bresp;
    wire       s_axi_bvalid;
    reg        s_axi_bready;

    wire        cxl_valid;
    reg         cxl_ready;
    wire [127:0] cxl_data;
    wire [15:0]  cxl_keep;
    wire [127:0] cxl_header;
    wire        cxl_header_valid;
    wire        cxl_last;
    wire        cxl_flit_last;
    wire        cxl_flit_start;
    wire        cxl_bank;
    wire [3:0]  cxl_word_index;

    integer beat;
    integer cycles;
    integer ready_low_count;
    integer output_count;

    reg [127:0] word_data;

    top_flit_engine dut (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .cxl_valid(cxl_valid),
        .cxl_ready(cxl_ready),
        .cxl_data(cxl_data),
        .cxl_keep(cxl_keep),
        .cxl_header(cxl_header),
        .cxl_header_valid(cxl_header_valid),
        .cxl_last(cxl_last),
        .cxl_flit_last(cxl_flit_last),
        .cxl_flit_start(cxl_flit_start),
        .cxl_bank(cxl_bank),
        .cxl_word_index(cxl_word_index)
    );

    always #5 clk = ~clk;

    task send_aw;
        begin
            @(negedge clk);

            s_axi_awaddr  = 64'h0000_0000_0000_0100;
            s_axi_awlen   = 8'd31;
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

    task send_word;
        input integer n;
        begin
            word_data = 128'd0;

            word_data[7:0]   = n * 16;
            word_data[15:8]  = n * 16 + 1;
            word_data[23:16] = n * 16 + 2;
            word_data[31:24] = n * 16 + 3;
            word_data[39:32] = n * 16 + 4;
            word_data[47:40] = n * 16 + 5;
            word_data[55:48] = n * 16 + 6;
            word_data[63:56] = n * 16 + 7;
            word_data[71:64] = n * 16 + 8;
            word_data[79:72] = n * 16 + 9;
            word_data[87:80] = n * 16 + 10;
            word_data[95:88] = n * 16 + 11;
            word_data[103:96] = n * 16 + 12;
            word_data[111:104] = n * 16 + 13;
            word_data[119:112] = n * 16 + 14;
            word_data[127:120] = n * 16 + 15;

            s_axi_wdata  = word_data;
            s_axi_wstrb  = 16'hFFFF;
            s_axi_wlast  = (n == 31);
            s_axi_wvalid = 1'b1;

            @(posedge clk);

            if (s_axi_wvalid && !s_axi_wready)
                ready_low_count = ready_low_count + 1;

            @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (cxl_valid && cxl_ready)
            output_count = output_count + 1;
    end

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

        ready_low_count = 0;
        output_count = 0;

        repeat (3)
            @(posedge clk);

        rst_n = 1'b1;

        send_aw;

        for (beat = 0; beat < 32; beat = beat + 1)
            send_word(beat);

        @(negedge clk);
        s_axi_wvalid = 1'b0;

        cycles = 0;

        while (!s_axi_bvalid && cycles < 500) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        repeat (20)
            @(posedge clk);

        if (ready_low_count != 0) begin
            $display("PROFILE A FAILED: WREADY dropped %0d times", ready_low_count);
            $finish;
        end

        if (s_axi_bresp != 2'b00) begin
            $display("PROFILE A FAILED: BRESP");
            $finish;
        end

        $display("PROFILE A PASSED");
        $display("WREADY LOW COUNT = %0d", ready_low_count);
        $display("CXL OUTPUT COUNT = %0d", output_count);

        $finish;

    end

endmodule