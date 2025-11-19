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

module U110_PCI_SM (

    input CLK40, CLK33, RESETn, RnW, TSn, DEVSELn, DEVSELn, TRDYn, BURST, BPRO_ENn,
    input PCI_TIPn, UUBEn, UMBEn, LMBEn, LLBEn,
    input [1:0] PCIAT,
    input [1:0] A,

    output PCI_STARTn,
    output [1:0] AD,
    output [3:0] CBE

);

  ////////////////
 // PARAMETERS //
////////////////

//PCIAT Cycle Types
localparam CON0_ACCESS = 2'b00;
localparam CON1_ACCESS = 2'b01;
localparam MEM_ACCESS  = 2'b10;
localparam IO_ACCESS   = 2'b11;

//Burst Order
localparam LINEAR = 2'b00;
localparam WRAP   = 2'b10;

//PCI State Machine States
localparam IDLE = 2'b00;
localparam DATA = 2'b01;
localparam WAIT = 2'b10;

//PCI Bus Commands
localparam RD_IO  = 4'b0010;
localparam WR_IO  = 4'b0011;
localparam RD_MEM = 4'b0110;
localparam WR_MEM = 4'b0111;
localparam RD_CON = 4'b1010;
localparam WR_CON = 4'b1011;

  ////////////
 // AD BUS //
////////////

//We drive the AD bus bits 1 and 0 during the address phase as dictated by the cycle type.
//During the data phase, we hi-z.

assign AD = PHASEA_D ? AD_OUT : 2'bz;

  ///////////////////////////
 // PCI CLOCK EDGE DETECT //
///////////////////////////

//Using the CLK66 falling edge, we can detect the phase of CLK33.

/*localparam LO_PHASE = 0;
localparam HI_PHASE = 1;

reg PCI_CLK_D1;
reg PCI_CLK_D2;

always @(negedge CLK66) begin
    PCI_CLK_PHASE <= CLK33 ? HI_PHASE : LO_PHASE;
end*/

  /////////////////
 // CYCLE START //
/////////////////

//Catch the start of a new prometheus data transfer cycle.
//We are only detecting prometheus cycles for now. Add non-prometheus cycles later.

reg CYCLE_START;
always @(posedge CLK40) begin
    if (!RESETn) begin
        CYCLE_START <= 0;
    end else begin
        CYCLE_START <= ((!TSn && !BPRO_ENn) || (CYCLE_START && PCI_STARTn));
    end
end

//THE PCI STATE MACHINE IS SPLIT BETWEEN U110 AND U109.
//U110 IDENTIFIES THE START OF A PCI CYCLE. WHEN A DEVICE ON THE
//PCI BUS RESPONDS, THE CYCLE IS TURNED OVER TO U109 TO COMPLETE THE
//DATA PORTION OF THE CYCLE.

reg BURST_CYCLE;
reg [1:0] PCI_STATE;
reg [1:0] AD_OUT;

always @(negedge CLK33) begin
    if (!RESETn) begin
        FRAMEn <= 1;
        CBE <= RD_MEM;
        PCI_STATE <= IDLE;
        PCI_STARTn <= 1;
        AD_OUT <= 2'b0;
        BURST_CYCLE <= 0;
        PCI_STARTn <= 1;
    end else begin
        case (PCI_STATE)
            IDLE : begin
                if (CYCLE_START) begin
                    FRAMEn     <= 0;
                    PCI_STARTn <= 0;
                    PCI_STATE  <= DATA;
                    BURST_CYCLE = BURST;
                    case (PCIAT)
                        MEM_ACCESS : begin
                            CBE <= RnW ? RD_MEM : WR_MEM;
                            AD_OUT <= WRAP;
                        end
                        IO_ACCESS  : begin
                            CBE <= RnW ? RD_IO  : WR_IO;
                            AD_OUT <= A;
                        end
                        default    : begin
                            CBE <= RnW ? RD_CON : WR_CON;
                            AD_OUT <= PCIAT;
                        end
                    endcase
                end
            end
            DATA : begin
                CBE <= RnW ? 4'b0000 : {LLBEn, LMBEn, UMBEn, UUBEn};
                FRAMEn <= !(BURST_CYCLE); //Negate _FRAME now for non-burst cycles.
                if (!PCI_TIPn) begin //Wait for U109 to signal it has started the data portion of the cycle.
                    PCI_STATE <= WAIT;
                    PCI_STARTn <= 1;
                end
            end
            WAIT : begin
                FRAMEn <= PCI_TIPn || FRAMEn; //Negate _FRAME when U109 negates _PCI-TIP.
                if (PHASEA_D) begin //U109 says the PCI cycle is complete.
                    PCI_STATE <= IDLE;
                end
            end
        endcase
    end
end

endmodule
