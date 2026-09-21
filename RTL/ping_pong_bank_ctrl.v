`timescale 1ns / 1ps

module ping_pong_bank_ctrl (
    input         clk,
    input         rst_n,

    input         in_valid,
    input  [3:0]  in_word_index,
    input         in_flit_last,
    input         in_last,
    output        in_ready,
    output        write_bank,

    input         out_valid,
    input         out_ready,
    input         out_flit_last,
    input  [3:0]  out_word_index,

    output        rd_issue,
    output        rd_bank,
    output [3:0]  rd_addr,
    output        rd_issue_last,
    output        rd_issue_flit_last
);

    localparam BANK_FREE  = 2'b00;
    localparam BANK_FILL  = 2'b01;
    localparam BANK_READY = 2'b10;
    localparam BANK_READ  = 2'b11;

    reg [1:0] bank0_state;
    reg [1:0] bank1_state;

    reg       write_bank_reg;

    reg       read_active;
    reg       read_bank_reg;

    reg       bank0_started;
    reg       bank1_started;

    reg [3:0] bank0_first_word;
    reg [3:0] bank1_first_word;

    reg [3:0] bank0_last_word;
    reg [3:0] bank1_last_word;

    reg       bank0_burst_last;
    reg       bank1_burst_last;

    wire in_fire;
    wire out_fire;
    wire out_flit_done;

    wire read_other_bank;

    wire bank0_free_now;
    wire bank1_free_now;

    assign in_ready =
        (write_bank_reg == 1'b0) ?
        (bank0_state == BANK_FILL) :
        (bank1_state == BANK_FILL);

    assign write_bank =
        write_bank_reg;

    assign in_fire =
        in_valid &&
        in_ready;

    assign out_fire =
        out_valid &&
        out_ready;

    assign out_flit_done =
        out_fire &&
        out_flit_last;

    assign read_other_bank =
        read_active &&
        (read_bank_reg != write_bank_reg);

    // A bank finishing its read is usable on the same clock edge.
    assign bank0_free_now =
        (bank0_state == BANK_FREE) ||
        ((bank0_state == BANK_READ) &&
         out_flit_done &&
         (read_bank_reg == 1'b0));

    assign bank1_free_now =
        (bank1_state == BANK_FREE) ||
        ((bank1_state == BANK_READ) &&
         out_flit_done &&
         (read_bank_reg == 1'b1));

    // Read scheduler.
    assign rd_issue =
        (!read_active) ?
            ((bank0_state == BANK_READY) ||
             (bank1_state == BANK_READY)) :
        (out_fire &&
         (!out_flit_last ||
          ((read_bank_reg == 1'b0) &&
           (bank1_state == BANK_READY)) ||
          ((read_bank_reg == 1'b1) &&
           (bank0_state == BANK_READY))));

    assign rd_bank =
        (!read_active) ?
            ((bank0_state == BANK_READY) ? 1'b0 : 1'b1) :
        (out_flit_last) ?
            ((read_bank_reg == 1'b0) ? 1'b1 : 1'b0) :
            read_bank_reg;

    assign rd_addr =
        (!read_active) ?
            ((bank0_state == BANK_READY) ?
                bank0_first_word : bank1_first_word) :
        (!out_flit_last) ?
            (out_word_index + 4'd1) :
            ((read_bank_reg == 1'b0) ?
                bank1_first_word : bank0_first_word);

    assign rd_issue_flit_last =
        (!read_active) ?
            ((bank0_state == BANK_READY) ?
                (bank0_first_word == bank0_last_word) :
                (bank1_first_word == bank1_last_word)) :
        (!out_flit_last) ?
            ((read_bank_reg == 1'b0) ?
                ((out_word_index + 4'd1) == bank0_last_word) :
                ((out_word_index + 4'd1) == bank1_last_word)) :
        ((read_bank_reg == 1'b0) ?
            (bank1_first_word == bank1_last_word) :
            (bank0_first_word == bank0_last_word));

    assign rd_issue_last =
        (!read_active) ?
            ((bank0_state == BANK_READY) ?
                ((bank0_first_word == bank0_last_word) &&
                 bank0_burst_last) :
                ((bank1_first_word == bank1_last_word) &&
                 bank1_burst_last)) :
        (!out_flit_last) ?
            ((read_bank_reg == 1'b0) ?
                (((out_word_index + 4'd1) == bank0_last_word) &&
                 bank0_burst_last) :
                (((out_word_index + 4'd1) == bank1_last_word) &&
                 bank1_burst_last)) :
        ((read_bank_reg == 1'b0) ?
            ((bank1_first_word == bank1_last_word) &&
             bank1_burst_last) :
            ((bank0_first_word == bank0_last_word) &&
             bank0_burst_last));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            bank0_state <= BANK_FILL;
            bank1_state <= BANK_FREE;

            write_bank_reg <= 1'b0;

            read_active  <= 1'b0;
            read_bank_reg <= 1'b0;

            bank0_started <= 1'b0;
            bank1_started <= 1'b0;

            bank0_first_word <= 4'd0;
            bank1_first_word <= 4'd0;

            bank0_last_word <= 4'd15;
            bank1_last_word <= 4'd15;

            bank0_burst_last <= 1'b0;
            bank1_burst_last <= 1'b0;

        end
        else begin

            // Start or continue reading a bank.
            if (rd_issue) begin

                read_active   <= 1'b1;
                read_bank_reg <= rd_bank;

                if (rd_bank == 1'b0) begin
                    bank0_state <= BANK_READ;
                end
                else begin
                    bank1_state <= BANK_READ;
                end

            end

            // Current read bank finished.
            if (out_flit_done) begin

                if (read_bank_reg == 1'b0) begin
                    bank0_state <= BANK_FREE;
                end
                else begin
                    bank1_state <= BANK_FREE;
                end

                if (!rd_issue) begin
                    read_active <= 1'b0;
                end

            end

            // Capture incoming words.
            if (in_fire) begin

                if (write_bank_reg == 1'b0) begin

                    if (!bank0_started) begin
                        bank0_first_word <= in_word_index;
                        bank0_started    <= 1'b1;
                    end

                    if (in_flit_last) begin
                        bank0_last_word  <= in_word_index;
                        bank0_burst_last <= in_last;
                        bank0_state      <= BANK_READY;
                        bank0_started    <= 1'b0;

                        if (bank1_free_now) begin
                            bank1_state      <= BANK_FILL;
                            bank1_started    <= 1'b0;
                            write_bank_reg   <= 1'b1;
                        end
                    end

                end
                else begin

                    if (!bank1_started) begin
                        bank1_first_word <= in_word_index;
                        bank1_started    <= 1'b1;
                    end

                    if (in_flit_last) begin
                        bank1_last_word  <= in_word_index;
                        bank1_burst_last <= in_last;
                        bank1_state      <= BANK_READY;
                        bank1_started    <= 1'b0;

                        if (bank0_free_now) begin
                            bank0_state      <= BANK_FILL;
                            bank0_started    <= 1'b0;
                            write_bank_reg   <= 1'b0;
                        end
                    end

                end
            end

            // A completed read frees the opposite bank for writing.
            if (!in_fire || !in_flit_last) begin

                if (write_bank_reg == 1'b0) begin

                    if ((bank0_state != BANK_FILL) &&
                        bank1_free_now) begin

                        bank1_state    <= BANK_FILL;
                        bank1_started  <= 1'b0;
                        write_bank_reg <= 1'b1;

                    end

                end
                else begin

                    if ((bank1_state != BANK_FILL) &&
                        bank0_free_now) begin

                        bank0_state    <= BANK_FILL;
                        bank0_started  <= 1'b0;
                        write_bank_reg <= 1'b0;

                    end

                end
            end

        end
    end

endmodule