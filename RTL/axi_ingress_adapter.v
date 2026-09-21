`timescale 1ns / 1ps

module axi_ingress_adapter #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 64
)(
    input                           clk,
    input                           rst_n,

    // AXI write data
    input  [DATA_WIDTH-1:0]         s_axi_wdata,
    input  [(DATA_WIDTH/8)-1:0]     s_axi_wstrb,
    input                           s_axi_wlast,
    input                           s_axi_wvalid,
    output                          s_axi_wready,

    // Burst control
    input                           w_accept_enable,
    input                           w_is_first,

    input  [ADDR_WIDTH-1:0]         burst_addr,
    input  [7:0]                    burst_len,
    input  [2:0]                    burst_size,
    input  [1:0]                    burst_type,
    input  [31:0]                   burst_bytes,
    input  [7:0]                    burst_offset,

    // Stream to packer
    output                          out_valid,
    input                           out_ready,
    output [DATA_WIDTH-1:0]         out_data,
    output [(DATA_WIDTH/8)-1:0]     out_keep,
    output                          out_last,
    output                          out_burst_start,

    output [ADDR_WIDTH-1:0]         out_burst_addr,
    output [7:0]                    out_burst_len,
    output [2:0]                    out_burst_size,
    output [1:0]                    out_burst_type,
    output [31:0]                   out_burst_bytes,
    output [7:0]                    out_burst_offset,

    // AXI handshake
    output                          w_fire
);

    localparam KEEP_WIDTH = DATA_WIDTH / 8;

    reg                     buffer_valid;
    reg [DATA_WIDTH-1:0]    buffer_data;
    reg [KEEP_WIDTH-1:0]    buffer_keep;
    reg                     buffer_last;
    reg                     buffer_burst_start;

    reg [ADDR_WIDTH-1:0]    buffer_burst_addr;
    reg [7:0]               buffer_burst_len;
    reg [2:0]               buffer_burst_size;
    reg [1:0]               buffer_burst_type;
    reg [31:0]              buffer_burst_bytes;
    reg [7:0]               buffer_burst_offset;

    wire buffer_can_accept;

    assign buffer_can_accept =
        (~buffer_valid) ||
        out_ready;

    assign s_axi_wready =
        w_accept_enable &&
        buffer_can_accept;

    assign w_fire =
        s_axi_wvalid &&
        s_axi_wready;

    assign out_valid =
        buffer_valid;

    assign out_data =
        buffer_data;

    assign out_keep =
        buffer_keep;

    assign out_last =
        buffer_last;

    assign out_burst_start =
        buffer_burst_start;

    assign out_burst_addr =
        buffer_burst_addr;

    assign out_burst_len =
        buffer_burst_len;

    assign out_burst_size =
        buffer_burst_size;

    assign out_burst_type =
        buffer_burst_type;

    assign out_burst_bytes =
        buffer_burst_bytes;

    assign out_burst_offset =
        buffer_burst_offset;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_valid       <= 1'b0;

            buffer_data        <= {DATA_WIDTH{1'b0}};
            buffer_keep        <= {KEEP_WIDTH{1'b0}};
            buffer_last        <= 1'b0;
            buffer_burst_start <= 1'b0;

            buffer_burst_addr   <= {ADDR_WIDTH{1'b0}};
            buffer_burst_len    <= 8'd0;
            buffer_burst_size   <= 3'd0;
            buffer_burst_type   <= 2'd0;
            buffer_burst_bytes  <= 32'd0;
            buffer_burst_offset <= 8'd0;
        end
        else begin
            if (buffer_valid && out_ready) begin
                buffer_valid <= 1'b0;
            end

            if (w_fire) begin
                buffer_valid <= 1'b1;

                buffer_data <= s_axi_wdata;
                buffer_keep <= s_axi_wstrb;
                buffer_last <= s_axi_wlast;

                buffer_burst_start <= w_is_first;

                buffer_burst_addr   <= burst_addr;
                buffer_burst_len    <= burst_len;
                buffer_burst_size   <= burst_size;
                buffer_burst_type   <= burst_type;
                buffer_burst_bytes  <= burst_bytes;
                buffer_burst_offset <= burst_offset;
            end
        end
    end

endmodule