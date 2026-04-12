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

Engineer: Jason Neus
Design Name: U110
Module Name: U110_CYCLE_TERMINATION
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Terminate ATA and PCI data transfers.

Date          Who  Description
-----------------------------------
02-JUL-2025   JN   Initial release for Rev 6.0 hardware.
16-OCT-2025   JN   Changed to rising clock edge to better accomodate latency in the FPGA.
17-NOV-2025   JN   Added PCI TACK.
24-NOV-2025   JN   Added cycle timeouts on the PCI bus.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U110_CYCLE_TERMINATION (

    //Clocks
    input CLK40,
    
    //Cycle Start/Terminate
    input RESETn, ATA_TACK, PCI_CYCLEn,
    output TCIn, TBIn, //TEAn, 

    inout TACKn

);

  ///////////////////////
 // CYCLE TERMINATION //
///////////////////////

//Terminate cycles for PCI and ATA access. We don't allow caching in either PCI or ATA spaces.

//_TCI is asserted with every cycle termination driven by U110, which is only ATA cycles.
//_TCI is also asserted in response to a PCI cycle in progress. For that process,
//_TCI is enabled by watching for assertion of _PCICYCLE from U109. Once _TCI is asserted,
//assertion of _TACK disables it. During normal PCI cycle terminations, U109 drives _TACK and _TBI
//while we assert TCIn here, in U110.

wire TCI_EN  =  (TACK_OUT_EN ||  PCI_TCI_EN);
wire TxI_OUT = !(!TACK_OUT   || !PCI_TCI_OUT);

assign TACKn = TACK_OUT_EN ? TACK_OUT : 1'bz;
assign TCIn  = TCI_EN ? TxI_OUT : 1'bz;
assign TBIn = TACK_OUT_EN ? TACK_OUT : 1'bz;
//assign TEAn  = 1;

//------ _TACK State Machine ------
reg TACK_OUT_EN, TACK_OUT;
reg [3:0] TACK_COUNT;
always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_OUT_EN <= 0;
        TACK_OUT <= 1;
        TACK_COUNT <= 4'h0;
    end else begin
        case (TACK_COUNT)
            4'h0 : begin
                if (ATA_TACK) begin
                    TACK_OUT_EN <= 1;
                    TACK_OUT <= 0;
                    TACK_COUNT <= 4'h1;
                end
            end
            4'h1 : begin
                TACK_OUT <= 1;
                TACK_COUNT <= 4'h2;
            end
            4'h2 : begin
                TACK_OUT_EN <= 0;
                TACK_COUNT <= 4'h0;
            end
        endcase
    end
end

//------ _TCI State Machine ------
reg PCI_TCI_EN, PCI_TCI_OUT;
reg [1:0] TCI_STATE, TCI_CYCLE_EN;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_TCI_EN <= 0;
        PCI_TCI_OUT <= 1;
        TCI_CYCLE_EN <= 2'b0;
        TCI_STATE <= 2'b0;
    end else begin
        case (TCI_STATE)
            2'b00 : begin
                if (TCI_CYCLE_EN != 2'b00) begin
                    PCI_TCI_EN <= 1;
                    PCI_TCI_OUT <= 0;
                    TCI_STATE <= 2'b01;
                end else begin
                    TCI_CYCLE_EN <= {TCI_CYCLE_EN[0], ~PCI_CYCLEn};
                end
            end
            2'b01 : begin
                if (!TACKn) begin
                    PCI_TCI_OUT <= 1;
                    TCI_CYCLE_EN <= 2'b0;
                    TCI_STATE <= 2'b10;
                end
            end
            2'b10 : begin
                PCI_TCI_EN <= 0;
                TCI_STATE <= 2'b00;
            end
        endcase
    end    
end

endmodule

