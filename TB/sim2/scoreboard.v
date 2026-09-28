`timescale 1ns / 1ps

module scoreboard (
    input         clk,
    input         rst_n,

    input         start_burst,
    input  [7:0]  start_offset,

    input         cxl_valid,
    input         cxl_ready,
    input  [127:0] cxl_data,
    input  [15:0] cxl_keep,
    input         cxl_last,
    input         cxl_flit_last,
    input         cxl_flit_start,

    output reg    burst_done,
    output reg    error,
    output reg [7:0] received_count
);

    reg [8:0] flit_offset;
    reg       expect_flit_start;

    integer i;
    integer valid_bytes;
    integer temp_count;
    integer temp_offset;

    reg [7:0] expected_byte;

    function [5:0] count_keep;
        input [15:0] keep;
        integer k;

        begin
            count_keep = 0;

            for (k = 0; k < 16; k = k + 1) begin
                if (keep[k])
                    count_keep = count_keep + 1;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            flit_offset        <= 9'd0;
            expect_flit_start  <= 1'b1;
            burst_done         <= 1'b0;
            error              <= 1'b0;
            received_count     <= 8'd0;

        end
        else begin

            burst_done <= 1'b0;

            if (start_burst) begin

                flit_offset       <= {1'b0, start_offset};
                expect_flit_start <= 1'b1;
                burst_done        <= 1'b0;
                error             <= 1'b0;
                received_count    <= 8'd0;

            end

            else if (cxl_valid && cxl_ready) begin

                valid_bytes = count_keep(cxl_keep);

                temp_count = received_count;

                for (i = 0; i < 16; i = i + 1) begin

                    if (cxl_keep[i]) begin

                        expected_byte = temp_count[7:0];

                        if (cxl_data[8*i +: 8] !== expected_byte)
                            error <= 1'b1;

                        temp_count = temp_count + 1;

                    end

                end

                temp_offset = flit_offset + valid_bytes;

                if (expect_flit_start && !cxl_flit_start)
                    error <= 1'b1;

                if (!expect_flit_start && cxl_flit_start)
                    error <= 1'b1;

                // A final partial flit is valid.
                if (cxl_flit_last) begin

                    if (!cxl_last && temp_offset != 256)
                        error <= 1'b1;

                    flit_offset       <= 9'd0;
                    expect_flit_start <= 1'b1;

                end
                else begin

                    if (temp_offset >= 256)
                        error <= 1'b1;

                    flit_offset       <= temp_offset[8:0];
                    expect_flit_start <= 1'b0;

                end

                if (cxl_last) begin

                    if (temp_count != 32)
                        error <= 1'b1;

                    burst_done <= 1'b1;

                end
                else begin

                    if (temp_count >= 32)
                        error <= 1'b1;

                end

                received_count <= temp_count[7:0];

            end

        end

    end

endmodule