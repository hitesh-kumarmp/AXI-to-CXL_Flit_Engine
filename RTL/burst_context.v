`timescale 1ns / 1ps

module burst_context #(
    parameter ADDR_WIDTH = 64
)(
    input                       clk,
    input                       rst_n,

    // AXI write address
    input  [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  [7:0]                s_axi_awlen,
    input  [2:0]                s_axi_awsize,
    input  [1:0]                s_axi_awburst,
    input                       s_axi_awvalid,
    output                      s_axi_awready,

    // W handshake info
    input                       w_fire,
    input                       w_last,

    // Control for the adapter
    output                      w_accept_enable,
    output                      w_is_first,

    // Current burst
    output                      burst_active,
    output [ADDR_WIDTH-1:0]     burst_addr,
    output [7:0]                burst_len,
    output [2:0]                burst_size,
    output [1:0]                burst_type,
    output [31:0]               burst_bytes,
    output [7:0]                burst_offset,

    // AXI response
    output                      s_axi_bvalid,
    output [1:0]                s_axi_bresp,
    input                       s_axi_bready,

    // Status
    output                      burst_done,
    output                      burst_error
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    reg                     burst_active_reg;
    reg [ADDR_WIDTH-1:0]    burst_addr_reg;
    reg [7:0]               burst_len_reg;
    reg [2:0]               burst_size_reg;
    reg [1:0]               burst_type_reg;
    reg [8:0]               beats_left_reg;

    reg                     error_seen_reg;

    reg                     bvalid_reg;
    reg [1:0]               bresp_reg;

    reg                     burst_done_reg;
    reg                     burst_error_reg;

    wire                    aw_fire;
    wire                    expected_last;
    wire                    last_mismatch;

    assign s_axi_awready =
        (~burst_active_reg) &&
        (~bvalid_reg);

    assign aw_fire =
        s_axi_awvalid &&
        s_axi_awready;

    assign w_accept_enable =
        burst_active_reg;

    assign w_is_first =
        burst_active_reg &&
        (beats_left_reg ==
         ({1'b0, burst_len_reg} + 9'd1));

    assign expected_last =
        (beats_left_reg == 9'd1);

    assign last_mismatch =
        (w_last != expected_last);

    assign burst_active =
        burst_active_reg;

    assign burst_addr =
        burst_addr_reg;

    assign burst_len =
        burst_len_reg;

    assign burst_size =
        burst_size_reg;

    assign burst_type =
        burst_type_reg;

    assign burst_bytes =
        ({24'd0, burst_len_reg} + 32'd1) <<
        burst_size_reg;

    assign burst_offset =
        burst_addr_reg[7:0];

    assign s_axi_bvalid =
        bvalid_reg;

    assign s_axi_bresp =
        bresp_reg;

    assign burst_done =
        burst_done_reg;

    assign burst_error =
        burst_error_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            burst_active_reg <= 1'b0;

            burst_addr_reg  <= {ADDR_WIDTH{1'b0}};
            burst_len_reg   <= 8'd0;
            burst_size_reg  <= 3'd0;
            burst_type_reg  <= 2'd0;

            beats_left_reg  <= 9'd0;
            error_seen_reg  <= 1'b0;

            bvalid_reg      <= 1'b0;
            bresp_reg       <= RESP_OKAY;

            burst_done_reg  <= 1'b0;
            burst_error_reg <= 1'b0;
        end
        else begin
            burst_done_reg  <= 1'b0;
            burst_error_reg <= 1'b0;

            if (bvalid_reg && s_axi_bready) begin
                bvalid_reg     <= 1'b0;
                error_seen_reg <= 1'b0;
            end

            if (aw_fire) begin
                burst_active_reg <= 1'b1;

                burst_addr_reg  <= s_axi_awaddr;
                burst_len_reg   <= s_axi_awlen;
                burst_size_reg  <= s_axi_awsize;
                burst_type_reg  <= s_axi_awburst;

                beats_left_reg <=
                    {1'b0, s_axi_awlen} + 9'd1;

                error_seen_reg <=
                    (s_axi_awburst != 2'b01);
            end

            if (w_fire) begin
                if (last_mismatch) begin
                    error_seen_reg <= 1'b1;
                end

                if (expected_last || w_last) begin
                    burst_active_reg <= 1'b0;
                    beats_left_reg   <= 9'd0;

                    bvalid_reg <= 1'b1;

                    if (error_seen_reg || last_mismatch)
                        bresp_reg <= RESP_SLVERR;
                    else
                        bresp_reg <= RESP_OKAY;

                    burst_done_reg <= 1'b1;

                    if (error_seen_reg || last_mismatch)
                        burst_error_reg <= 1'b1;
                end
                else begin
                    beats_left_reg <=
                        beats_left_reg - 9'd1;
                end
            end
        end
    end

endmodule