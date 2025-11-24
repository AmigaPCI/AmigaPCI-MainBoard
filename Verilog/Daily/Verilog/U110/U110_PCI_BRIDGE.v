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

iceprog D:\AmigaPCI\U110\APCI_U110\APCI_U110_Implmnt\sbt\outputs\bitmap\U110_TOP_bitmap.bin
*/

module U110_PCI_BRIDGE (

    input CLK40, CLK33, RESETn, TSn, RnW,
    input BGn, PCI_CYCLEn, DEVSELn, UUBEn, UMBEn, LMBEn, LLBEn, BURSTn, BRIDGE_ENn, 
    input [1:0] PCIAT,

    output FRAMEn,
    output reg PHASEA_D, PCI_TIPn,
    output [3:0] CBE

);

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

localparam [3:0] TIMEOUT = 4'h3;
localparam [1:0] BURST_TOTAL = 2'b11;

  /////////////////
 // CYCLE START //
/////////////////

reg PCI_CYCLE_START_HOLD;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_CYCLE_START_HOLD <= 0;
    end else begin
        if (START_CYCLE_RESET) begin
            PCI_CYCLE_START_HOLD <= 0;
        end else if (!TSn && !BRIDGE_ENn) begin
            PCI_CYCLE_START_HOLD <= 1;
        end
    end
end

  /////////////////////////////
 // PCI CYCLE STATE MACHINE //
/////////////////////////////

//Sampled signals are latched on the rising clock edge.
//Driven signals are asserted on the falling clock edge.
//The signals come out about 2-3ns early, which is probably fine.
//A pll can be used in the next hardware revision to get it exact.

reg DEVSELn_DELAY;
always @(posedge CLK33) begin
    if (!RESETn) begin
        DEVSELn_DELAY <= 1;
    end else begin
        DEVSELn_DELAY <= DEVSELn;
    end
end

// Access Type         PCIAT1   PCIAT0
//-------------------------------------
//PCI Config Space 0     0        0
//PCI Config Space 1     0        1
//PCI Memory Space       1        0
//I/O Space              1        1

wire CONF_ACCESS = ((PCIAT == CONFIG0_ACCESS) || (PCIAT == CONFIG1_ACCESS));

wire [3:0] CBE_CMD = ((PCIAT == MEMORY_ACCESS) &&  RnW) ? RD_MEM :
                     ((PCIAT == MEMORY_ACCESS) && !RnW) ? WR_MEM :
                     ((CONF_ACCESS) &&  RnW) ? RD_CON :
                     ((CONF_ACCESS) && !RnW) ? WR_CON : 
                     ((PCIAT == IO_ACCESS) &&  RnW) ? RD_IO : WR_IO;

assign FRAMEn = !BGn ? FRAME_OUTn : 1'bz;
assign CBE = !BGn ? CBE_OUT : 4'bz;

reg FRAME_OUTn, BURST_CYCLE, START_CYCLE_RESET;
reg [3:0] CBE_OUT, CYCLE_STATE, TIMEOUT_COUNT;

always @(negedge CLK33) begin
    if (!RESETn) begin
        PHASEA_D <= 1;
        PCI_TIPn <= 1;
        FRAME_OUTn <= 1;
        BURST_CYCLE <= 0;
        START_CYCLE_RESET <= 0;
        CBE_OUT <= 4'hf;
        TIMEOUT_COUNT <= 4'h0;
        CYCLE_STATE <= 4'h0;
    end else begin
        case (CYCLE_STATE)
            4'h0 : begin
                if (PCI_CYCLE_START_HOLD) begin
                    PCI_TIPn <= 0;
                    FRAME_OUTn <= 0;
                    CBE_OUT <= CBE_CMD;
                    BURST_CYCLE <= !(BURSTn);
                    START_CYCLE_RESET <= 1;
                    CYCLE_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                PHASEA_D <= 0;
                CBE_OUT <= RnW ? 4'h0 : {LLBEn, LMBEn, UMBEn, UUBEn};
                FRAME_OUTn <= !(BURST_CYCLE);
                CYCLE_STATE <= 4'h2;
            end
            4'h2 : begin
                START_CYCLE_RESET <= 0;
                if (!DEVSELn_DELAY) begin
                    CYCLE_STATE <= 4'h3;
                end else begin
                    //Timeout if the device takes too long to respond.
                    TIMEOUT_COUNT <= TIMEOUT_COUNT + 1;
                    if (TIMEOUT_COUNT == TIMEOUT) begin
                        PCI_TIPn <= 1;
                        FRAME_OUTn <= 1;
                        PHASEA_D <= 1;
                        CYCLE_STATE <= 4'h0;
                    end
                end
            end
            4'h3 : begin
                if (PCI_CYCLEn) begin
                    FRAME_OUTn <= 1;
                end                
                if (DEVSELn_DELAY) begin
                    PCI_TIPn <= 1;
                    PHASEA_D <= 1;
                    CYCLE_STATE <= 4'h0;
                end
            end
        endcase
    end    
end

endmodule