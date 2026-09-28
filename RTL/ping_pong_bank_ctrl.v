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

    localparam FREE  = 2'b00;
    localparam FILL  = 2'b01;
    localparam READY = 2'b10;
    localparam READ  = 2'b11;

    reg [1:0] bank0_state;
    reg [1:0] bank1_state;

    reg       write_bank_reg;
    reg       read_bank_reg;
    reg       read_active;

    reg       bank0_started;
    reg       bank1_started;

    reg [3:0] bank0_first_word;
    reg [3:0] bank1_first_word;

    reg [3:0] bank0_last_word;
    reg [3:0] bank1_last_word;

    reg       bank0_burst_last;
    reg       bank1_burst_last;

    reg [1:0] bank0_state_next;
    reg [1:0] bank1_state_next;

    reg       write_bank_next;
    reg       read_bank_next;
    reg       read_active_next;

    reg       bank0_started_next;
    reg       bank1_started_next;

    reg [3:0] bank0_first_word_next;
    reg [3:0] bank1_first_word_next;

    reg [3:0] bank0_last_word_next;
    reg [3:0] bank1_last_word_next;

    reg       bank0_burst_last_next;
    reg       bank1_burst_last_next;

    reg       rd_issue_reg;
    reg       rd_bank_reg;
    reg [3:0] rd_addr_reg;
    reg       rd_issue_last_reg;
    reg       rd_issue_flit_last_reg;

    wire in_fire;
    wire out_fire;
    wire read_done;

    assign in_ready =
        (write_bank_reg == 1'b0) ?
        (bank0_state == FILL) :
        (bank1_state == FILL);

    assign write_bank =
        write_bank_reg;

    assign in_fire =
        in_valid &&
        in_ready;

    assign out_fire =
        out_valid &&
        out_ready;

    assign read_done =
        out_fire &&
        out_flit_last;

    assign rd_issue =
        rd_issue_reg;

    assign rd_bank =
        rd_bank_reg;

    assign rd_addr =
        rd_addr_reg;

    assign rd_issue_last =
        rd_issue_last_reg;

    assign rd_issue_flit_last =
        rd_issue_flit_last_reg;

    always @* begin

        bank0_state_next = bank0_state;
        bank1_state_next = bank1_state;

        write_bank_next = write_bank_reg;

        read_bank_next = read_bank_reg;
        read_active_next = read_active;

        bank0_started_next = bank0_started;
        bank1_started_next = bank1_started;

        bank0_first_word_next = bank0_first_word;
        bank1_first_word_next = bank1_first_word;

        bank0_last_word_next = bank0_last_word;
        bank1_last_word_next = bank1_last_word;

        bank0_burst_last_next = bank0_burst_last;
        bank1_burst_last_next = bank1_burst_last;

        rd_issue_reg = 1'b0;
        rd_bank_reg = read_bank_reg;
        rd_addr_reg = 4'd0;
        rd_issue_last_reg = 1'b0;
        rd_issue_flit_last_reg = 1'b0;

        // Free the bank after its final output word.
        if (read_done) begin

            if (read_bank_reg == 1'b0)
                bank0_state_next = FREE;
            else
                bank1_state_next = FREE;

            read_active_next = 1'b0;
        end

        // Capture incoming packed words.
        if (in_fire) begin

            if (write_bank_reg == 1'b0) begin

                if (!bank0_started) begin
                    bank0_first_word_next = in_word_index;
                    bank0_started_next = 1'b1;
                end

                if (in_flit_last) begin
                    bank0_last_word_next = in_word_index;
                    bank0_burst_last_next = in_last;
                    bank0_started_next = 1'b0;
                    bank0_state_next = READY;
                end

            end
            else begin

                if (!bank1_started) begin
                    bank1_first_word_next = in_word_index;
                    bank1_started_next = 1'b1;
                end

                if (in_flit_last) begin
                    bank1_last_word_next = in_word_index;
                    bank1_burst_last_next = in_last;
                    bank1_started_next = 1'b0;
                    bank1_state_next = READY;
                end

            end
        end

        // Move writer to a free bank.
        if (write_bank_reg == 1'b0) begin

            if ((bank0_state_next != FILL) &&
                (bank1_state_next == FREE)) begin

                write_bank_next = 1'b1;
                bank1_state_next = FILL;
                bank1_started_next = 1'b0;
            end

        end
        else begin

            if ((bank1_state_next != FILL) &&
                (bank0_state_next == FREE)) begin

                write_bank_next = 1'b0;
                bank0_state_next = FILL;
                bank0_started_next = 1'b0;
            end
        end

        // Continue current bank.
        if (read_active) begin

            if (out_fire && !out_flit_last) begin

                rd_issue_reg = 1'b1;
                rd_bank_reg = read_bank_reg;
                rd_addr_reg = out_word_index + 4'd1;

                if (read_bank_reg == 1'b0) begin

                    rd_issue_flit_last_reg =
                        ((out_word_index + 4'd1) ==
                         bank0_last_word);

                    rd_issue_last_reg =
                        ((out_word_index + 4'd1) ==
                         bank0_last_word) &&
                        bank0_burst_last;

                end
                else begin

                    rd_issue_flit_last_reg =
                        ((out_word_index + 4'd1) ==
                         bank1_last_word);

                    rd_issue_last_reg =
                        ((out_word_index + 4'd1) ==
                         bank1_last_word) &&
                        bank1_burst_last;
                end
            end

            // Safe bank handoff only to a bank already READY.
            else if (out_fire && out_flit_last) begin

                if ((read_bank_reg == 1'b0) &&
                    (bank1_state == READY)) begin

                    rd_issue_reg = 1'b1;
                    rd_bank_reg = 1'b1;
                    rd_addr_reg = bank1_first_word;

                    rd_issue_flit_last_reg =
                        (bank1_first_word == bank1_last_word);

                    rd_issue_last_reg =
                        (bank1_first_word == bank1_last_word) &&
                        bank1_burst_last;

                    bank1_state_next = READ;
                    read_bank_next = 1'b1;
                    read_active_next = 1'b1;

                end
                else if ((read_bank_reg == 1'b1) &&
                         (bank0_state == READY)) begin

                    rd_issue_reg = 1'b1;
                    rd_bank_reg = 1'b0;
                    rd_addr_reg = bank0_first_word;

                    rd_issue_flit_last_reg =
                        (bank0_first_word == bank0_last_word);

                    rd_issue_last_reg =
                        (bank0_first_word == bank0_last_word) &&
                        bank0_burst_last;

                    bank0_state_next = READ;
                    read_bank_next = 1'b0;
                    read_active_next = 1'b1;
                end
            end

        end
        else begin

            // Start a bank that was already READY.
            if ((bank0_state == READY) &&
                (write_bank_reg != 1'b0)) begin

                rd_issue_reg = 1'b1;
                rd_bank_reg = 1'b0;
                rd_addr_reg = bank0_first_word;

                rd_issue_flit_last_reg =
                    (bank0_first_word == bank0_last_word);

                rd_issue_last_reg =
                    (bank0_first_word == bank0_last_word) &&
                    bank0_burst_last;

                bank0_state_next = READ;
                read_bank_next = 1'b0;
                read_active_next = 1'b1;

            end
            else if ((bank1_state == READY) &&
                     (write_bank_reg != 1'b1)) begin

                rd_issue_reg = 1'b1;
                rd_bank_reg = 1'b1;
                rd_addr_reg = bank1_first_word;

                rd_issue_flit_last_reg =
                    (bank1_first_word == bank1_last_word);

                rd_issue_last_reg =
                    (bank1_first_word == bank1_last_word) &&
                    bank1_burst_last;

                bank1_state_next = READ;
                read_bank_next = 1'b1;
                read_active_next = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            bank0_state <= FILL;
            bank1_state <= FREE;

            write_bank_reg <= 1'b0;

            read_bank_reg <= 1'b0;
            read_active <= 1'b0;

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

            bank0_state <= bank0_state_next;
            bank1_state <= bank1_state_next;

            write_bank_reg <= write_bank_next;

            read_bank_reg <= read_bank_next;
            read_active <= read_active_next;

            bank0_started <= bank0_started_next;
            bank1_started <= bank1_started_next;

            bank0_first_word <= bank0_first_word_next;
            bank1_first_word <= bank1_first_word_next;

            bank0_last_word <= bank0_last_word_next;
            bank1_last_word <= bank1_last_word_next;

            bank0_burst_last <= bank0_burst_last_next;
            bank1_burst_last <= bank1_burst_last_next;
        end
    end

endmodule