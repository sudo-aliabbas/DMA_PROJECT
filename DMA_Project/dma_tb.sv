// ============================================================================
// File: tb_dma_axi_complete.sv
// Description: DMA + AXI4 complete testbench (fixed for Questa)
// ============================================================================

`timescale 1ns/1ps

module tb_dma_axi_complete;
    import dma_pkg::*;

    // =========================================================================
    // Clock and Reset
    // =========================================================================
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;     // 100 MHz clock
    end

    // =========================================================================
    // CPU Register Interface
    // =========================================================================
    logic        reg_write;
    logic        reg_read;
    logic [3:0]  reg_addr;
    logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;

    // =========================================================================
    // AXI4 Signals
    // =========================================================================
    logic [3:0]  m_axi_arid;
    logic [31:0] m_axi_araddr;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic        m_axi_arvalid;
    logic        m_axi_arready;

    logic [3:0]  m_axi_rid;
    logic [31:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rlast;
    logic        m_axi_rvalid;
    logic        m_axi_rready;

    logic [3:0]  m_axi_awid;
    logic [31:0] m_axi_awaddr;
    logic [7:0]  m_axi_awlen;
    logic [2:0]  m_axi_awsize;
    logic [1:0]  m_axi_awburst;
    logic        m_axi_awvalid;
    logic        m_axi_awready;

    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wlast;
    logic        m_axi_wvalid;
    logic        m_axi_wready;

    logic [3:0]  m_axi_bid;
    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;

    logic interrupt;

    // Counters
    int errors = 0;
    int pass_count = 0;
    int test_number = 0;

    // =========================================================================
    // DUT
    // =========================================================================
    dma_controller_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),

        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),

        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),

        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),

        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),

        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),

        .interrupt(interrupt)
    );

    // =========================================================================
    // AXI Slave Memory
    // =========================================================================
    axi_slave_mem #(
        .ADDR_WIDTH(16),
        .MEM_BYTES(65536)
    ) memory (
        .aclk(clk),
        .aresetn(rst_n),

        .s_axi_arid(m_axi_arid),
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arlen(m_axi_arlen),
        .s_axi_arsize(m_axi_arsize),
        .s_axi_arburst(m_axi_arburst),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),

        .s_axi_rid(m_axi_rid),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rlast(m_axi_rlast),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready),

        .s_axi_awid(m_axi_awid),
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awlen(m_axi_awlen),
        .s_axi_awsize(m_axi_awsize),
        .s_axi_awburst(m_axi_awburst),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),

        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wlast(m_axi_wlast),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),

        .s_axi_bid(m_axi_bid),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready)
    );

    // =========================================================================
    // Register Access Tasks
    // =========================================================================
    task automatic write_reg(input [3:0] addr, input [31:0] data);
        @(posedge clk);
        reg_write = 1;
        reg_addr  = addr;
        reg_wdata = data;
        @(posedge clk);
        reg_write = 0;
    endtask

    task automatic read_reg(input [3:0] addr, output [31:0] data);
        @(posedge clk);
        reg_read = 1;
        reg_addr = addr;
        @(posedge clk);
        data = reg_rdata;
        reg_read = 0;
    endtask

    // =========================================================================
    // Wait for DMA completion
    // =========================================================================
    task automatic wait_for_done(input int timeout_cycles = 20000);
        int cycle_count = 0;
        logic [31:0] status;

        // Wait for BUSY to clear
        do begin
            read_reg(REG_STATUS, status);
            @(posedge clk);
            cycle_count++;

            if (cycle_count > timeout_cycles) begin
                $display("  ERROR: DMA TIMEOUT");
                errors++;
                return;
            end
        end while (status[STAT_BUSY]);

        // Read status again AFTER busy clears
        read_reg(REG_STATUS, status);
        @(posedge clk);

        // Check the fresh status
        if (status[STAT_DONE]) begin
            $display("  Transfer completed in %0d cycles", cycle_count);
            pass_count++;
        end else if (status[STAT_ERROR]) begin
            $display("  ERROR: STAT_ERROR bit set!");
            errors++;
        end else begin
            $display("  ERROR: Unexpected status=0x%02h", status);
            errors++;
        end
    endtask

    // =========================================================================
    // Clear interrupt status for next test
    // =========================================================================
    task automatic clear_interrupts();
        logic [31:0] int_status;
        read_reg(REG_INT_STATUS, int_status);
        if (int_status != 0) begin
            write_reg(REG_INT_STATUS, int_status);  // W1C - clear by writing 1s
        end
    endtask

    // =========================================================================
    // Initialize memory
    // =========================================================================
    task automatic initialize_memory(input logic [31:0] addr,
                                     input int words,
                                     input logic [31:0] pattern);
        int idx;
        for (int i = 0; i < words; i++) begin
            idx = (addr >> 2) + i;
            memory.mem[idx] = pattern + i;
        end
    endtask

    // =========================================================================
    // Verify memory
    // =========================================================================
    task automatic verify_memory(input logic [31:0] src,
                                 input logic [31:0] dst,
                                 input int words);
        int mism = 0;
        logic [31:0] s, d;

        for (int i = 0; i < words; i++) begin
            s = memory.mem[(src >> 2) + i];
            d = memory.mem[(dst >> 2) + i];
            if (s !== d) begin
                $display("  MISMATCH word %0d: src=%h dst=%h", i, s, d);
                mism++;
            end
        end

        if (mism == 0) begin
            $display("  PASS: All %0d words verified correctly", words);
            pass_count++;
        end else begin
            $display("  FAIL: %0d mismatches found", mism);
            errors += mism;
        end
    endtask

    // =========================================================================
    // TEST 1: Simple Burst (16 words)
    // =========================================================================
    task automatic test_simple_burst();
        $display("\n========================================");
        $display("TEST 1: SIMPLE BURST (16 words)");
        $display("========================================");
        test_number++;

        initialize_memory(32'h0000, 16, 32'hA000_0000);

        write_reg(REG_SRC_ADDR, 32'h0000);
        write_reg(REG_DST_ADDR, 32'h1000);
        write_reg(REG_LENGTH,   16);
        write_reg(REG_CONTROL,  8'b0101_0111);  // WORD, burst_en=1

        wait_for_done();
        verify_memory(32'h0000, 32'h1000, 16);
        clear_interrupts();
    endtask

    // =========================================================================
    // TEST 2: Single Word Transfer (no burst)
    // =========================================================================
    task automatic test_single_word();
        $display("\n========================================");
        $display("TEST 2: SINGLE WORD TRANSFER (1 word)");
        $display("========================================");
        test_number++;

        initialize_memory(32'h2000, 1, 32'hDEAD_BEEF);

        write_reg(REG_SRC_ADDR, 32'h2000);
        write_reg(REG_DST_ADDR, 32'h3000);
        write_reg(REG_LENGTH,   1);           // Only 1 word
        write_reg(REG_CONTROL,  8'b0100_0111); // WORD, burst_en=0, no burst

        wait_for_done();
        verify_memory(32'h2000, 32'h3000, 1);
        clear_interrupts();
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        rst_n = 0;
        reg_write = 0;
        reg_read  = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Run tests
        test_simple_burst();
        repeat(10) @(posedge clk);
        
        test_single_word();
        repeat(10) @(posedge clk);

        // Final report
        $display("\n========================================");
        $display("FINAL TEST REPORT");
        $display("========================================");
        $display("Tests run:  %0d", test_number);
        $display("Passes:     %0d", pass_count);
        $display("Errors:     %0d", errors);
        
        if (errors == 0) begin
            $display("\n*** ALL TESTS PASSED! ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end

        $finish;
    end

endmodule