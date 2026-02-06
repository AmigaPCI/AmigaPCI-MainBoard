/*
LICENSE:

This work is released under the Creative Commons Attribution-NonCommercial 4.0 International
https://creativecommons.org/licenses/by-nc/4.0/

You are free to:
Share — copy and redistribute the material in any medium or format
Adapt — remix, transform, and build upon the material
The licensor cannot revoke these freedoms as long as you follow the license terms.

Under the following terms:
Attribution — You must give appropriate credit , provide a link to the license, and indicate if changes were made . You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
NonCommercial — You may not use the material for commercial purposes .
No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

RTL MODULE:

Engineer: Jason Neus
Design Name: U109
Module Name: U109_PCI_STATE_MACHINE
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Part of the PCI state machine.

Date          Who  Description
-----------------------------------
18-NOV-2025   JN   INITIAL CODE
21-NOV-2025   JN   Moved PCIAT assertion to this module.
01-DEC-2025   JN   Incorporate FIFO transactions.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_PCI_STATE_MACHINE (

    //Clocks
    input CLK80, CLK66, CLK40, CLK33, RESETn, RnW,

    //Cycle Start/Termination
    input CPU_BUS,
    input [1:0] REG_DATA,
    input BURSTn, PCI_TIPn, BRIDGE_CONF_SPACE, //PCI_WRITE_EN, 
    input [7:0] A,

    //FIFO
    //input P2A_FIFO_EMPTY, A2P_FIFO_EMPTY,

    //PCI Signals
    input CACHE_SPACE_EN, //DEVSELn,
    output TACKn, TBIn, PARITY_DIR, PCI_RSTn, //CLK_ADDRESS_LATCH,
    output reg P2A_READ_NEXT, A2P_READ_NEXT, TCI_ENn, BUFFER_EN, P2A_TIMEOUT, PCI_CYCLEn, RETRY_CYCLE,

    inout TSn, INIT_READYn, TARGET_READYn, STOPn

    ,output reg TP0, output TP1
);

//assign TP1 = REG_DATA;
//assign TP0 = REG_CYCLE;
//assign TP0 = A2P_TIMEOUT;
assign TP1 = RETRY_CYCLE;

/////////////////
// PARAMETERS //
///////////////

localparam [1:0] BURST_TOTAL = 2'b11;
localparam PCI_TO_AMIGA = 0;
localparam AMIGA_TO_PCI = 1;
localparam BRIDGE_REGISTER_ADDRESS  = 8'hfc;

///////////////////////
// WIRE ASSIGNMENTS //
/////////////////////

//assign CLK_ADDRESS_LATCH = 0;
assign INIT_READYn   =  CPU_BUS ? ~INIT_EN   : 1'bz;
assign TARGET_READYn = !CPU_BUS ? ~TRDY_EN   : 1'bz;
assign STOPn         = !CPU_BUS ? ~STOP_EN   : 1'bz;
assign TSn           = !CPU_BUS ? ~TS_OUT_EN : 1'bz;

assign PARITY_DIR    = (PCI_CYCLEn || A2P_CYCLE_EN) ? AMIGA_TO_PCI : PCI_TO_AMIGA;

////////////////////////////
// BRIDGE REGISTER CYCLE //
//////////////////////////

//We support a write only register at offset $FC in the bridge
//config0 space.

//D[31] = PCI bus reset bit
//D[30] = Test bit to drive _BREQ on the test card.

assign PCI_RSTn = !(!RESETn || PCI_RST_REG);
wire REG_CYCLE_START = (!TSn && !RnW && BRIDGE_CONF_SPACE && A == BRIDGE_REGISTER_ADDRESS);

reg REG_CYCLE, PCI_RST_REG, BREQ_TEST;
always @(posedge CLK40 or posedge REG_CYCLE_START) begin
    if (REG_CYCLE_START) begin
        REG_CYCLE <= 1;
    end else if (!RESETn) begin
        PCI_RST_REG <= 0;
        BREQ_TEST <= 0;
        REG_CYCLE <= 0;
    end else begin
        if (REG_CYCLE) begin
            PCI_RST_REG <= REG_DATA[1];
            BREQ_TEST   <= REG_DATA[0]; //THIS IS JUST FOR TESTING, NOT AN ACTUAL REGISTER!
            REG_CYCLE   <= 0;
        end
    end    
end

//THIS IS JUST FOR TESTING THE ARBITER!
//DELETE THIS LATER
reg [3:0] BREQ_COUNT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        TP0 <= 1;
        BREQ_COUNT <= 4'h0;
    end else begin
        if (BREQ_TEST) begin
            if (BREQ_COUNT == 4'ha) begin
                TP0 <= 1;
            end else begin
                TP0 <= 0;
                BREQ_COUNT <= BREQ_COUNT + 1;
            end
        end else begin
            BREQ_COUNT <= 4'h0;
        end
    end
end

///////////////////////////////////////
// AMIGA TO PCI (A2P) STATE MACHINE //
/////////////////////////////////////

//------ R/W cycle synchornizer ------
//Data moves from the Amiga bus to the PCI bus during CPU writes or DMA reads.
wire A2P_EN = CPU_BUS ? ~RnW : RnW;
reg PREV_CLK33;
reg [1:0] A2P_SYNC;
always @(negedge CLK66) begin
    if (!RESETn) begin
        PREV_CLK33 <= 0;
        A2P_SYNC <= 2'b0;
    end else begin
        PREV_CLK33 <= CLK33;
        A2P_SYNC <= {A2P_SYNC[0], A2P_EN};
    end
end

//------ Drive PCI_CYCLEn ------
//PCI_CYCLEn conditions many important signals for the PCI cycle.
//It also is the handshaking signal to U110 that indicates when
//a PCI cycle is active. It tells U110 when to negate _FRAME and
//_DEVSEL. In U109, it causes the address latch/conditin to be held
//during the cycle so we don't drop buffers.

//_STOP may asserted by the target device as a means to terminate the cycle.
//It takes precedence over our wishes. If the target device
//asserts _STOP, we then need to react to that by transferring the first
//word of data (if possible) and then terminate the CPU cycle by asserting _TBI. 
//If _STOP is asserted _TRDY is asserted, well,
//that's a problem and will need to result in a bus error.
//wire PCI_CYCLE_RST = (!RESETn || !STOPn || PCI_CYCLE_END);

//PCI_CYCLE_END terminates CPU driven cycles, TRDY_COMPLETE terminates DMA cycles.
wire PCI_CYCLE_RST = (!RESETn || PCI_CYCLE_END || TRDY_COMPLETE || RETRY_RESET);
always @(posedge CLK33 or posedge PCI_CYCLE_RST) begin
    if (PCI_CYCLE_RST) begin
        PCI_CYCLEn <= 1;
    end else begin
        if (PCI_CYCLE_EN) begin
            PCI_CYCLEn <= 0;
        end
    end
end

//Capture _TRDY so we can sample it on the falling edge.
reg PCI_CYCLE_TRDY, PCI_CYCLE_RETRY, INIT_READY_DELAY, CYCLE_TIMEOUT; //PCI_CYCLE_STOP
always @(posedge CLK33) begin
    if (!RESETn) begin
        PCI_CYCLE_TRDY   <= 0;
        //PCI_CYCLE_STOP   <= 0;
        PCI_CYCLE_RETRY <= 0;
        INIT_READY_DELAY <= 0;
        CYCLE_TIMEOUT      <= 0;
    end else begin
        //PCI_CYCLE_STOP   <= ~STOPn;
        PCI_CYCLE_TRDY   <= ~TARGET_READYn;
        PCI_CYCLE_RETRY  <= (!STOPn && TARGET_READYn);
        INIT_READY_DELAY <= ~INIT_READYn;
        CYCLE_TIMEOUT    <=  PCI_TIPn;
    end
end

//------ PCI State Machine ------
//We drive the signals common to both Amiga to PCI and PCI to Amiga data
//transfer cycle types. We assert _IRDY right away and then drive the
//proper cycle type, dictated by the direction of data movement.
//This state machine also pushes data to the AD bus.

wire P2A_RST = (!RESETn || P2A_CYCLE_RST);
wire BURST_CYCLE_EN = (CACHE_SPACE_EN || (!CPU_BUS && !BURSTn));
reg INIT_EN, A2P_CYCLE_EN, P2A_CYCLE_EN, PCI_CYCLE_EN, A2P_TIMEOUT, TS_EN;
reg A2P_BURST_CYCLE, P2A_BURST_CYCLE, RETRY_RESET;
reg [3:0] PCI_CYCLE_STATE;
always @(negedge CLK33 or posedge P2A_RST) begin
    if (P2A_RST) begin
        INIT_EN         <= 0;
        TS_EN           <= 0;
        BUFFER_EN       <= 0;
        A2P_READ_NEXT   <= 0;
        A2P_CYCLE_EN    <= 0;
        P2A_CYCLE_EN    <= 0;
        PCI_CYCLE_EN    <= 0;
        A2P_TIMEOUT     <= 0;
        A2P_BURST_CYCLE <= 0;
        P2A_BURST_CYCLE <= 0;
        RETRY_CYCLE     <= 0;
        RETRY_RESET <= 0;
        PCI_CYCLE_STATE <= 4'h0;
    end else begin

        A2P_READ_NEXT <= 0;

        case (PCI_CYCLE_STATE)
            4'h0: begin
                RETRY_CYCLE <= 0;
                if (!PCI_TIPn) begin
                    PCI_CYCLE_EN    <= 1;
                    BUFFER_EN       <= 1; //Also holds BRIDGE_ENn asserted.
                    INIT_EN         <= CPU_BUS;
                    PCI_CYCLE_STATE <= 4'h1;
                end
            end
            4'h1: begin
                //TRDY_COMPLETE is a stop gap for lack of handshaking with SDRAM during P2A DMA cycles.
                //Get rid of this when we have this handshaking.
                if (CPU_BUS || (A2P_SYNC[1] || TRDY_COMPLETE)) begin
                    A2P_CYCLE_EN    <=  A2P_SYNC[1];
                    P2A_CYCLE_EN    <= ~A2P_SYNC[1];
                    A2P_BURST_CYCLE <= ( A2P_SYNC[1] && BURST_CYCLE_EN);
                    P2A_BURST_CYCLE <= (!A2P_SYNC[1] && BURST_CYCLE_EN);
                    PCI_CYCLE_STATE <= 4'h2;
                    TS_EN <= !CPU_BUS;
                end
            end
            4'h2: begin
                //P2A cycles stop here.
                //A2P cycles continue on.
                PCI_CYCLE_EN <= 0;
                if (PCI_CYCLE_RETRY || (A2P_CYCLE_EN && (PCI_CYCLE_TRDY || CYCLE_TIMEOUT))) begin
                    A2P_READ_NEXT   <= (A2P_CYCLE_EN && !PCI_CYCLE_RETRY); //Do not increment pointer for retry cycles.
                    INIT_EN         <= 0;
                    TS_EN           <= 0;
                    A2P_TIMEOUT     <= CYCLE_TIMEOUT;                    
                    RETRY_CYCLE     <= PCI_CYCLE_RETRY;
                    RETRY_RESET     <= PCI_CYCLE_RETRY;
                    PCI_CYCLE_STATE <= 4'h3;
                end
            end
            4'h3: begin
                if (RETRY_CYCLE || A2P_TIMEOUT || !A2P_BURST_CYCLE) begin
                    A2P_CYCLE_EN    <= 0;
                    BUFFER_EN       <= 0;
                    A2P_TIMEOUT     <= 0;
                    RETRY_RESET     <= 0;
                    PCI_CYCLE_STATE <= 4'h0;
                end else if (PCI_CYCLE_TRDY) begin //Word 2
                    A2P_READ_NEXT   <= 1;
                    PCI_CYCLE_STATE <= 4'h4;
                end
            end
            4'h4: begin
                if (PCI_CYCLE_TRDY) begin //Word 3
                    A2P_READ_NEXT   <= 1;
                    PCI_CYCLE_STATE <= 4'h5;
                end
            end
            4'h5: begin
                if (PCI_CYCLE_TRDY) begin //Word 4
                    A2P_READ_NEXT   <= 1;
                    PCI_CYCLE_STATE <= 4'h6;
                end
            end
            4'h6: begin
                A2P_CYCLE_EN    <= 0;
                BUFFER_EN       <= 0;
                PCI_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

///////////////////////////////////////
// PCI TO AMIGA (P2A) STATE MACHINE //
/////////////////////////////////////

//CPU read or DMA write.

//Push data to the Amiga bus on the 40MHz clock.
reg P2A_CYCLE_RST, PREV_CLK40, READ_NEXT_COUNT;
reg [1:0] P2A_CYCLE_SYNC, PCI_TIPn_SYNC, RETRY_CYCLE_SYNC;
reg [3:0] P2A_CYCLE_STATE;
always @(negedge CLK80) begin
    if (!RESETn) begin

        PREV_CLK40      <= 0;
        TCI_ENn         <= 1;
        P2A_READ_NEXT   <= 0;
        P2A_CYCLE_RST   <= 0;
        READ_NEXT_COUNT <= 0;
        P2A_TIMEOUT     <= 0;

        RETRY_CYCLE_SYNC <= 2'b0;
        P2A_CYCLE_SYNC   <= 2'b0;
        PCI_TIPn_SYNC    <= 2'b0;
        P2A_CYCLE_STATE  <= 4'h0;

    end else begin
        //------ Sync with 33MHz domain ------
        PCI_TIPn_SYNC <= {PCI_TIPn_SYNC[0], PCI_TIPn};
        RETRY_CYCLE_SYNC <= {RETRY_CYCLE_SYNC[0], RETRY_CYCLE};

        //Get the 40MHz clock state. Capture this on the falling edge.
        PREV_CLK40 <= CLK40;

        //------ PCI to Amiga state machine ------
        case (P2A_CYCLE_STATE)
            4'h0 : begin
                if (P2A_CYCLE_SYNC[1] || P2A_CYCLE_SYNC[0]) begin
                    TCI_ENn <= 0;
                    P2A_TIMEOUT <= 0;
                    P2A_CYCLE_STATE <= 4'h1;
                end else begin
                    P2A_CYCLE_SYNC <= {P2A_CYCLE_SYNC[0], P2A_CYCLE_EN};
                    P2A_CYCLE_RST <= 0;
                    P2A_READ_NEXT <= 0;
                end
            end
            4'h1 : begin
                if (RETRY_CYCLE_SYNC[1] || ((CPU_TACK0 || DMA_TRDY0) && !P2A_BURST_CYCLE)) begin
                    P2A_CYCLE_STATE <= 4'h8;
                end else if (CPU_TACK0 || DMA_TRDY0) begin
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h2;
                end else if (PCI_TIPn_SYNC[1] || PCI_TIPn_SYNC[0]) begin
                    P2A_TIMEOUT <= 1;
                end
            end
            4'h2 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h3;
            end
            4'h3 : begin
                if (CPU_TACK1 || DMA_TRDY1) begin //Word 2
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h4;
                end else begin
                    READ_NEXT_COUNT <= 1;                 
                    P2A_READ_NEXT <= !READ_NEXT_COUNT;
                end
            end
            4'h4 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h5;
            end
            4'h5 : begin
                if (CPU_TACK2 || DMA_TRDY2) begin //Word 3
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h6;
                end else begin
                    READ_NEXT_COUNT <= 1;
                    P2A_READ_NEXT <= !READ_NEXT_COUNT;
                end
            end
            4'h6 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h7;
            end
            4'h7 : begin
                if (CPU_TACK3 || DMA_TRDY3) begin //Word 4
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h8;
                end else begin
                    READ_NEXT_COUNT <= 1;
                    P2A_READ_NEXT <= !READ_NEXT_COUNT;
                end
            end
            4'h8 : begin
                TCI_ENn <= 1;
                P2A_READ_NEXT <= (!P2A_TIMEOUT && !RETRY_CYCLE_SYNC[1]);
                P2A_CYCLE_SYNC <= 2'b0;
                P2A_CYCLE_STATE <= 4'h9;
            end
            4'h9 : begin
                P2A_TIMEOUT <= 0;
                P2A_CYCLE_RST <= 1;
                P2A_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

//////////////////////////////////
// DMA AMIGA BUS STATE MACHINE //
////////////////////////////////

//During DMA cycles, we need to assert _TS to start the cycle
//on the AmigaPCI bus.

//reg TS_OUT_EN;
reg TS_OUT_EN;
reg [1:0] TS_EN_SYNC, TS_STATE;
always @(posedge CLK80) begin
    if (!RESETn) begin
        TS_OUT_EN  <= 0;
        TS_EN_SYNC <= 2'b0;
        TS_STATE   <= 2'b0;
    end else begin
        TS_EN_SYNC <= {TS_EN_SYNC[0], TS_EN};
        case (TS_STATE)
            2'd0 : begin
                if (TS_EN_SYNC != 2'b0) begin
                    TS_OUT_EN <= 1;
                    TS_STATE <= 2'd1;
                end
            end
            2'd1 : begin
                TS_STATE <= 2'd2;
            end
            2'd2 : begin
                TS_OUT_EN <= 0;
                TS_STATE <= 2'd3;
            end
            2'd3 : begin
                if (TS_EN_SYNC == 2'b0) begin
                    TS_STATE <= 2'd0;
                end
            end
        endcase
    end
end

////////////////////////////
// DMA CYCLE TERMINATION //
//////////////////////////

//------ Count _TACK assertions ------
//During A2P DMA cycles, we capture the number of times _TACK was
//asserted by the AmigaPCI bus in the 40MHz domain.
//These are the responding target devices. This value is then
//synchronized into the 33MHz domain to driver assertion of _TRDY.
//In the event of an P2A DMA cycle, we enable all TRDY assertions
//simultaneously. This will allow us to assert _TRDY either 1 or 4
//times, based on whether this is a burst cycle. This will fill the FIFO.

wire DMA_TACK_RST = (!RESETn || TRDY_RST || P2A_CYCLE_RST);
reg [1:0] TACK_POINTER;
reg [3:0] DMA_TACK_COUNT;
always @(posedge CLK40, posedge DMA_TACK_RST) begin
    if (DMA_TACK_RST) begin
        TACK_POINTER   <= 2'b0;
        DMA_TACK_COUNT <= 4'h0;
    end else begin
        if (!CPU_BUS) begin
            if (P2A_CYCLE_EN) begin
                DMA_TACK_COUNT <= 4'b1111;
            end else if (!TACKn) begin
                TACK_POINTER <= TACK_POINTER + 1;
                case (TACK_POINTER)
                    2'd0 : DMA_TACK_COUNT[0] <= 1;
                    2'd1 : DMA_TACK_COUNT[1] <= 1;
                    2'd2 : DMA_TACK_COUNT[2] <= 1;
                    2'd3 : DMA_TACK_COUNT[3] <= 1;
                endcase
            end
        end else begin
            DMA_TACK_COUNT <= 4'h0;
        end
    end
end

//------ Assert TRDY on PCI bus ------
//During DMA cycles to the AmigaPCI, we need to assert
//_TRDY on the PCI bus once we have driven data for read
//cycles or latched data for write cycles.

//For DMA write cycles, we count the number of
//_TRDY assertions so we know when we can start the Amiga side
//of the cycle. PCI can insert waits at any time. Since we can't
//predict when those waits will happen, we need to wait for all
//expected assertions of _TRDY before we can start the Amiga side of the
//cycle. For bursts, this is a very slow and temporary solution. 
//A handshaking signal needs to be added. Once a handshaking signal
//is added, we should be able to drop the TRDY_COMPLETE wire.

wire DMA_TRDY0 = (INIT_READY_DELAY && (TACK_COUNT_SYNC[4] || TACK_COUNT_SYNC[0]));
wire DMA_TRDY1 = (INIT_READY_DELAY && (TACK_COUNT_SYNC[5] || TACK_COUNT_SYNC[1]));
wire DMA_TRDY2 = (INIT_READY_DELAY && (TACK_COUNT_SYNC[6] || TACK_COUNT_SYNC[2]));
wire DMA_TRDY3 = (INIT_READY_DELAY && (TACK_COUNT_SYNC[7] || TACK_COUNT_SYNC[3]));

reg TRDY_EN, TRDY_RST, STOP_EN, TRDY_COMPLETE;
reg [3:0] TRDY_STATE;
reg [7:0] TACK_COUNT_SYNC;
always @(posedge CLK66) begin
    if (!RESETn) begin
        TRDY_EN         <= 0;
        TRDY_RST        <= 0;
        TRDY_COMPLETE   <= 0;
        TACK_COUNT_SYNC <= 8'h0;
        TRDY_STATE      <= 4'h0;
    end else begin

        if (TRDY_RST) begin
            TACK_COUNT_SYNC <= 8'h0;
        end else begin
            TACK_COUNT_SYNC <= {TACK_COUNT_SYNC[3:0], DMA_TACK_COUNT};
        end

        case (TRDY_STATE)
            4'h0: begin
                TRDY_COMPLETE <= 0;
                if (DMA_TRDY0 && PREV_CLK33) begin //First word.
                    TRDY_EN <= 1;
                    STOP_EN <= BURSTn;
                    TRDY_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                if (!BURSTn) begin
                    TRDY_STATE <= 4'h2;
                end else begin
                    TRDY_STATE <= 4'h8;
                end
            end
            4'h2: begin
                if (DMA_TRDY1 && PREV_CLK33) begin //Second word.
                    TRDY_EN <= 1;
                    TRDY_STATE <= 4'h3;
                end else begin
                    TRDY_EN <= 0;
                end
            end
            4'h3 : begin
                TRDY_STATE <= 4'h4;
            end
            4'h4: begin
                if (DMA_TRDY2 && PREV_CLK33) begin //Third word.
                    TRDY_EN <= 1;
                    TRDY_STATE <= 4'h5;
                end else begin
                    TRDY_EN <= 0;
                end
            end
            4'h5 : begin
                TRDY_STATE <= 4'h6;
            end
            4'h6: begin
                if (DMA_TRDY3 && PREV_CLK33) begin //Fourth word.
                    TRDY_EN <= 1;
                    STOP_EN <= 1;
                    TRDY_STATE <= 4'h7;
                end else begin
                    TRDY_EN <= 0;
                end
            end
            4'h7 : begin
                TRDY_STATE <= 4'h8;
            end
            4'h8 : begin
                TRDY_EN <= 0;
                STOP_EN <= 0;
                //TRDY_RST <= 1;
                TRDY_RST <= A2P_CYCLE_EN; //Only reset during A2P cycles! P2A cycles have a different reset condition.
                TRDY_COMPLETE <= 1;
                TRDY_STATE <= 4'h9;
            end
            4'h9 : begin
                TRDY_RST <= 0;
                TRDY_STATE <= 4'h0;
            end
        endcase
    end
end

////////////////////////////
// P2A CYCLE TERMINATION //
//////////////////////////

//------ Count _TRDY assertions ------
//We capture the number of target ready assertions in the 
//33MHz domain. It should never exceed 4.

//For CPU read cycles, This value is then 
//synchrnonized into the 80MHz domain for assertion of _TACK.
//The target ready count is asynchronously reset from the 80MHz
//domain once each data transfer has been terminated.

wire CPU_TRDY_RST = (!RESETn || TACK_RST);
reg PCI_CYCLE_END;
reg [1:0] TRDY_POINTER;
reg [3:0] CPU_TRDY_COUNT;
always @(posedge CLK33 or posedge CPU_TRDY_RST) begin
    if (CPU_TRDY_RST) begin
        PCI_CYCLE_END <= 1;
        CPU_TRDY_COUNT <= 4'h0;
        TRDY_POINTER <= 2'd0;
    end else begin
        if (A2P_TIMEOUT) begin
            CPU_TRDY_COUNT <= 4'b1111;
        end else begin
            if (CPU_BUS && !TARGET_READYn) begin
                TRDY_POINTER <= TRDY_POINTER + 1;
                case (TRDY_POINTER)
                    2'h0 : CPU_TRDY_COUNT[0] <= 1;
                    2'h1 : CPU_TRDY_COUNT[1] <= 1;
                    2'h2 : begin CPU_TRDY_COUNT[2] <= 1; PCI_CYCLE_END <= 1; end
                    2'h3 : CPU_TRDY_COUNT[3] <= 1;
                endcase
            end else begin
                PCI_CYCLE_END <= 0;
            end
        end
    end
end

//------ Transfer Burst Inhibit (_TBI) ------
//We have very little time to recognize assertion of _STOP
//and pass it to the CPU. We are being fast and loose
//with clock domain crossing, but we have little choice. The
//risk of metastability should be low due to _STOP asserting
//BEFORE we assert _TACK. We can just get in under the wire.

/*wire TBI_SET = (!STOPn && !BURSTn);
assign TBIn = TBI_EN ? TBI_OUT : 1'bz;

reg TBI_EN, TBI_OUT, STOP_CYCLE;
always @(posedge CLK80 or posedge TBI_SET) begin
    if (TBI_SET) begin
        TBI_EN <= 1;
        TBI_OUT <= 0;
        STOP_CYCLE <= 1;
    end else if (!RESETn) begin
        TBI_EN <= 0;
        TBI_OUT <= 1;
        STOP_CYCLE <= 0;
    end else begin
        if (!TBI_OUT) begin
            STOP_CYCLE <= 0;
            TBI_OUT <= 1;
        end else begin
            TBI_EN <= 0;
        end
    end
end*/

//------ CPU cycle termination (_TACK) ------
//CPU cycles can be terminated either by normal assertion of _TRDY by
//the PCI device or by timeout where no PCI device claims the bus.

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;
//assign TBIn  = (TACK_EN && !BURST_CYCLE) ? TACK_OUT : 1'bz;
assign TBIn  = (TACK_EN && !P2A_BURST_CYCLE) ? TACK_OUT : 1'bz;

wire CPU_TACK0 = (TRDY_COUNT_SYNC[4] || TRDY_COUNT_SYNC[0] || P2A_TIMEOUT);
wire CPU_TACK1 = (TRDY_COUNT_SYNC[5] || TRDY_COUNT_SYNC[1] || P2A_TIMEOUT);
wire CPU_TACK2 = (TRDY_COUNT_SYNC[6] || TRDY_COUNT_SYNC[2] || P2A_TIMEOUT);
wire CPU_TACK3 = (TRDY_COUNT_SYNC[7] || TRDY_COUNT_SYNC[3] || P2A_TIMEOUT);

reg TACK_EN, TACK_OUT, TACK_RST;
reg [3:0] TACK_STATE;
reg [7:0] TRDY_COUNT_SYNC;
always @(posedge CLK80) begin
    if (!RESETn) begin
        TACK_EN  <= 0;
        TACK_OUT <= 1;
        TACK_RST <= 0;
        TRDY_COUNT_SYNC <= 8'h0;
        TACK_STATE      <= 4'h0;
    end else begin

        if (TACK_RST) begin
            TRDY_COUNT_SYNC <= 8'h0;
        end else begin
            TRDY_COUNT_SYNC <= {TRDY_COUNT_SYNC[3:0], CPU_TRDY_COUNT};
        end

        case (TACK_STATE)
            4'h0 : begin
                if ((CPU_TACK0) && !PREV_CLK40) begin //First word
                    TACK_EN <= 1;
                    TACK_OUT <= 0;
                    TACK_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                if (!P2A_BURST_CYCLE && !A2P_BURST_CYCLE) begin
                    TACK_STATE <= 4'h8;
                end else begin
                    TACK_STATE <= 4'h2;
                end
            end
            4'h2 : begin
                if ((CPU_TACK1) && !PREV_CLK40) begin //Second word
                    TACK_OUT <= 0;
                    TACK_STATE <= 4'h3;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h3 : begin
                TACK_STATE <= 4'h4;
            end
            4'h4 : begin
                if ((CPU_TACK2) && !PREV_CLK40) begin //Third word
                    TACK_OUT <= 0;
                    TACK_STATE <= 4'h5;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h5 : begin
                TACK_STATE <= 4'h6;
            end
            4'h6 : begin
                if ((CPU_TACK3) && !PREV_CLK40) begin //Fourth word
                    TACK_OUT <= 0;
                    TACK_STATE <= 4'h7;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h7 : begin
                TACK_STATE <= 4'h8;
            end
            4'h8 : begin
                TACK_OUT <= 1;
                TACK_RST <= 1;
                TACK_STATE <= 4'h9;
            end
            4'h9 : begin
                TACK_EN <= 0;
                TACK_RST <= 0;
                TACK_STATE <= 4'h0;
            end
        endcase
    end
end

endmodule
