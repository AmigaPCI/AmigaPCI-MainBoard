
module U109_PCI_STATE_MACHINE (
    
    //Clocks
    input CLK66, CLK33, CLK80, CLK40,

    //Cycle
    input RESETn, CPU_BUSn, RnW, TSn,
    output TACKn_OUT, TBIn,
    input [31:30] REG_DATA,

    //PCI Commands
    input PCI_TIPn, A_REGISTER, BRIDGE_CONF_SPACE, STOPn,
    output PCI_RSTn, PCI_CYCLEn,
    output reg PARITY_DIR, DATA_BUFFER_EN, P2A_READ_NEXT, A2P_READ_NEXT, P2A_TIMEOUT, RETRY_CYCLE, PCI_INT_ENn,
    input TRDYn,
    inout IRDYn

    //,output TP0
    
);

//assign TP0 = TACK_START;

//--------------------------------------------------------------------------------

////////////////////////////
// PARITY DATA DIRECTION //
//////////////////////////

//Parity Direction
//0 = PCI to FPGA
//1 = FPGA to PCI

//    ADDRESS PHASE   DATA PHASE
//      CPU  DMA      CPU     DMA
//    --------------------------
// RD    1    0       0 (P2A) 1 (A2P)
// WR    1    0       1 (A2P) 0 (P2A)

wire A2P_CYCLE_EN = (CPU_A2P_CYCLE || DMA_A2P_CYCLE);
wire PAR_RST = (!RESETn || PCI_TIPn);

reg PAR_ADDRESS_PHASE;
reg [1:0] PAR_STATE;
always @(negedge CLK33, posedge PAR_RST) begin
    if (PAR_RST) begin
        PARITY_DIR <= 1'b1;
        PAR_ADDRESS_PHASE <= 1'b1;
    end else begin
        if (PAR_ADDRESS_PHASE) begin
            PAR_ADDRESS_PHASE <= 1'b0;
        end else begin
            PARITY_DIR <= A2P_CYCLE_EN;
        end
    end
end

//--------------------------------------------------------------------------------

////////////////////////////
// BRIDGE REGISTER CYCLE //
//////////////////////////

//We support a write only register at offset $FC in the bridge space.

//PCI devices are held in reset until a write to this register takes them out of reset.

//D[31] = PCI bus reset bit.
//D[30] = Enable PCI interupts.

assign PCI_RSTn = ~(!RESETn || PCI_RST_REG);
wire REG_CYCLE_START = (!TSn && !RnW && BRIDGE_CONF_SPACE && A_REGISTER);

reg REG_CYCLE, PCI_RST_REG;
always @(posedge CLK40 or posedge REG_CYCLE_START) begin
    if (REG_CYCLE_START) begin
        REG_CYCLE <= 1'b1;
    end else if (!RESETn) begin
        PCI_RST_REG <= 1'b1;
        PCI_INT_ENn <= 1'b1;
        REG_CYCLE <= 1'b0;
    end else begin
        if (REG_CYCLE) begin
            PCI_RST_REG <= ~REG_DATA[31];
            PCI_INT_ENn <=  REG_DATA[30];
            REG_CYCLE   <=  1'b0;
        end
    end    
end

//--------------------------------------------------------------------------------

////////////////////
// CLOCK SAMPLES //
//////////////////

//--- PCI Domain Clock ---

reg CLK33_PREV;
always @(negedge CLK66) begin
    CLK33_PREV <= CLK33;
end

//--- AMIGA Domain Clock ---

reg CLK40_PREV;
always @(negedge CLK80) begin
    CLK40_PREV <= CLK40;
end

//--------------------------------------------------------------------------------

////////////////////////////
// CPU DRIVEN PCI CYCLES //
//////////////////////////

//Start all non-register cycles here. We determine if this is a CPU cycle or a DMA cycle, 
//which then signals other state machines to take over from there. Signals are 
//enabled as conditioned by cycle type.
//All cycles start by recognizing the assertion of _PCITIP from U110. _PCICYCLE
//is in the 33MHz domain.

localparam [3:0] START_CYCLE_IDLE  = 4'h0;
localparam [3:0] START_CYCLE_IP    = 4'h1;
localparam [3:0] START_CYCLE_NEG   = 4'h2;
localparam [3:0] START_CYCLE_REARM = 4'h3;
localparam [3:0] START_CYCLE_END   = 4'h4;

//--- External PCI signals ---
assign IRDYn = CPU_CYCLE ? ~IRDY_EN : 1'bz;
assign PCI_CYCLEn = ~PCI_CYCLE_EN;

//--- Helper Signals ---
wire CPU_CYCLE = (CPU_A2P_CYCLE || CPU_P2A_CYCLE);
wire START_PCI_CYCLE = (!PCI_TIPn && !CPU_BUSn && CLK33_PREV); //Assert on falling edge of CLK33.
wire END_PCI_CYCLE = (PCI_TIPn && !CLK33_PREV); //Sample on the rising edge of CLK33
wire RETRY_PCI_CYCLE = (!STOPn && TRDYn && CPU_CYCLE && !CLK33_PREV); //Sample on the rising edge of CLK33
wire TRDY_DETECT = (!TRDYn && CPU_CYCLE && !CLK33_PREV); //Capture _TRDY on rising edge for CPU driven cycles
wire TACK_ASST = (TACK_EN_SYNC != 2'b00 && CLK33_PREV); //Done on the falling edge of CLK33 for the A2P Fifo read next command.

//--- PCI State Machine ---
reg CPU_A2P_CYCLE;
reg CPU_P2A_CYCLE;
reg IRDY_EN;
reg TIMEOUT_ASST;
reg PCI_CYCLE_EN;
reg BUFFER_EN;
reg RETRY_RST;
reg [1:0] RW_SYNC;
reg [1:0] TACK_EN_SYNC;
reg [3:0] START_CYCLE_STATE;

always @(posedge CLK66) begin
    if (!RESETn) begin
        BUFFER_EN     <= 1'b0;
        IRDY_EN       <= 1'b0;
        TIMEOUT_ASST  <= 1'b0;
        A2P_READ_NEXT <= 1'b0;
        P2A_TIMEOUT   <= 1'b0;
        RETRY_RST     <= 1'b0;
        PCI_CYCLE_EN  <= 1'b0;
        CPU_A2P_CYCLE <= 1'b0;
        CPU_P2A_CYCLE <= 1'b0;
        RW_SYNC       <= 2'b00;
        TACK_EN_SYNC  <= 2'b00;
        START_CYCLE_STATE <= START_CYCLE_IDLE;
    end else begin

        RW_SYNC <= {RW_SYNC[0], RnW};
        
        case (START_CYCLE_STATE)

            START_CYCLE_IDLE : begin
                if (START_PCI_CYCLE) begin
                    //Falling Edge
                    CPU_A2P_CYCLE <= ~(RW_SYNC[1]); //CPU Write cycle
                    CPU_P2A_CYCLE <=   RW_SYNC[1];  //CPU Read cycle
                    IRDY_EN <= 1'b1;
                    BUFFER_EN <= 1'b1;
                    PCI_CYCLE_EN <= 1'b1;
                    START_CYCLE_STATE <= START_CYCLE_IP;
                end
            end

            START_CYCLE_IP : begin
                // Rising edge
                if (RETRY_PCI_CYCLE || TRDY_DETECT || END_PCI_CYCLE) begin
                    BUFFER_EN <= 1'b0;
                    START_CYCLE_STATE <= START_CYCLE_NEG;

                    if (RETRY_PCI_CYCLE) begin
                        RETRY_CYCLE   <= 1'b1;
                        RETRY_RST     <= 1'b1;
                        CPU_A2P_CYCLE <= 1'b0;
                        CPU_P2A_CYCLE <= 1'b0;
                    end else begin
                        RETRY_CYCLE <= 1'b0;
                        A2P_READ_NEXT <= CPU_A2P_CYCLE; //Early move to next fifo entry
                        if (END_PCI_CYCLE) begin // Timeout
                            TIMEOUT_ASST <= 1'b1;   // Terminate the cycle
                            P2A_TIMEOUT  <= 1'b1;   // Tell buffers to drive 0xffffffff
                        end
                    end
                end
            end

            START_CYCLE_NEG : begin
                //Falling Edge
                if (RETRY_CYCLE) begin
                    RETRY_RST <= 1'b0;
                    START_CYCLE_STATE <= START_CYCLE_IDLE;
                end else begin
                    START_CYCLE_STATE <= START_CYCLE_REARM;
                end

                PCI_CYCLE_EN <= 1'b0;
                IRDY_EN <= 1'b0;
            end

            START_CYCLE_REARM : begin
                //A2P_READ_NEXT <= CPU_A2P_CYCLE; //Rising edge.
                A2P_READ_NEXT <= 1'b0; //Rising Edge
                if (TACK_ASST || (CPU_A2P_CYCLE && CLK33_PREV)) begin
                    //Falling or Rising Edge
                    TIMEOUT_ASST  <= 1'b0;
                    TACK_EN_SYNC  <= 2'b00;
                    START_CYCLE_STATE <= START_CYCLE_END;
                end else begin
                    TACK_EN_SYNC <= {TACK_EN_SYNC[0], ~TACK_OUT};
                end
            end

            START_CYCLE_END : begin
                if (!CLK33_PREV) begin
                    //Rising Edge
                    P2A_TIMEOUT   <= 1'b0;
                    CPU_A2P_CYCLE <= 1'b0;
                    CPU_P2A_CYCLE <= 1'b0;
                    //A2P_READ_NEXT <= 1'b0;
                    START_CYCLE_STATE <= START_CYCLE_IDLE;
                end
            end

        endcase

    end
end

////////////////////
// BUFFER ENABLE //
//////////////////

//It is important the AD data buffers are not enabled longer than necessary.
//This can cause issues with the next cycle. The buffers are enabled in the 
//PCI clock domain, so We use an asynchronous reset from the Amiga clock 
//domain to shut them off. In the event of a retry cycle, we turn the buffers
//off using the same mechanism.

wire BUF_RST = (!RESETn || BUFFER_RST || RETRY_RST);

always @(posedge CLK66, posedge BUF_RST) begin
    if (BUF_RST) begin
        DATA_BUFFER_EN <= 1'b0;
    end else begin
        if (!DATA_BUFFER_EN && BUFFER_EN) begin
            DATA_BUFFER_EN <= 1'b1;
        end
    end
end

////////////////////////////
// CPU CYCLE TERMINATION //
//////////////////////////

//_TACK is super slow to get out. Not sure why, but have not found a solution.
//It takes an ABSURD 20ns for the _TACK signal to hit the pin.
//Because of that, some of the state machine states may look funny, but it gets
//the signal on the edge it needs to be.

//We start the _TACK state machine when _TRDY assertion is detected. This is for 
//A2P and P2A cycles.

localparam [3:0] TACK_STATE_IDLE  = 4'h0;
localparam [3:0] TACK_STATE_ASST  = 4'h1;
localparam [3:0] TACK_STATE_NEG   = 4'h2;
localparam [3:0] TACK_STATE_BRST  = 4'h3;
localparam [3:0] TACK_STATE_REARM = 4'h4;

assign TACKn_OUT = TACK_EN ? TACK_OUT : 1'bz;
assign TBIn = TACK_EN ? TACK_OUT : 1'bz;

wire TACK_START = (TRDY_ASST_SYNC != 2'b00 && CLK40_PREV);

reg TACK_EN;
reg TACK_OUT;
reg BUFFER_RST;
reg [1:0] TRDY_ASST_SYNC;
reg [3:0] TACK_STATE;

always @(posedge CLK80) begin
    if (!RESETn) begin
        TACK_EN <= 1'b0;
        TACK_OUT <= 1'b1;
        P2A_READ_NEXT <= 1'b0;
        BUFFER_RST <= 1'b0;
        TRDY_ASST_SYNC <= 2'b00;
        TACK_STATE <= TACK_STATE_IDLE;
    end else begin

        case (TACK_STATE)

            TACK_STATE_IDLE : begin
                if (TACK_START) begin
                    //Falling CLK40 Edge
                    TACK_EN <= 1'b1;
                    TRDY_ASST_SYNC <= 2'b00;
                    TACK_STATE <= TACK_STATE_ASST;
                end else begin
                    TRDY_ASST_SYNC <= {TRDY_ASST_SYNC[0], (!TRDYn || TIMEOUT_ASST)};
                end
            end

            TACK_STATE_ASST : begin
                //Rising Edge
                TACK_OUT <= 1'b0;
                TACK_STATE <= TACK_STATE_NEG;
            end

            TACK_STATE_NEG : begin
                if (!CLK40_PREV) begin
                    //Rising CLK40 edge.
                    TACK_OUT <= 1'b1;
                    P2A_READ_NEXT <= (CPU_P2A_CYCLE && !P2A_TIMEOUT); //Jumps clock domains! Load next P2A slot into FIFO.
                    TACK_STATE <= TACK_STATE_BRST;
                end
            end

            TACK_STATE_BRST : begin 
                //Falling CLK40 edge.
                BUFFER_RST <= 1'b1;
                TACK_STATE <= TACK_STATE_REARM;
            end

            TACK_STATE_REARM : begin
                //Rising CLK40 edge.
                TACK_EN <= 1'b0;
                BUFFER_RST <= 1'b0;
                P2A_READ_NEXT <= 1'b0;
                TACK_STATE <= TACK_STATE_IDLE;
            end

        endcase

    end
end

//--------------------------------------------------------------------------------

////////////////////////
// DMA DRIVEN CYCLES //
//////////////////////

wire DMA_A2P_CYCLE = 1'b0;
wire DMA_P2A_CYCLE = 1'b0;
//reg DMA_A2P_CYCLE;
//reg DMA_P2A_CYCLE;

endmodule