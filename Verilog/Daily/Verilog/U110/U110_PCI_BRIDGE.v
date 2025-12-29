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
*/

module U110_PCI_BRIDGE (

    input CLK66, CLK40, CLK33, RESETn, TSn, RnW, TACK_OUT,
    input BGn, PCI_CYCLEn, DEVSELn, UUBEn, UMBEn, LMBEn, LLBEn, BURSTn, BRIDGE_ENn, PARITY_DA,
    input [1:0] PCIAT,

    output FRAMEn, PARITY,
    output reg W_LATCH_ENn, PCI_TIPn, // A2P_TACK_EN, PCI_TIMEOUT, 
    output [3:0] CBE

    ,output TP0,TP1,TP2

);

assign TP0 = BURSTn;
assign TP1 = PCI_TIPn;
assign TP2 = PCI_CYCLEn;

  ////////////////
 // PARAMETERS //
////////////////

//PCIAT Cycle Types
localparam CONFIG0_ACCESS = 2'b00;
localparam CONFIG1_ACCESS = 2'b01;
localparam MEMORY_ACCESS  = 2'b10;
localparam IO_ACCESS      = 2'b11;

//PCI Bus Commands
localparam RD_IO  = 4'b0010;
localparam WR_IO  = 4'b0011;
localparam RD_MEM = 4'b0110;
localparam WR_MEM = 4'b0111;
localparam RD_CON = 4'b1010;
localparam WR_CON = 4'b1011;

localparam [3:0] TIMEOUT = 4'h2;
localparam [1:0] BURST_TOTAL = 2'b11;

  /////////////////
 // CYCLE START //
/////////////////

reg PCI_CYCLE_PENDING, PCI_CYCLE_START_HOLD, WRITE_CYCLE, W_LATCH_ENn;
reg [1:0] PCI_TIPn_SYNC, PCI_CYCLE_STATE;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_CYCLE_PENDING <= 0;
        PCI_CYCLE_START_HOLD <= 0;
        WRITE_CYCLE <= 0;
        //A2P_TACK_EN <= 0;
        W_LATCH_ENn <= 1;
        PCI_CYCLE_STATE <= 2'b0;
        PCI_TIPn_SYNC <= 2'b0;
    end else begin

        if (!TSn && !BRIDGE_ENn) begin PCI_CYCLE_PENDING <= 1; end
        PCI_TIPn_SYNC <= {PCI_TIPn_SYNC[0], PCI_TIPn};

        case (PCI_CYCLE_STATE)
            2'b00 : begin
                if (PCI_CYCLE_PENDING || (!TSn && !BRIDGE_ENn)) begin
                    PCI_CYCLE_START_HOLD <= 1;                    
                    if (!RnW) begin
                        W_LATCH_ENn <= 0;
                        WRITE_CYCLE <= 1;
                        //A2P_TACK_EN <= 1;
                    end
                    PCI_CYCLE_STATE <= 2'b01;
                end
            end
            2'b01: begin
                //A2P_TACK_EN <= 0;
                W_LATCH_ENn <= 1;
                PCI_CYCLE_PENDING <= 0;
                PCI_CYCLE_STATE <= 2'b10;
            end
            2'b10 : begin
                if (!PCI_TIPn_SYNC[1]) begin
                    PCI_CYCLE_START_HOLD <= 0;
                    WRITE_CYCLE <= 0;
                    PCI_CYCLE_STATE <= 2'b00;
                end
                /*if (!W_LATCH_ENn) begin
                    if (!TACK_OUT) begin
                        W_LATCH_ENn <= 1;
                    end
                end else if (!PCI_TIPn_SYNC[1]) begin
                    PCI_CYCLE_START_HOLD <= 0;
                    WRITE_CYCLE <= 0;
                    PCI_CYCLE_STATE <= 2'b00;
                end*/
            end
        endcase
    end
end

  /////////////////
 // CBE COMMAND //
/////////////////

//Latch the CBE command here.

// Access Type         PCIAT1   PCIAT0
//-------------------------------------
//PCI Config Space 0     0        0
//PCI Config Space 1     0        1
//PCI Memory Space       1        0
//I/O Space              1        1

reg [3:0] CBE_CMD;
always @* begin
    case (PCIAT)
        MEMORY_ACCESS: begin
            CBE_CMD = WRITE_CYCLE ? WR_MEM : RD_MEM;
        end

        IO_ACCESS: begin
            CBE_CMD = WRITE_CYCLE ? WR_IO : RD_IO;
        end

        default: begin
            CBE_CMD = WRITE_CYCLE ? WR_CON : RD_CON;
        end
    endcase
end

  /////////////////////////////
 // PCI CYCLE STATE MACHINE //
/////////////////////////////

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

//------ SYNCHRONIZER ------
reg [1:0] BURSTn_SYNC, WRITE_CYCLE_SYNC;
//reg [3:0] PCI_CYCLE_START_SYNC;
reg [1:0] PCI_CYCLE_START_SYNC;
always @(posedge CLK66) begin
    if (!RESETn) begin
        PCI_CYCLE_START_SYNC <= 4'h0;
        BURSTn_SYNC <= 2'b0;
        WRITE_CYCLE_SYNC <= 2'b0;
    end else begin
        //PCI_CYCLE_START_SYNC <= {PCI_CYCLE_START_SYNC[2:0], PCI_CYCLE_START_HOLD};
        PCI_CYCLE_START_SYNC <= {PCI_CYCLE_START_SYNC[0], PCI_CYCLE_START_HOLD};
        WRITE_CYCLE_SYNC <= {WRITE_CYCLE_SYNC[0], WRITE_CYCLE};
        BURSTn_SYNC <= {BURSTn_SYNC[0], BURSTn};
    end
end

//------ FALLING EDGE DRIVERS ------
wire WRITE_CYCLE_START = (WRITE_CYCLE_SYNC[1] || WRITE_CYCLE_SYNC[0]);

assign FRAMEn = !BGn ? FRAME_OUTn : 1'bz;
assign CBE = !BGn ? CBE_OUT : 4'bz;

reg FRAME_OUTn, BURST_CYCLE, PCI_WRITE_CYCLE, PHASEA_D;
//reg [1:0] TIMEOUT_STATE;
reg [3:0] CBE_OUT, CYCLE_STATE, TIMEOUT_COUNT;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PHASEA_D <= 1;
        PCI_TIPn <= 1;
        //PCI_TIMEOUT <= 0;
        FRAME_OUTn <= 1;
        BURST_CYCLE <= 0;
        CBE_OUT <= 4'hf;
        //TIMEOUT_STATE <= 2'b0;
        TIMEOUT_COUNT <= 4'h0;
        CYCLE_STATE <= 4'h0;
    end else begin
        case (CYCLE_STATE)
            4'h0 : begin
                if (PCI_CYCLE_START_SYNC[1] || PCI_CYCLE_START_SYNC[0]) begin
                    PCI_TIPn <= 0;
                    FRAME_OUTn <= 0;
                    CBE_OUT <= CBE_CMD;
                    BURST_CYCLE <= (!BURSTn_SYNC[1] || !BURSTn_SYNC[0]);
                    PCI_WRITE_CYCLE <= WRITE_CYCLE_START;
                    //TIMEOUT_STATE <= 2'b0;
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
                    PCI_TIPn <= 1;
                    FRAME_OUTn <= 1;
                    PHASEA_D <= 1;
                    //TIMEOUT_STATE <= 2'b01;
                    CYCLE_STATE <= 4'h0;
                end


                /*case (TIMEOUT_STATE)
                    2'b00 : begin
                        if (!DEVSELn_DELAY) begin
                            CYCLE_STATE <= 4'h3;
                        end else if (TIMEOUT_COUNT == TIMEOUT) begin
                            PCI_TIPn <= 1;
                            FRAME_OUTn <= 1;
                            PHASEA_D <= 1;
                            TIMEOUT_STATE <= 2'b01;
                        end
                    end
                    2'b01 : begin
                        PCI_TIMEOUT <= !(WRITE_CYCLE); //Only assert timeout _TACK for read cycles.
                        TIMEOUT_STATE <= 2'b10;
                    end
                    2'b10 : begin
                        TIMEOUT_STATE <= 2'b11;
                    end
                    2'b11 : begin
                        PCI_TIMEOUT <= 0;
                        CYCLE_STATE <= 4'h0;
                    end
                endcase*/
            end
            4'h3 : begin
                if (PCI_CYCLEn || DEVSELn_DELAY) begin //The cycle is done.
                    PCI_TIPn <= 1;
                    FRAME_OUTn <= 1;
                    PHASEA_D <= 1;
                    CYCLE_STATE <= 4'h0;
                end
            end
        endcase
    end    
end

  ////////////
 // PARITY //
////////////

//We only assert PARITY one cycle after we drive the bus.

//Calculate the parity.
reg PARITY_CBE, PARITY_OUT;
always @(posedge CLK33) begin
    if (!RESETn) begin
        PARITY_CBE <= 1;
    end else begin
        PARITY_CBE <= ^{CBE_OUT};
    end    
end

//Assert Parity
assign PARITY = PARITY_EN ? PARITY_OUT : 1'bz;
reg PARITY_EN;
always @(negedge CLK33) begin
    if (!RESETn) begin
        PARITY_EN <= 0;
        PARITY_OUT <= 1;
    end else begin
        if (!BGn && (PHASEA_D || PCI_WRITE_CYCLE)) begin
            PARITY_OUT <= ^{PARITY_CBE, PARITY_DA};
            PARITY_EN <= 1;
        end else begin
            PARITY_EN <= 0;
        end
    end    
end

endmodule