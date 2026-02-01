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
*/

module U110_PCI_BRIDGE (

    input CLK66, CLK40, CLK33, RESETn, TSn, RnW,
    input AD31, BGn, PCI_CYCLEn, UUBEn, UMBEn, LMBEn, LLBEn, BRIDGE_ENn, PARITY_DA,
    input CPU_BUS,
    

    output PARITY, PCI_TIPn, BB_EN, DMA_START,
    output reg DMA_WRITE_CYCLE, W_LATCH_EN,
    output [1:0] A_LOW,
    output reg [1:0] SIZ_OUT,

    inout DEVSELn, FRAMEn,
    input [2:0] PCIAT,
    inout [3:0] CBE

    //,output TP0,TP1,TP2
    ,output TP1

);

//assign TP0 = PCI_CYCLE_START_HOLD;
assign TP1 = PCI_TIPn;
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

assign DMA_START = (RESETn && !FRAMEn && !AD31);
assign PCI_TIPn = ~(PCI_CYCLE_ACTIVE || DMA_CYCLE_ACTIVE);
assign BB_EN = BB_EN_SYNC[1];

  /////////////////////
 // TRISTATABLE I/O //
/////////////////////

assign PARITY = PARITY_EN ? PARITY_OUT : 1'bz;

//Drive when the CPU has the bus.
//Listen when PCI has the bus.
assign CBE    = CPU_BUS ? CBE_OUT    : 4'bz;
assign FRAMEn = CPU_BUS ? FRAME_OUTn : 1'bz;

//Drive when PCI has the bus.
//Listen when CPU has the bus.
assign DEVSELn = !CPU_BUS ? DEVSEL_OUT  : 1'bz;
assign A_LOW   = !CPU_BUS ? A_LOW_OUT   : 2'bz;

  ///////////////////
 // MULTIPLEX I/O //
///////////////////

//assign WLATCH_FRAMEn = ~(W_LATCH_EN || !FRAMEn);
//assign WLATCH_FRAMEn = ~(W_LATCH_EN || DMA_START);

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

reg PCI_CYCLE_START_HOLD, WRITE_CYCLE, BURST_CYCLE_EN; //W_LATCH_EN, 
reg [1:0] PCI_CYCLE_ACTIVE_SYNC, PCI_CYCLE_STATE;;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_CYCLE_START_HOLD <= 0;
        WRITE_CYCLE <= 0;
        W_LATCH_EN <= 0;
        BURST_CYCLE_EN <= 0;
        PCI_CYCLE_STATE <= 2'b0;
        PCI_CYCLE_ACTIVE_SYNC <= 2'b0;
    end else begin

        PCI_CYCLE_ACTIVE_SYNC <= {PCI_CYCLE_ACTIVE_SYNC[0], PCI_CYCLE_ACTIVE};

        case (PCI_CYCLE_STATE)
            2'b00 : begin
                if (!TSn && !BRIDGE_ENn) begin
                    PCI_CYCLE_START_HOLD <= 1;
                    BURST_CYCLE_EN <= PCIAT[2];           
                    if (!RnW) begin
                        W_LATCH_EN <= 1;
                        WRITE_CYCLE <= 1;
                    end
                    PCI_CYCLE_STATE <= 2'b01;
                end
            end
            2'b01: begin
                W_LATCH_EN <= 0;
                PCI_CYCLE_STATE <= 2'b10;
            end
            2'b10 : begin
                if (PCI_CYCLE_ACTIVE_SYNC != 2'b0) begin
                    PCI_CYCLE_START_HOLD <= 0;
                    WRITE_CYCLE <= 0;
                    BURST_CYCLE_EN <= 0;
                    PCI_CYCLE_STATE <= 2'b00;
                end
            end
        endcase
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
//Reserved               1        1        1

reg [3:0] CBE_CMD;
always @* begin
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

        default: begin
            CBE_CMD = WRITE_CYCLE ? WR_CON : RD_CON;
        end
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
reg DEVSELn_DELAY;
always @(posedge CLK33) begin
    if (!RESETn) begin
        DEVSELn_DELAY <= 1;
    end else begin
        DEVSELn_DELAY <= DEVSELn;
    end
end

//------ FALLING EDGE DRIVERS ------
wire WRITE_CYCLE_START = (WRITE_CYCLE_SYNC[1] || WRITE_CYCLE_SYNC[0]);

reg FRAME_OUTn, BURST_CYCLE, PCI_WRITE_CYCLE, PHASEA_D, PCI_CYCLE_ACTIVE;
reg [3:0] CBE_OUT, CYCLE_STATE, TIMEOUT_COUNT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PHASEA_D <= 1;
        PCI_CYCLE_ACTIVE <= 0;
        FRAME_OUTn <= 1;
        BURST_CYCLE <= 0;
        CBE_OUT <= 4'hf;
        TIMEOUT_COUNT <= 4'h0;
        CYCLE_STATE <= 4'h0;
    end else begin
        case (CYCLE_STATE)
            4'h0 : begin
                if (PCI_CYCLE_START_SYNC[1] || PCI_CYCLE_START_SYNC[0]) begin
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
                CBE_OUT <= !PCI_WRITE_CYCLE ? 4'h0 : {LLBEn, LMBEn, UMBEn, UUBEn};
                FRAME_OUTn <= !(BURST_CYCLE);
                CYCLE_STATE <= 4'h2;
            end
            4'h2 : begin
                TIMEOUT_COUNT <= TIMEOUT_COUNT + 1;
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
                if (PCI_CYCLEn || DEVSELn_DELAY) begin //The cycle is done.
                    PCI_CYCLE_ACTIVE <= 0;
                    FRAME_OUTn <= 1;
                    PHASEA_D <= 1;
                    CYCLE_STATE <= 4'h0;
                end
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

//------ Sample Signals from PCI Bus ------
reg DEVSEL_EN, DMA_BURST_CYCLE, DMA_CYCLE_ACTIVE, PCI_BB_EN;
reg [1:0] DMA_STATE, A_LOW_OUT;
always @(posedge CLK33) begin
    if (!RESETn) begin
        DEVSEL_EN <= 0;
        DMA_CYCLE_ACTIVE <= 0;
        DMA_BURST_CYCLE <= 0;
        DMA_WRITE_CYCLE <= 0;
        PCI_BB_EN <= 0;
        SIZ_OUT <= 2'b0;
        A_LOW_OUT <= 2'b0;
        DMA_STATE <= 2'd0;
    end else begin
        case (DMA_STATE)
            2'd0 : begin
                //if (!FRAMEn && BGn_SYNC[1] && !AD31) begin
                if (DMA_START && BGn_SYNC[1]) begin
                    //DMA cycle has started
                    //NEED TO DRIVE TT BUS FROM HERE!
                    PCI_BB_EN <= 1;
                    DMA_CYCLE_ACTIVE <= 1;                    
                    DMA_WRITE_CYCLE <= CBE[0]; //1=Write
                    DMA_BURST_CYCLE <= CBE[3]; //1=Burst
                    DMA_STATE <= 2'd1;
                end
            end
            2'd1 : begin
                DEVSEL_EN <= 1;
                DMA_CYCLE_ACTIVE <= 0;
                DMA_STATE <= 2'd2;
                case (CBE)
                    4'b0000 : begin
                        SIZ_OUT <= DMA_BURST_CYCLE ? 2'b11 : 2'b00;
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
            2'd2 : begin
                DEVSEL_EN <= 0;
                if (PCI_CYCLEn) begin
                    PCI_BB_EN <= 0;
                    DMA_STATE <= 2'd0;
                end
            end
        endcase
    end
end

//------ Drive PCI DMA signals on falling edge ------
reg DEVSEL_OUT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        DEVSEL_OUT <= 1;
    end else begin
        if (DEVSEL_EN) begin
            DEVSEL_OUT <= 0;
        end else if (PCI_CYCLEn) begin
            DEVSEL_OUT <= 1;
        end
    end
end

  ////////////
 // PARITY //
////////////

//We only assert PARITY one cycle after we drive the bus.

//------ Calculate the parity. ------
reg PARITY_CBE, PARITY_OUT;
always @(posedge CLK33) begin
    if (!RESETn) begin
        PARITY_CBE <= 1;
    end else begin
        PARITY_CBE <= ^{CBE_OUT};
    end    
end

//------ Assert Parity ------
reg PARITY_EN;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PARITY_EN <= 0;
        PARITY_OUT <= 1;
    end else begin
        if (CPU_BUS && (PHASEA_D || PCI_WRITE_CYCLE)) begin
            PARITY_OUT <= ^{PARITY_CBE, PARITY_DA};
            PARITY_EN <= 1;
        end else begin
            PARITY_EN <= 0;
        end
    end    
end

endmodule