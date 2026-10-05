`timescale 1ns / 1ps

module board_top (
    input        CLK,
    input        UART_RX,
    output       UART_TX,

    input  [3:0] SW,
    input  [3:0] btn,
    output [3:0] LED
);

    wire rst_n;
    wire enable;

    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;

    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    wire       uart_tx_ready;

    wire [63:0] axi_awaddr;
    wire [7:0]  axi_awlen;
    wire [2:0]  axi_awsize;
    wire [1:0]  axi_awburst;
    wire        axi_awvalid;
    wire        axi_awready;

    wire [127:0] axi_wdata;
    wire [15:0]  axi_wstrb;
    wire         axi_wlast;
    wire         axi_wvalid;
    wire         axi_wready;

    wire [1:0] axi_bresp;
    wire       axi_bvalid;
    wire       axi_bready;

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

    wire busy;
    wire done;
    wire stall_seen;
    wire error;

    assign rst_n  = ~btn[0];
    assign enable = SW[0];

    uart_rx #(
        .CLKS_PER_BIT(868)
    ) u_uart_rx (
        .clk   (CLK),
        .rst_n (rst_n),
        .rx    (UART_RX),
        .data  (uart_rx_data),
        .valid (uart_rx_valid)
    );

    uart_tx #(
        .CLKS_PER_BIT(868)
    ) u_uart_tx (
        .clk   (CLK),
        .rst_n (rst_n),
        .data  (uart_tx_data),
        .valid (uart_tx_valid),
        .ready (uart_tx_ready),
        .tx    (UART_TX)
    );

    uart_burst_bridge u_uart_burst_bridge (
        .clk              (CLK),
        .rst_n            (rst_n),
        .enable           (enable),

        .rx_data          (uart_rx_data),
        .rx_valid         (uart_rx_valid),

        .tx_data          (uart_tx_data),
        .tx_valid         (uart_tx_valid),
        .tx_ready         (uart_tx_ready),

        .axi_awaddr       (axi_awaddr),
        .axi_awlen        (axi_awlen),
        .axi_awsize       (axi_awsize),
        .axi_awburst      (axi_awburst),
        .axi_awvalid      (axi_awvalid),
        .axi_awready      (axi_awready),

        .axi_wdata        (axi_wdata),
        .axi_wstrb        (axi_wstrb),
        .axi_wlast        (axi_wlast),
        .axi_wvalid       (axi_wvalid),
        .axi_wready       (axi_wready),

        .axi_bresp        (axi_bresp),
        .axi_bvalid       (axi_bvalid),
        .axi_bready       (axi_bready),

        .cxl_valid        (cxl_valid),
        .cxl_data         (cxl_data),
        .cxl_keep         (cxl_keep),
        .cxl_header       (cxl_header),
        .cxl_header_valid (cxl_header_valid),
        .cxl_last         (cxl_last),
        .cxl_flit_last    (cxl_flit_last),
        .cxl_flit_start   (cxl_flit_start),
        .cxl_bank         (cxl_bank),
        .cxl_word_index   (cxl_word_index),

        .busy             (busy),
        .done             (done),
        .stall_seen       (stall_seen),
        .error            (error)
    );

    top_flit_engine u_flit_engine (
        .clk                (CLK),
        .rst_n              (rst_n),

        .s_axi_awaddr       (axi_awaddr),
        .s_axi_awlen        (axi_awlen),
        .s_axi_awsize       (axi_awsize),
        .s_axi_awburst      (axi_awburst),
        .s_axi_awvalid      (axi_awvalid),
        .s_axi_awready      (axi_awready),

        .s_axi_wdata        (axi_wdata),
        .s_axi_wstrb        (axi_wstrb),
        .s_axi_wlast        (axi_wlast),
        .s_axi_wvalid       (axi_wvalid),
        .s_axi_wready      (axi_wready),

        .s_axi_bresp        (axi_bresp),
        .s_axi_bvalid       (axi_bvalid),
        .s_axi_bready       (axi_bready),

        .cxl_valid          (cxl_valid),
        .cxl_ready          (1'b1),

        .cxl_data           (cxl_data),
        .cxl_keep           (cxl_keep),
        .cxl_header         (cxl_header),
        .cxl_header_valid   (cxl_header_valid),
        .cxl_last           (cxl_last),
        .cxl_flit_last      (cxl_flit_last),
        .cxl_flit_start     (cxl_flit_start),
        .cxl_bank           (cxl_bank),
        .cxl_word_index     (cxl_word_index)
    );

    assign LED[0] = busy;
    assign LED[1] = done;
    assign LED[2] = stall_seen;
    assign LED[3] = error;

endmodule