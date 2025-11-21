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

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_PCI_STATE_MACHINE (

    //Clocks
    input CLK40, CLK33,

    //Cycle Start/Termination
    input RESETn, TSn, RnW, BRIDGE_ENn, BURSTn, BRIDGE_REG_SPACE, DEVSELn,

    //Address/Data
    input [31:0] AD,

    //PCI Signals
    input TARGET_READYn, CONFIG0_SPACE, CONFIG1_SPACE, IO_SPACE,
    output CLK_ADDRESS_LATCH, A_LATCH_VALID,
    output reg PCI_CYCLEn, PHASEA_D, PCI_TACK_EN,
    output reg [1:0] PCIAT,
    output reg [31:0] A_LATCH

);

/////////////////////////
// SYNCHORNIZER INPUT //
///////////////////////

// Access Type         PCIAT1   PCIAT0
//-------------------------------------
//PCI Config Space 0     0        0
//PCI Config Space 1     0        1
//PCI Memory Space       1        0
//I/O Space              1        1

assign A_LATCH_VALID = PCI_CYCLE_START_HOLD;

reg PCI_CYCLE_START_HOLD;
reg [1:0] RESET_START;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_CYCLE_START_HOLD <= 0;
        PCIAT <= 2'b10;
        A_LATCH <= 32'h0;
        RESET_START <= 2'b0;
    end else begin
        RESET_START[0] <= START_CYCLE_RESET;
        RESET_START[1] <= RESET_START[0];

        if (RESET_START[1]) begin
            PCI_CYCLE_START_HOLD <= 0;
        end else if (!TSn && !BRIDGE_ENn && !BRIDGE_REG_SPACE) begin
            PCI_CYCLE_START_HOLD <= 1;
            PCIAT[1] <= (IO_SPACE || (!IO_SPACE && !CONFIG0_SPACE && !CONFIG1_SPACE));
            PCIAT[0] <= (IO_SPACE || CONFIG1_SPACE);
            A_LATCH <= AD;
        end
    end
end

////////////////////////
// PCI STATE MACHINE //
//////////////////////

localparam [3:0] TIMEOUT = 4'h7;

assign CLK_ADDRESS_LATCH = 0;

reg TARGET_READYn_DELAY, DEVSELn_DELAY;
always @(posedge CLK33) begin
    if (!RESETn) begin
        TARGET_READYn_DELAY <= 1;
        DEVSELn_DELAY <= 1;
    end else begin
        TARGET_READYn_DELAY <= TARGET_READYn;
        DEVSELn_DELAY <= DEVSELn;
    end
end

reg CYCLE_BURST_CYCLE, START_CYCLE_RESET;
reg [1:0] PCI_CYCLE_START, BURST_COUNT;
reg [3:0] CYCLE_STATE, TIMEOUT_COUNT;

always @(negedge CLK33) begin
    if (!RESETn) begin
        PCI_CYCLE_START <= 2'b00;
        BURST_COUNT <= 2'b00;
        CYCLE_BURST_CYCLE <= 0;
        PCI_CYCLEn <= 1;
        PHASEA_D <= 1;
        START_CYCLE_RESET <= 0;
        PCI_TACK_EN <= 0;
        CYCLE_STATE <= 4'h0;
    end else begin

        PCI_CYCLE_START[0] <= PCI_CYCLE_START_HOLD;
        PCI_CYCLE_START[1] <= PCI_CYCLE_START[0];

        case (CYCLE_STATE)
            4'h0 : begin
                PCI_TACK_EN <= 0;
                if (PCI_CYCLE_START[1]) begin
                    //DOUBLE CHECK CYCLE TYPE (MEM, CP0, CS1, REGISTER SPACE)
                    PCI_CYCLEn <= 0; //Signal U110 to assert _FRAME.
                    CYCLE_BURST_CYCLE <= !BURSTn;
                    BURST_COUNT <= 2'b0;
                    TIMEOUT_COUNT <= 4'h0;
                    START_CYCLE_RESET <= 1;
                    CYCLE_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                PHASEA_D <= 0; //Signal we are now in the data phase.
                PCI_CYCLEn <= CYCLE_BURST_CYCLE; //Disable _FRAME one clock before cycle ends.
                CYCLE_STATE <= 4'h2;
            end
            4'h2 : begin
                START_CYCLE_RESET <= 0;
                if (!DEVSELn_DELAY) begin
                    //Target device has responded.
                    //_TRDY and _DEVSEL may assert on the same edge!
                    CYCLE_STATE <= 4'h3;
                end else begin
                    //Timeout if the target device takes too long to respond.
                    TIMEOUT_COUNT <= TIMEOUT_COUNT + 1;
                    if (TIMEOUT_COUNT == TIMEOUT) begin
                        PCI_TACK_EN <= 1;
                        PCI_CYCLEn <= 1;
                        PHASEA_D <= 1;
                        CYCLE_STATE <= 4'h0;
                    end
                end
            end
            4'h3 : begin
                if (!TARGET_READYn_DELAY) begin
                    //Target device accepted or asserted data.
                    //Can also check for FIFO not empty to proceed, which is probably better.
                    BURST_COUNT <= BURST_COUNT + 1;
                    if (!CYCLE_BURST_CYCLE || BURST_COUNT == 2'b11) begin
                        PHASEA_D <= 1; //Return to idle state.
                        CYCLE_STATE <= 4'h0;
                    end

                    if (BURST_COUNT == 2'b10) begin
                        PCI_CYCLEn <= 1; //Disable _FRAME one clock before cycle ends.
                    end
                end
            end
        endcase

    end
end

endmodule
