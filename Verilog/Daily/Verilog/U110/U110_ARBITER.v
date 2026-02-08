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
09-JAN-2026   JN   Implement round-robin arbiter.
*/

module U110_ARBITER (

    input CLK40, CLK33, RESETn, BRn, BBn, LOCKn,// CPU_BUS, BB_EN
    input [4:0] BUSREQ,

    output BGn,
    output reg CPU_BUS_OWN,
    output reg [4:0] BUSGNT

    //,output TP0, TP2

);

//assign TP0 = REQ[4];
//assign TP2 = REQ[5];

/////////////////
// PARAMETERS //
///////////////

localparam [3:0] BUS_GRANT_TIMEOUT = 4'hf;

////////////////////
// SYNCHRONIZERS //
//////////////////

//------ CLK33 Domain ------
reg [4:0] BUSGNT_SYNC0, BUSGNT_SYNC1;
always @(posedge CLK33) begin
    if (!RESETn) begin
        BUSGNT_SYNC1 <= 5'b11111;
        BUSGNT_SYNC0 <= 5'b11111;
    end else begin
        BUSGNT_SYNC1 <= BUSGNT_SYNC0;
        BUSGNT_SYNC0 <= BUSGNT_PRE;
    end
end

//------ CLK40 Domain ------
reg [4:0] BUSREQ_SYNC0, BUSREQ_SYNC1;
always @(posedge CLK40) begin
    if (!RESETn) begin
        BUSREQ_SYNC0 <= 5'b11111;
        BUSREQ_SYNC1 <= 5'b11111;
    end else begin
        BUSREQ_SYNC0 <= BUSREQ;
        BUSREQ_SYNC1 <= BUSREQ_SYNC0;
    end
end

//////////////////////////
// ROUND ROBIN ARBITER //
////////////////////////

//Who wants the bus?
wire [5:0] REQ;
assign REQ[0] = ~BUSREQ_SYNC1[0];
assign REQ[1] = ~BUSREQ_SYNC1[1];
assign REQ[2] = ~BUSREQ_SYNC1[2];
assign REQ[3] = ~BUSREQ_SYNC1[3];
assign REQ[4] = ~BUSREQ_SYNC1[4];
assign REQ[5] = ~BRn || (BUSREQ_SYNC1 == 5'b11111);

//Who gets the bus?
reg [2:0] NEXT_GRANT;
always @* begin
    // Default = no grant
    NEXT_GRANT = 3'd7;

    // Round-robin priority check starting from (PTR + 1)
    if      (REQ[(PTR + 3'd1) % 6]) NEXT_GRANT = (PTR + 3'd1) % 6;
    else if (REQ[(PTR + 3'd2) % 6]) NEXT_GRANT = (PTR + 3'd2) % 6;
    else if (REQ[(PTR + 3'd3) % 6]) NEXT_GRANT = (PTR + 3'd3) % 6;
    else if (REQ[(PTR + 3'd4) % 6]) NEXT_GRANT = (PTR + 3'd4) % 6;
    else if (REQ[(PTR + 3'd5) % 6]) NEXT_GRANT = (PTR + 3'd5) % 6;
    else if (REQ[(PTR + 3'd0) % 6]) NEXT_GRANT = (PTR + 3'd0) % 6;
end

////////////////////////////
// ARBITER STATE MACHINE //
//////////////////////////

reg PCI_BUS_GRANT_EN, CPU_BUS_GRANT_EN;
reg [1:0] ARBITER_STATE;
reg [2:0] PTR, CURRENT_OWNER;
reg [3:0] BUS_GRANT_COUNTER;
always @(posedge CLK40) begin
    if (!RESETn) begin
        PCI_BUS_GRANT_EN <= 0;
        CPU_BUS_GRANT_EN <= 0;
        CPU_BUS_OWN <= 1;
        PTR <= 3'd0;
        CURRENT_OWNER <= 3'd7;
        ARBITER_STATE <= 2'h0;
        BUS_GRANT_COUNTER <= 4'h0;
    end else begin
        case (ARBITER_STATE)
            2'h0: begin
                if (CURRENT_OWNER != NEXT_GRANT) begin
                    BUS_GRANT_COUNTER <= 4'h0;
                    CURRENT_OWNER <= NEXT_GRANT;
                    if (NEXT_GRANT != 3'd7) begin
                        PTR <= NEXT_GRANT;
                    end
                    ARBITER_STATE <= 4'h1;
                    CPU_BUS_GRANT_EN <= 0;
                    PCI_BUS_GRANT_EN <= 0;
                end
            end
            2'h1 : begin
                if (BBn) begin
                    ARBITER_STATE <= 4'h2;
                end
            end
            2'h2 : begin
                if (BBn) begin
                    //Once we know the CPU is off the bus, we can give it to PCI.
                    if (CURRENT_OWNER == 3'd5) begin
                        CPU_BUS_GRANT_EN <= 1;
                        CPU_BUS_OWN <= 1;
                    end else begin
                        PCI_BUS_GRANT_EN <= 1;
                        CPU_BUS_OWN <= 0;
                    end
                    ARBITER_STATE <= 4'h3;                    
                end else begin
                    //CPU took the bus back. Need to wait longer.
                    //If this is a lock cycle, you must assert _BG and wait!
                    ARBITER_STATE <= 4'h1;
                end
            end
            2'h3: begin
                if (!BBn || BUS_GRANT_COUNTER == BUS_GRANT_TIMEOUT) begin
                    //A new device took the bus or the bus grant action timed out.
                    ARBITER_STATE <= 4'h0;
                end else begin
                    BUS_GRANT_COUNTER <= BUS_GRANT_COUNTER + 1;
                end
            end
        endcase
    end
end

////////////////
// BUS GRANT //
//////////////

/*A somewhat dangerous situation exists when the processor begins a locked transfer after 
the bus has been granted to the alternate bus master, causing the alternate bus master to 
perform a bus transfer during a locked sequence. To correct this situation, the external 
bus arbiter must be able to recognize the possible indeterminate condition and reassert 
BG to the processor when the processor begins a locked sequence.  pp7-48 of MC68040 user manual*/

//------ Pre-grant ------
reg [4:0] BUSGNT_PRE;
reg BG_PRE;
always @* begin
    BUSGNT_PRE = 5'b11111;
    BG_PRE = 0;
    if (CURRENT_OWNER < 3'd5) begin
        BUSGNT_PRE[CURRENT_OWNER] = 1'b0;
    end else if (CURRENT_OWNER == 3'd5) begin
        BG_PRE = 1;
    end
end

//------ Drive _BG for CPU ------
assign BGn = ~(BG_EN || !LOCKn);
reg BG_EN;
always @(posedge CLK40) begin
    if (!RESETn) begin
        BG_EN <= 0;
    end else begin
        BG_EN <= (BG_PRE && CPU_BUS_GRANT_EN);
    end
end

//------ Drive BUSGNT for PCI ------
always @(negedge CLK33) begin
    if (!RESETn) begin
        BUSGNT <= 5'b11111;
    end else begin
        if (PCI_BUS_GRANT_EN) begin
            BUSGNT <= BUSGNT_SYNC1;
        end else begin
            BUSGNT <= 5'b11111;
        end
    end
end

endmodule
