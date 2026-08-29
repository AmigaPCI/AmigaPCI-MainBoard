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
NonCommercial — You may not use the material for commercial purposes.
No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

Engineer: Jason Neus
Design Name: U110
Module Name: U110_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: U110 AMIGA PCI FPGA - PCI finiate state machine.

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

Date          Who  Description
-----------------------------------
29-NOV-2025   JN   Initial code.
05-DEC-2025   JN   Assert _TACK for write to PCI cycles.
10-JAN-2026   JN   Added DMA state machine.
15-FEB-2025   JN   Drop BURST when _FRAME negates after one clock.
*/

module U110_PCI_BRIDGE (

    input CLK66, CLK40, CLK33, RESETn, TSn, RnW,
    input AD31, BGn, PCI_CYCLEn, UUBEn, UMBEn, LMBEn, LLBEn, BRIDGE_ENn, PARITY_DA, IRDYn,
    input CPU_BUS_OWN,
    

    output PARITY, BB_EN, DMA_START, PPDMA, PCI_BUFF_ENn, W_LATCH_ENn,
    output reg DMA_WRITE_CYCLE, LATCH_ADn, PCI_TIPn, 
    output [1:0] A_LOW,
    output reg [1:0] SIZ_OUT,

    input [2:0] PCIAT,
    inout DEVSELn, FRAMEn,
    inout [3:0] CBE

    //,output TP0,TP1,TP2
    //,output TP1

);

//assign TP0 = PCI_CYCLE_ACTIVE;
//assign TP1 = DMA_PCI_CYCLE;
//assign TP2 = BURST_CYCLE;

  ////////////////
 // PARAMETERS //
////////////////

//PCIAT Cycle Types
localparam CONFIG0_ACCESS = 3'b000;
localparam CONFIG1_ACCESS = 3'b001;
localparam MEMORY_ACCESS  = 3'b010;
localparam IO_ACCESS      = 3'b011;
localparam CACHE_ACCESS   = 3'b100;
localparam RETRY_ACCESS   = 3'b111;

//PCI Bus Commands
localparam RD_IO    = 4'b0010;
localparam WR_IO    = 4'b0011;
localparam RD_MEM   = 4'b0110;
localparam WR_MEM   = 4'b0111;
localparam RD_CON   = 4'b1010;
localparam WR_CON   = 4'b1011;
localparam RD_CACHE = 4'b1110;
localparam WR_CACHE = 4'b1111;

localparam [3:0] TIMEOUT = 4'h2;
localparam [1:0] BURST_TOTAL = 2'b11;

  ///////////
 // WIRES //
///////////

assign BB_EN         =   BB_EN_SYNC[1];
//assign PCI_TIPn      = ~(PCI_CYCLE_ACTIVE || DMA_PCI_CYCLE);
assign DMA_START     =  (RESETn && !FRAMEn && !AD31);
assign PCI2PCI_START =  (RESETn && !FRAMEn &&  AD31);

always @(posedge CLK33) begin
    if (!RESETn) begin
        PCI_TIPn <= 1'b1;
    end else begin
        PCI_TIPn <= ~(PCI_CYCLE_ACTIVE || DMA_PCI_CYCLE);
    end
end

//PPDMA controls the direction of the _DEVSEL and _TRDY signals.
//The direction is conditioned on the cycle type in progress.

//Cycle Type   Data Direction  Value
//----------------------------------
// CPU to PCI  Bridge <- PCI     1
// DMA to Ami  Bridge -> PCI     0
// DMA to PCI  Bridge <- PCI     1

//assign PPDMA = (PCI_BUFF_ENn || PCI_CYCLE_ACTIVE);
assign PPDMA = ~PCI_BUFF_ENn; //PCI_BUF_ENn = 1 when PCI <-> PCI DMA cycle.

  //////////////////
 // TRISTATE I/O //
//////////////////

assign PARITY = PARITY_EN ? PARITY_OUT : 1'bz;

//Drive when the CPU has the bus.
//Listen when PCI has the bus.
assign CBE    = CPU_BUS_OWN ? CBE_OUT    : 4'bz;
assign FRAMEn = CPU_BUS_OWN ? FRAME_OUTn : 1'bz;

//Drive when PCI has the bus.
//Listen when CPU has the bus.
assign DEVSELn = !CPU_BUS_OWN ? ~DEVSEL_EN  : 1'bz;
assign A_LOW   = !CPU_BUS_OWN ? A_LOW_OUT   : 2'bz;

  ///////////////////
 // SYNCHRONIZERS //
///////////////////

//------ 33MHz Domain ------
reg [1:0] BURSTn_SYNC, WRITE_CYCLE_SYNC;
reg [1:0] PCI_CYCLE_START_SYNC, BGn_SYNC;
always @(posedge CLK66) begin
    if (!RESETn) begin
        BURSTn_SYNC <= 2'b0;
        WRITE_CYCLE_SYNC <= 2'b0;
        BGn_SYNC <= 2'b0;
        PCI_CYCLE_START_SYNC <= 4'h0;
    end else begin
        PCI_CYCLE_START_SYNC <= {PCI_CYCLE_START_SYNC[0], PCI_CYCLE_START_HOLD};
        WRITE_CYCLE_SYNC <= {WRITE_CYCLE_SYNC[0], WRITE_CYCLE};
        BURSTn_SYNC <= {BURSTn_SYNC[0], BURST_CYCLE_EN};
        BGn_SYNC <= {BGn_SYNC[0], BGn};
    end
end

//------ 40MHz Domain ------
reg [1:0] BB_EN_SYNC;
always @(negedge CLK40) begin
    if (!RESETn) begin
        BB_EN_SYNC <= 2'b0;
    end else begin
        BB_EN_SYNC <= {BB_EN_SYNC[0], PCI_BB_EN};
    end
end

  /////////////////////
 // CPU CYCLE START //
/////////////////////

//All CPU driven PCI cycles start here by watching for assertion of _TS
//while in the bridge address space. When a new cycle start is detected,
//the PCI (33MHz) state machine is signaled to start. This state machine
//then returns to an idle state.

//This currently DOES NOT support burst writes to PCI.
//Future idea...drive _TACK from here instead of asserting W_LATCH_EN?

wire CPU_PCI_CYCLE_START = (!TSn && !BRIDGE_ENn && CPU_BUS_OWN);

reg PCI_CYCLE_START_HOLD, WRITE_CYCLE, BURST_CYCLE_EN, WRITE_LATCH_EN;
reg [1:0] PCI_CYCLE_ACTIVE_SYNC;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_CYCLE_START_HOLD <= 1'b0;
        WRITE_CYCLE <= 1'b0;
        WRITE_LATCH_EN <= 1'b0;
        BURST_CYCLE_EN <= 1'b0;
        PCI_CYCLE_ACTIVE_SYNC <= 2'b00;
    end else begin

        WRITE_LATCH_EN <= 1'b0;

        if (PCI_CYCLE_START_HOLD) begin
            if (PCI_CYCLE_ACTIVE_SYNC != 2'b00) begin
                PCI_CYCLE_START_HOLD <= 1'b0;
                BURST_CYCLE_EN <= 1'b0;
                PCI_CYCLE_ACTIVE_SYNC <= 2'b00;
            end else begin
                //Wait for the 33MHz state machine to start before returning to idle state.
                PCI_CYCLE_ACTIVE_SYNC <= {PCI_CYCLE_ACTIVE_SYNC[0], PCI_CYCLE_ACTIVE};
            end
        end else begin
            //Start the CPU driven PCI cycle.
            if (CPU_PCI_CYCLE_START) begin
                PCI_CYCLE_START_HOLD <= 1'b1;
                BURST_CYCLE_EN <= PCIAT[2];           
                if (!RnW) begin
                    WRITE_LATCH_EN <= 1'b1;
                    WRITE_CYCLE <= 1'b1;
                end else begin
                    WRITE_CYCLE <= 1'b0;
                end
            end
        end
    end
end

  //////////////////////
 // FIFO WRITE LATCH //
//////////////////////

//Signal the FIFO in U109 to latch data on an A2P cycle.
//This state machine gets it on the correct edge.

assign W_LATCH_ENn = ~(WRITE_LATCH);

reg WRITE_LATCH;
always @(negedge CLK40) begin
    if (!RESETn) begin
        WRITE_LATCH <= 1'b0;
    end else begin
        WRITE_LATCH <= WRITE_LATCH_EN;
    end
end

  /////////////////
 // CBE COMMAND //
/////////////////

//Latch the CBE command here.

// Access Type         PCIAT2   PCIAT1   PCIAT0
//---------------------------------------------
//PCI Config Space 0     0        0        0
//PCI Config Space 1     0        0        1
//PCI Memory Space       0        1        0
//I/O Space              0        1        1
//Cache Space            1        0        0
//Reserved               1        0        1
//Reserved               1        1        0
//Retry                  1        1        1

reg RETRY_CYCLE;
reg [3:0] CBE_CMD;
always @* begin
    
    //Defaults
    CBE_CMD = WRITE_CYCLE ? WR_CON : RD_CON;
    RETRY_CYCLE <= 0;
    
    case (PCIAT)
        MEMORY_ACCESS: begin
            CBE_CMD = WRITE_CYCLE ? WR_MEM : RD_MEM;
        end

        CACHE_ACCESS: begin
            CBE_CMD = WRITE_CYCLE ? WR_CACHE : RD_CACHE;
        end

        IO_ACCESS: begin
            CBE_CMD = WRITE_CYCLE ? WR_IO : RD_IO;
        end

        RETRY_ACCESS : begin
            RETRY_CYCLE <= 1;
        end

        //default: begin
        //    CBE_CMD = WRITE_CYCLE ? WR_CON : RD_CON;
        //end
    endcase
end

  //////////////////////////
 // CPU DRIVEN PCI CYCLE //
//////////////////////////

//Sampled signals are latched on the rising clock edge.
//Driven signals are asserted on the falling clock edge.
//The signals come out about 2-3ns early, which is probably fine.
//A pll can be used in the next hardware revision to get it exact.

//------ RISING SIGNAL LATCH ------
reg DEVSELn_DELAY, PCI_CYCLEn_DELAY;
always @(posedge CLK33) begin
    if (!RESETn) begin
        DEVSELn_DELAY <= 1;
        PCI_CYCLEn_DELAY <= 1;
    end else begin
        DEVSELn_DELAY <= DEVSELn;
        PCI_CYCLEn_DELAY <= PCI_CYCLEn;
    end
end

//------ FALLING EDGE DRIVERS ------
wire WRITE_CYCLE_START = (WRITE_CYCLE_SYNC[1] || WRITE_CYCLE_SYNC[0]);

reg FRAME_OUTn, BURST_CYCLE, PCI_WRITE_CYCLE, PHASEA_D, PCI_CYCLE_ACTIVE, RETRY_EN;
reg [3:0] CBE_OUT, CYCLE_STATE, TIMEOUT_COUNT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PHASEA_D         <= 1;
        PCI_CYCLE_ACTIVE <= 0;
        FRAME_OUTn       <= 1;
        BURST_CYCLE      <= 0;
        RETRY_EN         <= 0;
        CBE_OUT          <= 4'hf;
        TIMEOUT_COUNT    <= 4'h0;
        CYCLE_STATE      <= 4'h0;
    end else begin
        case (CYCLE_STATE)
            4'h0 : begin
                if ((PCI_CYCLE_START_SYNC[1] || PCI_CYCLE_START_SYNC[0]) || RETRY_EN) begin
                    PCI_CYCLE_ACTIVE <= 1;
                    FRAME_OUTn <= 0;
                    CBE_OUT <= CBE_CMD;
                    BURST_CYCLE <= (BURSTn_SYNC[1] || BURSTn_SYNC[0]);
                    PCI_WRITE_CYCLE <= WRITE_CYCLE_START;
                    TIMEOUT_COUNT <= 4'h0;
                    CYCLE_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                PHASEA_D <= 0;
                RETRY_EN <= 0;
                CBE_OUT <= !PCI_WRITE_CYCLE ? 4'h0 : {LLBEn, LMBEn, UMBEn, UUBEn};
                FRAME_OUTn <= !(BURST_CYCLE);
                //RETRY_RESET <= 1;
                CYCLE_STATE <= 4'h2;
            end
            4'h2 : begin
                TIMEOUT_COUNT <= TIMEOUT_COUNT + 1;
                //RETRY_RESET <= 0;
                if (!DEVSELn_DELAY) begin
                    CYCLE_STATE <= 4'h3;
                end else if (TIMEOUT_COUNT == TIMEOUT) begin
                    PCI_CYCLE_ACTIVE <= 0;
                    FRAME_OUTn <= 1;
                    PHASEA_D <= 1;
                    CYCLE_STATE <= 4'h0;
                end
            end
            4'h3 : begin
                //if (RETRY_CYCLE || PCI_CYCLEn || DEVSELn_DELAY) begin //The cycle is done.
                if (RETRY_CYCLE || PCI_CYCLEn_DELAY || DEVSELn_DELAY) begin //The cycle is done.
                    PCI_CYCLE_ACTIVE <= 0;
                    FRAME_OUTn <= 1;
                    PHASEA_D <= 1;
                    RETRY_EN <= RETRY_CYCLE;
                    CYCLE_STATE <= RETRY_CYCLE ? 4'h4 : 4'h0;
                end
            end
            4'h4 : begin
                if (!RETRY_CYCLE) begin                    
                    CYCLE_STATE <= 4'h5;
                end
            end
            4'h5 : begin                
                CYCLE_STATE <= 4'h0;
            end
        endcase
    end    
end

  //////////////////////////
 // PCI DRIVEN DMA CYCLE //
//////////////////////////

//For PCI driven (DMA) cycles, we support four bus commands:
//Memory Read and Write, Memory Read Line, and Memory Write and Invalidate.
//Other bus commands may cause the state machine to fail.
//In the event the PCI device drives a cache line cycle, but only holds
//_FRAME for one clock, we revert to a non-burst cycle on the APCI.

//------ Sample Signals from PCI Bus ------
reg DMA_BURST_CYCLE, DMA_CYCLE_ACTIVE, PCI_BB_EN;
reg [1:0] A_LOW_OUT;
reg [2:0] DMA_STATE;
always @(posedge CLK33) begin
    if (!RESETn) begin
        //DEVSEL_EN <= 0;
        LATCH_ADn        <= 0;
        PCI_BB_EN        <= 0;
        DMA_CYCLE_ACTIVE <= 0;
        DMA_BURST_CYCLE  <= 0;
        DMA_WRITE_CYCLE  <= 0;
        SIZ_OUT   <= 2'b0;
        A_LOW_OUT <= 2'b0;
        DMA_STATE <= 3'd0;
    end else begin
        case (DMA_STATE)
            3'd0 : begin
                if (DMA_START && BGn_SYNC[1]) begin
                    //DMA cycle has started
                    //NEED TO DRIVE TT BUS FROM HERE!
                    PCI_BB_EN        <= 1;
                    LATCH_ADn        <= 1;
                    DMA_CYCLE_ACTIVE <= 1;                    
                    DMA_WRITE_CYCLE  <= CBE[0]; //1=Write
                    DMA_BURST_CYCLE  <= CBE[3]; //1=Burst
                    DMA_STATE        <= 2'd1;
                end
            end
            3'd1 : begin
                //DEVSEL_EN <= 1;
                LATCH_ADn        <= 0;
                DMA_CYCLE_ACTIVE <= 0;
                DMA_STATE        <= 2'd2;
                case (CBE)
                    //Byte Lanes
                    4'b0000 : begin
                        SIZ_OUT <= (DMA_BURST_CYCLE && !FRAMEn) ? 2'b11 : 2'b00;
                        A_LOW_OUT <= 2'b00;
                    end
                    4'b0011 : begin
                        SIZ_OUT <= 2'b10;
                        A_LOW_OUT <= 2'b10;
                    end
                    4'b1100 : begin
                        SIZ_OUT <= 2'b10;
                        A_LOW_OUT <= 2'b00;
                    end
                    default : begin
                        SIZ_OUT <= 2'b01;
                        A_LOW_OUT[1] <= (!CBE[2] || !CBE[3]);
                        A_LOW_OUT[0] <= (!CBE[1] || !CBE[3]);
                        //1110 = A_LOW_OUT <= 2'b00;                        
                        //1101 = A_LOW_OUT <= 2'b01;                       
                        //1011 = A_LOW_OUT <= 2'b10;
                        //0111 = A_LOW_OUT <= 2'b11;
                    end
                endcase
            end
            3'd2 : begin
                if (!PCI_CYCLEn) begin
                    DMA_STATE <= 3'd3;
                end
            end
            3'd3 : begin
                //DEVSEL_EN <= 0;
                if (PCI_CYCLEn) begin
                    PCI_BB_EN <= 0;
                    DMA_STATE <= 2'd0;
                end
            end
        endcase
    end
end

//WE NEED ANOTHER SIGNAL TO DRIVE NEGATION OF _DEVSEL.
//WE NEED TO DROP DEVSEL ON THE SAME EDGE THE LAST
//_TRDY IS NEGATED.
//This is in REV 7.0, _PCIEN is the signal name.

//------ Drive PCI DMA signals on falling edge ------
reg DMA_PCI_CYCLE, DEVSEL_EN;
reg [1:0] DMA_SIGNAL_STATE;
always @(negedge CLK33) begin
    if (!RESETn) begin
        DEVSEL_EN <= 0;
        DMA_PCI_CYCLE <= 0;
        DMA_SIGNAL_STATE <= 2'd0;
    end else begin
        case (DMA_SIGNAL_STATE)
            2'd0 : begin
                if (DMA_CYCLE_ACTIVE) begin
                    DMA_PCI_CYCLE <= 1; //Asert PCI_TIPn
                    DMA_SIGNAL_STATE <= 2'd1;
                end
            end
            2'd1 : begin
                DEVSEL_EN <= 1; //Assert DEVSELn
                DMA_SIGNAL_STATE <= 2'd2;
            end
            2'd2 : begin
                if (!PCI_CYCLEn_DELAY) begin //Wait for U109 to ack cycle.
                    DMA_SIGNAL_STATE <= 2'd3;
                end
            end
            2'd3 : begin
                if (PCI_CYCLEn_DELAY) begin //Cycle is over.
                    DMA_PCI_CYCLE <= 0;
                    DEVSEL_EN <= 0;
                    DMA_SIGNAL_STATE <= 2'd0;
                end
            end
        endcase
    end
end

  //////////////////////////
 // PCI DRIVEN PCI CYCLE //
//////////////////////////

//In the event of a PCI to PCI DMA cycle, we basically sit it out by
//disabling the AD buffers. We need to monitor the bus to know when 
//this cycle type starts and ends.

assign PCI_BUFF_ENn = 1'b0;

/*always @(posedge CLK33) begin
    if (!RESETn) begin
        PCI_BUFF_ENn <= 0;
    end else begin
        if (!PCI_BUFF_ENn) begin
            if (PCI2PCI_START) begin
                PCI_BUFF_ENn <= 1;
            end
        end else if (DEVSELn && IRDYn) begin
            PCI_BUFF_ENn <= 0;
        end
    end
end*/
    
  ////////////
 // PARITY //
////////////

//We only assert PARITY one cycle after we drive the bus.

//Parity Direction
//0 = PCI to FPGA
//1 = FPGA to PCI

//    ADDRESS PHASE   DATA PHASE
//      CPU  DMA      CPU     DMA
//    --------------------------
// RD    1    0       0 (P2A) 1 (A2P)
// WR    1    0       1 (A2P) 0 (P2A)

//Only drive parity where the table above is true.

//------ Calculate the parity. ------
reg PARITY_CBE, PARITY_EN;;
always @(posedge CLK33) begin
    if (!RESETn) begin
        PARITY_CBE <= 0;
        PARITY_EN  <= 0;
    end else begin
        PARITY_CBE <= ^{CBE_OUT};
        PARITY_EN <= CPU_BUS_OWN ? (PHASEA_D || !RnW) : RnW;//((CPU_BUS_OWN && (PHASEA_D == ADDRESS_PHASE || !RnW)) || (!CPU_BUS_OWN && RnW));
    end    
end

//------ Assert Parity ------
reg PARITY_OUT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PARITY_OUT <= 1;
    end else begin
        PARITY_OUT <= ^{PARITY_CBE, PARITY_DA};
    end    
end

endmodule