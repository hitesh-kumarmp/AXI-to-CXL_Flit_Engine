`timescale 1ns / 1ps

module top_flit_engine #(
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

    // AXI response
    output [1:0]                    s_axi_bresp,
    output                          s_axi_bvalid,
    input                           s_axi_bready,

    // CXL output
    output                          cxl_valid,
    input                           cxl_ready,
    output [127:0]                  cxl_data,
    output [15:0]                   cxl_keep,
    output [127:0]                  cxl_header,
    output                          cxl_header_valid,
    output                          cxl_last,
    output                          cxl_flit_last,
    output                          cxl_flit_start,
    output                          cxl_bank,
    output [3:0]                    cxl_word_index
);

    wire [DATA_WIDTH-1:0] ingress_data;
    wire [(DATA_WIDTH/8)-1:0] ingress_keep;
    wire ingress_valid;
    wire ingress_ready;
    wire ingress_last;
    wire ingress_burst_start;

    wire [ADDR_WIDTH-1:0] ingress_burst_addr;
    wire [7:0] ingress_burst_len;
    wire [2:0] ingress_burst_size;
    wire [1:0] ingress_burst_type;
    wire [31:0] ingress_burst_bytes;
    wire [7:0] ingress_burst_offset;

    wire pack_valid;
    wire pack_ready;
    wire [127:0] pack_data;
    wire [15:0] pack_keep;
    wire pack_last;
    wire pack_flit_last;
    wire [3:0] pack_word_index;
    wire [8:0] pack_flit_offset;

    wire storage_valid;
    wire storage_ready;
    wire [127:0] storage_data;
    wire [15:0] storage_keep;
    wire storage_last;
    wire storage_flit_last;
    wire storage_bank;
    wire [3:0] storage_word_index;

    wire [127:0] header_data;

    wire burst_active;
    wire burst_done;
    wire burst_error;

    // AXI ingress
    ingress #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_ingress (
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

        .out_valid          (ingress_valid),
        .out_ready          (ingress_ready),
        .out_data           (ingress_data),
        .out_keep           (ingress_keep),
        .out_last           (ingress_last),
        .out_burst_start    (ingress_burst_start),

        .out_burst_addr     (ingress_burst_addr),
        .out_burst_len      (ingress_burst_len),
        .out_burst_size     (ingress_burst_size),
        .out_burst_type     (ingress_burst_type),
        .out_burst_bytes    (ingress_burst_bytes),
        .out_burst_offset   (ingress_burst_offset),

        .burst_active       (burst_active),
        .burst_done         (burst_done),
        .burst_error        (burst_error)
    );

    // Byte packing
    packing u_packing (
        .clk             (clk),
        .rst_n           (rst_n),

        .in_data         (ingress_data),
        .in_keep         (ingress_keep),
        .in_valid        (ingress_valid),
        .in_ready        (ingress_ready),
        .in_last         (ingress_last),

        .in_burst_start  (ingress_burst_start),
        .in_burst_offset (ingress_burst_offset),
        .in_burst_size   (ingress_burst_size),

        .out_valid       (pack_valid),
        .out_ready       (pack_ready),
        .out_data        (pack_data),
        .out_keep        (pack_keep),
        .out_last        (pack_last),
        .out_flit_last   (pack_flit_last),
        .out_word_index  (pack_word_index),
        .out_flit_offset (pack_flit_offset)
    );

    // Ping-pong BRAM
    storage u_storage (
        .clk            (clk),
        .rst_n          (rst_n),

        .in_valid       (pack_valid),
        .in_ready       (pack_ready),
        .in_data        (pack_data),
        .in_keep        (pack_keep),
        .in_last        (pack_last),
        .in_flit_last   (pack_flit_last),
        .in_word_index  (pack_word_index),

        .out_valid      (storage_valid),
        .out_ready      (storage_ready),
        .out_data       (storage_data),
        .out_keep       (storage_keep),
        .out_last       (storage_last),
        .out_flit_last  (storage_flit_last),
        .out_bank       (storage_bank),
        .out_word_index (storage_word_index)
    );

    // Header generation
    headers u_headers (
        .valid         (1'b1),
        .partial_write (1'b0),

        .address       (ingress_burst_addr),
        .tag           (16'd0),

        .meta_field    (2'b00),
        .meta_value    (2'b00),
        .snp_type      (3'b000),

        .poison        (1'b0),
        .trp           (1'b0),
        .ld_id         (4'd0),
        .ckid          (13'd0),
        .tc            (2'b00),

        .header        (header_data)
    );

    // CXL egress
    egress u_egress (
        .clk               (clk),
        .rst_n             (rst_n),

        .in_valid          (storage_valid),
        .in_ready          (storage_ready),
        .in_data           (storage_data),
        .in_keep           (storage_keep),
        .in_last           (storage_last),
        .in_flit_last      (storage_flit_last),
        .in_bank           (storage_bank),
        .in_word_index     (storage_word_index),

        .header_data       (header_data),

        .cxl_valid         (cxl_valid),
        .cxl_ready         (cxl_ready),
        .cxl_data          (cxl_data),
        .cxl_keep          (cxl_keep),
        .cxl_header        (cxl_header),
        .cxl_header_valid  (cxl_header_valid),
        .cxl_last          (cxl_last),
        .cxl_flit_last     (cxl_flit_last),
        .cxl_flit_start    (cxl_flit_start),
        .cxl_bank          (cxl_bank),
        .cxl_word_index    (cxl_word_index)
    );

endmodule