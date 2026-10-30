`timescale 1ns/1ps
//------------------------------------------------------------------------------
// U109 address phase testbench: the bridge address spaces on the AD bus.
//
// A CPU model presents an address with _TS in the bridge space and the bench
// checks what U109_BUFFERS drives on AD during the address phase, the PCIAT
// access type it reports to U110 before and after the latch, and the IDSEL
// lines. One cycle for each space: the legacy window at $9FF (PCI memory
// $00000000-$000FFFFF, upper address bits forced to zero), I/O at $9FE,
// configuration type 0 and 1, the identity mapped memory BAR space and the
// cacheable space with and without a burst. The data phase is modelled only
// far enough to clear the address latch between cycles.
//
// Run: iverilog -g2005 -o tb tb_u109_buffers.v ../U109_BUFFERS.v && vvp -n tb
//------------------------------------------------------------------------------
module tb_u109_buffers;
    reg CLK40 = 0, CLK33 = 0, RESETn = 0;
    reg RnW = 1, TSn = 1, BURSTn = 1, CPU_BUSn = 0;
    reg [31:0] A2P_DATA = 0, P2A_DATA = 0;
    reg PCI_TIPn = 1, BRIDGE_SPACE = 0, CACHE_SPACE = 0, DATA_BUFFER_EN = 0, P2A_TIMEOUT = 0, RETRY_CYCLE = 0;
    wire ADDRESS_ENn, PCI_BUF_DIR, ADDRESS_DIR, PARITY_DA, PCI_WRITE_EN;
    wire [4:0] IDSEL;
    wire [2:0] PCIAT;
    wire [31:0] D, AD;
    reg [31:0] ad_drive = 32'bz;
    assign AD = ad_drive;

    U109_BUFFERS dut(.CLK40(CLK40), .CLK33(CLK33), .RESETn(RESETn), .RnW(RnW), .TSn(TSn), .BURSTn(BURSTn),
        .CPU_BUSn(CPU_BUSn), .A2P_DATA(A2P_DATA), .P2A_DATA(P2A_DATA), .PCI_TIPn(PCI_TIPn),
        .BRIDGE_SPACE(BRIDGE_SPACE), .CACHE_SPACE(CACHE_SPACE), .DATA_BUFFER_EN(DATA_BUFFER_EN),
        .P2A_TIMEOUT(P2A_TIMEOUT), .RETRY_CYCLE(RETRY_CYCLE), .ADDRESS_ENn(ADDRESS_ENn),
        .PCI_BUF_DIR(PCI_BUF_DIR), .ADDRESS_DIR(ADDRESS_DIR), .PARITY_DA(PARITY_DA),
        .PCI_WRITE_EN(PCI_WRITE_EN), .IDSEL(IDSEL), .PCIAT(PCIAT), .D(D), .AD(AD));

    always #12.5 CLK40 = ~CLK40;
    always #15 CLK33 = ~CLK33;

    integer failures = 0;
    task check(input [63:0] name, input [31:0] address, input [31:0] got, input [31:0] want);
        if (got !== want) begin
            failures = failures + 1;
            $display("FAIL %0s %h: got %h want %h", name, address, got, want);
        end
    endtask

    // Present a CPU address with _TS, let the buffers latch it, check the
    // address phase the FPGA drives on AD, then end the cycle.
    task cycle(input [31:0] address, input cache, input burst, input [2:0] want_pciat, input [31:0] want_ad, input [4:0] want_idsel);
        begin
            CACHE_SPACE = cache; BURSTn = !burst;
            BRIDGE_SPACE = (address[31:29] == 3'b100) || (address[31:29] == 3'b101);
            @(posedge CLK40); #1;
            ad_drive = address; TSn = 0;
            #1 check("pre ", address, PCIAT, want_pciat);   // PCIAT_PRE from the AD bus
            @(negedge CLK40); #1;                             // address latched here
            TSn = 1; ad_drive = 32'bz;
            #1;
            check("pciat ", address, PCIAT, want_pciat);
            check("ad ", address, AD, want_ad);
            check("idsel ", address, IDSEL, want_idsel);
            check("aden ", address, ADDRESS_ENn, 1);
            // Data phase: clear the latch and wait for the synchroniser.
            DATA_BUFFER_EN = 1;
            repeat (2) @(negedge CLK40);
            DATA_BUFFER_EN = 0;
            repeat (3) @(negedge CLK40); #1;
            check("idle ", address, AD, 32'bz);
            BRIDGE_SPACE = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge CLK40);
        RESETn = 1;
        repeat (2) @(negedge CLK40);
        //                 address      cache burst PCIAT   AD           IDSEL
        cycle(32'h9FFA0000, 0, 0, 3'b010, 32'h000A0002, 5'b00000); // legacy window: VGA graphics plane
        cycle(32'h9FFB8004, 0, 0, 3'b010, 32'h000B8006, 5'b00000); // legacy window: VGA text
        cycle(32'h9FFC0000, 0, 0, 3'b010, 32'h000C0002, 5'b00000); // legacy window: option ROM shadow
        cycle(32'h9FFFFFFC, 0, 0, 3'b010, 32'h000FFFFE, 5'b00000); // legacy window: last longword
        cycle(32'h9FE003C0, 0, 0, 3'b011, 32'h000003C0, 5'b00000); // I/O stays at $9FE
        cycle(32'h9FE003C1, 0, 0, 3'b011, 32'h000003C1, 5'b00000); // I/O keeps AD[1:0]
        cycle(32'h9FC10000, 0, 0, 3'b000, 32'h00010000, 5'b00001); // config 0, slot 0
        cycle(32'h9FC80004, 0, 0, 3'b000, 32'h00080004, 5'b01000); // config 0, slot 3
        cycle(32'h9FD10100, 0, 0, 3'b001, 32'h00010101, 5'b00001); // config 1 (IDSEL follows A[19:16] as before)
        cycle(32'h80100000, 0, 0, 3'b010, 32'h80100002, 5'b00000); // memory BAR space, identity
        cycle(32'h9FBFFFFC, 0, 0, 3'b010, 32'h9FBFFFFE, 5'b00000); // memory just below the bridge region
        cycle(32'hA0001000, 1, 1, 3'b100, 32'hA0001002, 5'b00000); // cache space burst, identity
        cycle(32'hA0001000, 1, 0, 3'b010, 32'hA0001002, 5'b00000); // cache space single beat
        if (failures) $display("%0d FAILURES", failures); else $display("ALL CHECKS PASSED");
        $finish;
    end
endmodule
