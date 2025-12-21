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

    //Clcoks
    input CLK40, //CLK33,
    
    //Cycle Start/Terminate
    input RESETn, ATA_TACK, PCI_TACK_ENn, PCI_TIMEOUT, A2P_TACK_EN,
    output TEAn, TACKn, TCIn, TBIn,
    output reg TACK_OUT

    //Condition Signals
    //input ATA_ENn

);

  ///////////////////////
 // CYCLE TERMINATION //
///////////////////////

//Terminate cycles for PCI and ATA access. We don't allow caching in either PCI or ATA spaces.
//Asserting _TEA alone causes the system to crash.

assign TACKn = TACK_OUT_EN ? TACK_OUT : 1'bz;
//assign TCIn  = (!PCI_TACK_ENn ? 1'b0 : (TACK_OUT_EN ? TACK_OUT : 1'bz));
assign TCIn  = TACK_OUT_EN ? TACK_OUT : !PCI_TACK_ENn ? 1'b0 : 1'bz;
assign TBIn  = TACK_OUT_EN ? TACK_OUT : 1'bz;
assign TEAn = 1;

reg TACK_OUT_EN, TACK_OUT; //, TBI_OUT_EN;
reg [1:0] PCI_TIMEOUT_SYNC;
reg [3:0] TACK_COUNT;

always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_OUT_EN <= 0;
        //TBI_OUT_EN <= 0;
        TACK_OUT <= 1;
        PCI_TIMEOUT_SYNC <= 2'b0;
        TACK_COUNT <= 4'h0;
    end else begin
        case (TACK_COUNT)
            4'h0 : begin
                //if (ATA_TACK || !PCI_TACK_ENn || A2P_TACK_EN || (PCI_TIMEOUT_SYNC[1] || PCI_TIMEOUT_SYNC[0])) begin
                if (ATA_TACK || A2P_TACK_EN || (PCI_TIMEOUT_SYNC[1] || PCI_TIMEOUT_SYNC[0])) begin
                    TACK_OUT_EN <= 1;
                    //TBI_OUT_EN <= (PCI_TACK_ENn); //Assert _TBI for non-PCI cycles.
                    TACK_OUT <= 0;
                    TACK_COUNT <= 4'h1;
                end else begin
                    PCI_TIMEOUT_SYNC <= {PCI_TIMEOUT_SYNC[0], PCI_TIMEOUT};
                end
            end
            4'h1 : begin
                TACK_OUT <= 1;
                TACK_COUNT <= 4'h2;
            end
            4'h2 : begin
                TACK_OUT_EN <= 0;
                //TBI_OUT_EN <= 0;
                PCI_TIMEOUT_SYNC <= 2'b0;
                TACK_COUNT <= 4'h0;
            end
        endcase
    end
end

endmodule

