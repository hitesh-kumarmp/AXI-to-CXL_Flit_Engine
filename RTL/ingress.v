`timescale 1ns / 1ps

module ingress #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 64
)(
    input                           clk,
    input                           rst_n,

    // AXI write address
    input  [ADDR_WIDTH-1:0]         s_axi_awaddr,
    input  [7:0]                    s_axi_awlen,
    input  [2:0]                    s_axi_awsize,
    input  [1:0]                    s_axi_awburst,
    input                           s_axi_awvalid,
    output                          s_axi_awready,

    // AXI write data
    input  [DATA_WIDTH-1:0]         s_axi_wdata,
    input  [(DATA_WIDTH/8)-1:0]     s_axi_wstrb,
    input                           s_axi_wlast,
    input                           s_axi_wvalid,
    output                          s_axi_wready,

    // AXI write response
    output [1:0]                    s_axi_bresp,
    output                          s_axi_bvalid,
    input                           s_axi_bready,

    // Interface to packer
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

    // Status
    output                          burst_active,
    output                          burst_done,
    output                          burst_error
);

    wire [ADDR_WIDTH-1:0] burst_addr;
    wire [7:0]            burst_len;
    wire [2:0]            burst_size;
    wire [1:0]            burst_type;
    wire [31:0]           burst_bytes;
    wire [7:0]            burst_offset;

    wire                  w_accept_enable;
    wire                  w_is_first;
    wire                  w_fire;

    burst_context #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_burst_context (
        .clk                (clk),
        .rst_n              (rst_n),

        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awlen        (s_axi_awlen),
        .s_axi_awsize       (s_axi_awsize),
        .s_axi_awburst      (s_axi_awburst),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),

        .w_fire             (w_fire),
        .w_last             (s_axi_wlast),

        .w_accept_enable    (w_accept_enable),
        .w_is_first         (w_is_first),

        .burst_active       (burst_active),
        .burst_addr         (burst_addr),
        .burst_len          (burst_len),
        .burst_size         (burst_size),
        .burst_type         (burst_type),
        .burst_bytes        (burst_bytes),
        .burst_offset       (burst_offset),

        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bready       (s_axi_bready),

        .burst_done         (burst_done),
        .burst_error        (burst_error)
    );

    axi_ingress_adapter #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_axi_ingress_adapter (
        .clk                (clk),
        .rst_n              (rst_n),

        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wlast        (s_axi_wlast),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),

        .w_accept_enable    (w_accept_enable),
        .w_is_first         (w_is_first),

        .burst_addr         (burst_addr),
        .burst_len          (burst_len),
        .burst_size         (burst_size),
        .burst_type         (burst_type),
        .burst_bytes        (burst_bytes),
        .burst_offset       (burst_offset),

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

        .w_fire             (w_fire)
    );

endmodule