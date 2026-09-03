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
Module Name: U109_BUFFERS
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Buffers for the PCI bus interface.

Date          Who  Description
-----------------------------------
18-NOV-2025   JN   INITIAL CODE
21-NOV-2025   JN   Added address decoding for all cycle types.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_BUFFERS
(
    //Clocks
    input CLK40, CLK33, RESETn,

    //Cycle Control Signals
    input RnW, TSn, BURSTn, CPU_BUSn,

    //FIFO Data
    input [31:0] A2P_DATA, P2A_DATA,

    //PCI Signals
    input PCI_TIPn, BRIDGE_SPACE, CACHE_SPACE, DATA_BUFFER_EN, P2A_TIMEOUT, RETRY_CYCLE, //DEVSELn, 
    output ADDRESS_ENn, PCI_BUF_DIR, ADDRESS_DIR,
    output reg PARITY_DA, PCI_WRITE_EN, //CACHE_SPACE_EN, //CLK_ADDRESS_LATCH,
    output [4:0] IDSEL,
    output [2:0] PCIAT,

    //Data In/Out
    inout [31:0] D,
    inout [31:0] AD

    //,output TP0
    //,output TP1
);

//assign TP0 = AD_OUT_EN;
//assign TP1 = D_OUT_EN;
//assign TP1 = ADDRESS_VALID;

/////////////////
// PARAMETERS //
///////////////

//localparam BRIDGE_ADDRESS  = 4'h0;
localparam SLOT0_ADDRESS   = 4'h1;
localparam SLOT1_ADDRESS   = 4'h2;
localparam SLOT4_ADDRESS   = 4'h3;
localparam SLOT2_ADDRESS   = 4'h4;
localparam SLOT3_ADDRESS   = 4'h8;
localparam CONF0_ADD_SPACE = 10'b0111111100; //$9FC
localparam CONF1_ADD_SPACE = 10'b0111111101; //$9FD
localparam IO_ADD_LO_SPACE = 10'b0111111110; //$9FE
localparam IO_ADD_HI_SPACE = 10'b0111111111; //$9FF

localparam BURST_ORDER_WRAP = 2'b10;

localparam CONFIG0_ACCESS   = 3'b000;
localparam CONFIG1_ACCESS   = 3'b001;
localparam MEM_ACCESS       = 3'b010;
localparam IO_ACCESS        = 3'b011;
localparam CACHE_ACCESS     = 3'b100;
localparam RETRY_ACCESS     = 3'b111;

////////////////////
// ADDRESS LATCH //
//////////////////

//The on board address buffers are enabled any time the PCI state machine is idle.
//The direction of the data is determined by who has the bus.

reg CPU_ADDRESS_VALID;
reg [1:0] DATA_BUFFER_EN_SYNC;
reg [2:0] PCIAT_LATCHED;
reg [31:0] A_LATCH;
always @(negedge CLK40) begin
    if (!RESETn) begin
        CPU_ADDRESS_VALID <= 0;
        PCI_WRITE_EN <= 0;
        PCIAT_LATCHED <= MEM_ACCESS;
        //CACHE_SPACE_EN <= 0;
        A_LATCH <= 32'h0;
        DATA_BUFFER_EN_SYNC <= 2'b11;
    end else begin
        DATA_BUFFER_EN_SYNC <= {DATA_BUFFER_EN_SYNC[0], DATA_BUFFER_EN};        
        if (CPU_ADDRESS_VALID) begin
            //if (DATA_BUFFER_EN_SYNC[1]) begin
            if (DATA_BUFFER_EN_SYNC != 2'b00) begin
                CPU_ADDRESS_VALID <= 0;
            end
        end else begin
            if (!CPU_BUSn && !TSn && BRIDGE_SPACE) begin
                A_LATCH <= AD;
                CPU_ADDRESS_VALID <= 1;
                PCI_WRITE_EN <= !(RnW);
                //CACHE_SPACE_EN <= CACHE_SPACE;
                case (AD[29:20])
                    CONF0_ADD_SPACE : PCIAT_LATCHED <= CONFIG0_ACCESS;
                    CONF1_ADD_SPACE : PCIAT_LATCHED <= CONFIG1_ACCESS;
                    IO_ADD_LO_SPACE : PCIAT_LATCHED <= IO_ACCESS;
                    IO_ADD_HI_SPACE : PCIAT_LATCHED <= IO_ACCESS;
                    default         : PCIAT_LATCHED <= (CACHE_SPACE && !BURSTn) ? CACHE_ACCESS : MEM_ACCESS;
                endcase
            end
        end
    end
end

//////////////////////////////////////////
// ENABLE THE ADDRESS FOR RETRY CYCLES //
////////////////////////////////////////

//For retry cycles, the address is already latched.

reg RETRY_ADDRESS_VALID;
always @(posedge CLK33, posedge RETRY_CYCLE) begin
    if (RETRY_CYCLE) begin
        RETRY_ADDRESS_VALID <= 1;
    end else if (!RESETn || DATA_BUFFER_EN) begin
        RETRY_ADDRESS_VALID <= 0;
    end
end

///////////////////////
// ADDRESSING WIRES //
/////////////////////

//--- Memory Spaces ---
wire ADDRESS_VALID = (CPU_ADDRESS_VALID || RETRY_ADDRESS_VALID);
wire CONFIG0_SPACE = (A_LATCH[29:20] == CONF0_ADD_SPACE);
wire CONFIG1_SPACE = (A_LATCH[29:20] == CONF1_ADD_SPACE);
wire IO_SPACE      = (A_LATCH[29:21] == IO_ADD_LO_SPACE[8:1]);
wire MEMORY_SPACE  = (!CONFIG0_SPACE && !CONFIG1_SPACE && !IO_SPACE);

//--- Slot IDSEL ---
wire SLOT4_ENABLE  = (A_LATCH[19:16] == SLOT4_ADDRESS);
wire SLOT3_ENABLE  = (A_LATCH[19:16] == SLOT3_ADDRESS);
wire SLOT2_ENABLE  = (A_LATCH[19:16] == SLOT2_ADDRESS);
wire SLOT1_ENABLE  = (A_LATCH[19:16] == SLOT1_ADDRESS);
wire SLOT0_ENABLE  = (A_LATCH[19:16] == SLOT0_ADDRESS);

assign IDSEL = (ADDRESS_VALID && (CONFIG0_SPACE || CONFIG1_SPACE)) ? {SLOT4_ENABLE, SLOT3_ENABLE, SLOT2_ENABLE, SLOT1_ENABLE, SLOT0_ENABLE} : 5'b00000;

//////////////////////
// ADDRESS BUFFERS //
////////////////////

//The address buffers must be turned on in order to snoop the 
//address and respond to a CPU driven PCI cycle. Once we latch
//the CPU address at the start of the cycle, we turn the buffers off
//to prevent contention on AD. During a DMA cycle, the buffers
//must latch the address from AD during the address phase. This
//presents and holds the address on the Amiga bus until the cycle ends.

//WLATCH_FRAMEn is a duplexed signal. When the CPU has the bus,
//it tells us when to latch data being written from the CPU.
//When PCI has the bus, it tells us when to start a DMA cycle.

wire ADDRESS_DIS = (ADDRESS_VALID || !PCI_TIPn || DATA_BUFFER_EN);
//wire DMA_START = (RESETn && CPU_BUSn && !W_LATCH_FRAMEn);
assign ADDRESS_DIR = CPU_BUSn;
assign ADDRESS_ENn = ~((!CPU_BUSn && !ADDRESS_DIS) || CPU_BUSn);

/*always @(posedge CLK40, posedge DMA_START) begin
    if (DMA_START) begin
        CLK_ADDRESS_LATCH <= 1;
    end else begin
        CLK_ADDRESS_LATCH <= 0;
    end
end*/

//////////////////////
// PCI ACCESS TYPE //
////////////////////

//This bus is used by U110 to interpret the PCI cycle bus command.
//In order to meet the needed setup time, we grab the address early
//and base PCIAT on that until the latched address becomes available.

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

reg [2:0] PCIAT_PRE;
always @* begin
    case (AD[29:20])
        CONF0_ADD_SPACE : PCIAT_PRE <= CONFIG0_ACCESS;
        CONF1_ADD_SPACE : PCIAT_PRE <= CONFIG1_ACCESS;
        IO_ADD_LO_SPACE : PCIAT_PRE <= IO_ACCESS;
        IO_ADD_HI_SPACE : PCIAT_PRE <= IO_ACCESS;
        default         : PCIAT_PRE <= (CACHE_SPACE && !BURSTn) ? CACHE_ACCESS : MEM_ACCESS;
    endcase
end

/*reg [2:0] PCIAT_OUT;
always @* begin
    case (AD[29:20])
        CONF0_ADD_SPACE : PCIAT_OUT <= CONFIG0_ACCESS;
        CONF1_ADD_SPACE : PCIAT_OUT <= CONFIG1_ACCESS;
        IO_ADD_LO_SPACE : PCIAT_OUT <= IO_ACCESS;
        IO_ADD_HI_SPACE : PCIAT_OUT <= IO_ACCESS;
        default         : PCIAT_OUT <= (CACHE_SPACE && !BURSTn) ? CACHE_ACCESS : MEM_ACCESS;
    endcase
end*/

assign PCIAT = RETRY_CYCLE ? RETRY_ACCESS : (ADDRESS_VALID ? PCIAT_LATCHED : PCIAT_PRE);
//assign PCIAT = RETRY_CYCLE ? RETRY_ACCESS : PCIAT_OUT;

///////////////////////
// D/AD BUS BUFFERS //
/////////////////////

//The onboard (FPGA) data bus buffers are enabled during the data phase of a PCI cycle.
//Only enable when a PCI device has identified itself.
//These buffers are byte swapped for data phase transfers.

//Set AD bus to correct output depending on access type and address or data phase.
wire AD_OUT_EN       = ADDRESS_VALID || (DATA_BUFFER_EN && (!CPU_BUSn ^ RnW));
wire [1:0]  A_LOW    = CONFIG0_SPACE ? 2'b00 : CONFIG1_SPACE ? 2'b01 : A_LATCH[1:0]; //Sets AD[1:0]
wire [31:0] AD_A_OUT = MEMORY_SPACE ? {A_LATCH[31:2], BURST_ORDER_WRAP} : {12'h0, A_LATCH[19:2], A_LOW}; //Sets AD[31:0]
wire [31:0] AD_OUT   = !DATA_BUFFER_EN ? AD_A_OUT : {A2P_DATA[7:0], A2P_DATA[15:8], A2P_DATA[23:16], A2P_DATA[31:24]}; //Sets AD source to address or FIFO data.

assign AD = AD_OUT_EN ? AD_OUT : 32'bz;

//Set D bus to correct output from FIFO.
wire D_OUT_EN          = (DATA_BUFFER_EN && (!CPU_BUSn == RnW));
wire [31:0] D_DATA_OUT = P2A_TIMEOUT ? 32'hffffffff : {P2A_DATA[7:0], P2A_DATA[15:8], P2A_DATA[23:16], P2A_DATA[31:24]};

assign D  = D_OUT_EN ? D_DATA_OUT : 32'bz;

/////////////
// PARITY //
///////////

always @(posedge CLK33) begin
    if (!RESETn) begin
        PARITY_DA <= 1'b1;
    end else begin
        PARITY_DA <= ^{AD_OUT};
    end
end

/////////////////////
// AD BUS BUFFERS //
///////////////////

//The level shifting buffers can be enabled for most cycles.
//The only exception is a PCI to PCI DMA cycle, which can 
//be detected by a PCI DMA cycle where _DEVSEL asserts.
//Direction is dictated by who what the bus and cycle type.
//U812, U813, U818, U819.

//The CPU is on the "B" side.
//PCI is on the "A" side.

//               Bus Direction
//      Address Phase     Data Phase
// R/W  CPU     DMA       CPU     DMA
// --------------------------------------
//  R   A<B (0) A>B (1)   A>B (1) A<B (0)
//  W   A<B (0) A>B (1)   A<B (0) A>B (1)

//When !DATA_BUFFER_EN, we are broadcasting the current address to the bus unfiltered.
//When BUFFEN_EN, we are in a CPU driven DMA cycle.
//When there is a PCI to Amiga DMA cycle, we enable these buffers.
//When there is a PCI to PCI DMA cycle, we disable these buffers.

//A PCI to PCI DMA cycle is identified by address bit 31 = 1.
//assign PCI_BUF_ENn = 0;
assign PCI_BUF_DIR = ((CPU_BUSn && !DATA_BUFFER_EN) || (DATA_BUFFER_EN && (!CPU_BUSn == RnW)));

endmodule