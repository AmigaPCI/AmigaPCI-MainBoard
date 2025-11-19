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

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U110_CYCLE_TERMINATION (

    //Clcoks
    input CLK40, 
    
    //Cycle Start/Terminate
    input RESETn, ATA_TACK, PCI_TACK_ENn,
    output TEAn, TACKn, TCIn, TBIn,

    //Condition Signals
    input ATA_ENn

);

  ///////////////////////
 // CYCLE TERMINATION //
///////////////////////

//Terminate cycles for PCI and ATA access. We don't allow caching in either PCI or ATA spaces.

assign TACKn = TACK_OUT_EN ? TACK_OUT : 1'bz;
assign TCIn  = TACK_OUT_EN ? TACK_OUT : 1'bz;
//assign TBIn  = TACK_OUT_EN && !ATA_ENn ? TACK_OUT : 1'bz;
assign TBIn  = TACK_OUT_EN ? TACK_OUT : 1'bz;
assign TEAn  = 1;

reg TACK_OUT_EN;
reg TACK_OUT;
reg [3:0] TACK_COUNT;

always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_OUT_EN <= 0;
        TACK_OUT <= 1;
        TACK_COUNT <= 4'h0;
    end else begin
        case (TACK_COUNT)
            4'h0 : begin
                if (ATA_TACK || !PCI_TACK_ENn) begin
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

endmodule
