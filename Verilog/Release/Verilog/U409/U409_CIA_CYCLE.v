module U409_CIA_CYCLE

(
    input CLK40, CLK28,

    input RESETn, RnW, TSn, CIA0_SPACE, CIA1_SPACE, TACK_EN,

    output reg CLK_CIA, CIA_TACK_EN, CIA_ADDR_LATCH,
    output CIACS0n, CIACS1n

);

//--- Detect the start of a CIA cycle. ---
reg CIA_START_CYCLE;
always @(posedge CLK40) begin
    if (!RESETn) begin
        CIA_START_CYCLE <= 1'b0;
    end else begin
        if (CIA_START_CYCLE) begin
            if (CIA_EN_SYNC[1]) begin
                CIA_START_CYCLE <= 1'b0;
            end
        end else begin
            CIA_START_CYCLE <= (!TSn && (CIA0_SPACE || CIA1_SPACE));
        end
    end
end

//--- Syncronize the CPU signals to the 28MHz domain. ---
reg [1:0] CIA_START_CYCLE_SYNC;
reg [1:0] RW_SYNC;
always @(posedge CLK28) begin
    if (!RESETn) begin
        CIA_START_CYCLE_SYNC <= 2'b00;
        RW_SYNC <= 2'b11;
    end else begin
        CIA_START_CYCLE_SYNC <= {CIA_START_CYCLE_SYNC[0], CIA_START_CYCLE};
        RW_SYNC <= {RW_SYNC[0], RnW};
    end
end

//--- Syncronize CIA signals to the CPU domain. ---
reg [1:0] CIA_EN_SYNC;
reg [1:0] CIA_TERM_CYCLE_SYNC;
always @(posedge CLK40) begin
    if (!RESETn) begin
        CIA_EN_SYNC <= 2'b00;
        CIA_TERM_CYCLE_SYNC <= 2'b00;
    end else begin
        CIA_EN_SYNC <= {CIA_EN_SYNC[0], CIA_EN};
        CIA_TERM_CYCLE_SYNC <= {CIA_TERM_CYCLE_SYNC[0], CIA_TERM_CYCLE};
    end
end

//--- Divide by 4 to generate a 7MHz clock. ---
reg [1:0] DIV_FOUR;
always @(posedge CLK28) begin
    DIV_FOUR <= DIV_FOUR + 1;
end

//--- Detect the negative edge of the 7MHz clock. ----
wire NEGEDGE_CLK7 = DIV_FOUR == 2'b00;

//--- Drive the CIA chip select signals. ---
assign CIACS0n = ~(CIA0_EN && CIA_EN);
assign CIACS1n = ~(CIA1_EN && CIA_EN);

//---Make the E clock. ---
reg [3:0] ECLK_STATE;
reg CIA_WRITE_CYCLE;
reg CIA_TERM_CYCLE;
reg CIA_EN;
reg CIA0_EN;
reg CIA1_EN;
always @(posedge CLK28) begin
    if (NEGEDGE_CLK7) begin
        case (ECLK_STATE)
            4'h0 : begin
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h1;
            end
            4'h1 : begin
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h2;
            end
            4'h2 : begin
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h3;
            end
            4'h3 : begin
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h4;
            end
            4'h4 : begin
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h5;
            end
            4'h5 : begin
                if (CIA_START_CYCLE_SYNC[1]) begin
                    CIA0_EN <= CIA0_SPACE;
                    CIA1_EN <= CIA1_SPACE;
                    CIA_EN <= 1'b1; //Enable the CIA chip select on the last clock before E goes high.
                    CIA_ADDR_LATCH <= 1'b1; //Latch the CIA address on the CIA at the time the chip select is enabled.
                    CIA_WRITE_CYCLE <= ~(RW_SYNC[1]);
                end
                CLK_CIA <= 1'b0;
                ECLK_STATE <= 4'h6;
            end
            4'h6 : begin
                CLK_CIA <= 1'b1; //First clock where the E clock is high.
                CIA_ADDR_LATCH <= 1'b0; //We are done with the latch signal.
                ECLK_STATE <= 4'h7;
            end
            4'h7 : begin
                CLK_CIA <= 1'b1;
                ECLK_STATE <= 4'h8;
            end
            4'h8 : begin
                if (CIA_EN) begin
                    CIA_TERM_CYCLE <= 1'b1;
                    CLK_CIA <= ~(CIA_WRITE_CYCLE); //The CIA latches write data on the falling E clock edge.
                end else begin
                    CLK_CIA <= 1'b1;
                end
                ECLK_STATE <= 4'h9;
            end
            4'h9 : begin
                if (CIA_EN) begin
                    CLK_CIA <= 1'b0;
                    CIA_EN <= 1'b0;
                    CIA_TERM_CYCLE <= 1'b0;
                end else begin
                    CLK_CIA <= 1'b1;
                end
                ECLK_STATE <= 4'h0;
            end
        endcase
    end
end

//--- Cycle Termination ---
localparam [1:0] CIA_TERM_IDLE = 2'b00;
localparam [1:0] CIA_TERM_ASST = 2'b01;
localparam [1:0] CIA_TERM_RARM = 2'b10;
localparam [3:0] CIA_TACK_DEL  = 4'h2;

reg [1:0] CIA_TERM_STATE;
reg [3:0] CIA_TACK_DEL_COUNTER;
always @(negedge CLK40) begin
    if (!RESETn) begin
        CIA_TACK_EN <= 1'b0;        
        CIA_TERM_STATE <= CIA_TERM_IDLE;
        CIA_TACK_DEL_COUNTER <= 4'h0;
    end else begin
        case (CIA_TERM_STATE)
            2'b00 : begin
                if (CIA_TERM_CYCLE_SYNC[1]) begin
                    CIA_TERM_STATE <= 2'b01;
                end
            end
            2'b01 : begin
                if (CIA_TACK_DEL_COUNTER == CIA_TACK_DEL) begin
                    CIA_TACK_EN <= 1'b1;
                    CIA_TACK_DEL_COUNTER <= 4'h0;
                    CIA_TERM_STATE <= 2'b10;
                end else begin
                    CIA_TACK_DEL_COUNTER <=  CIA_TACK_DEL_COUNTER + 1;
                end
            end
            2'b10 : begin
                if (TACK_EN) begin
                    CIA_TACK_EN <= 1'b0;
                    CIA_TERM_STATE <= 2'b11;
                end
            end
            2'b11 : begin
                if (!CIA_TERM_CYCLE_SYNC[1]) begin
                    CIA_TERM_STATE <= 2'b00;
                end
            end
        endcase
    end
end

endmodule
