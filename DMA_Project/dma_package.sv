// ============================================================================
// File: dma_pkg.sv
// Description: Package with enhanced types for AXI4-Full DMA
// ============================================================================
package dma_pkg;
    // Transfer width encoding
    typedef enum logic [1:0] {
        BYTE     = 2'b00,  // 8-bit transfer
        HALFWORD = 2'b01,  // 16-bit transfer
        WORD     = 2'b10   // 32-bit transfer
    } transfer_width_e;
    
    // DMA channel states (enhanced for AXI4 burst support)
    typedef enum logic [3:0] {
        IDLE          = 4'd0,
        LOAD_DESC     = 4'd1,  // Load descriptor parameters
        CALC_BURST    = 4'd2,  // Calculate burst parameters
        READ_ADDR     = 4'd3,  // Issue AXI read address
        READ_DATA     = 4'd4,  // Receive AXI read data bursts
        WRITE_ADDR    = 4'd5,  // Issue AXI write address
        WRITE_DATA    = 4'd6,  // Send AXI write data bursts
        WRITE_RESP    = 4'd7,  // Wait for write response
        CHECK_DONE    = 4'd8,  // Check if transfer complete
        COMPLETE      = 4'd9,  // Transfer done
        ERROR         = 4'd10  // Error state
    } dma_state_e;
    
    // AXI4 burst types
    typedef enum logic [1:0] {
        FIXED       = 2'b00,
        INCR        = 2'b01,
        WRAP        = 2'b10
    } axi_burst_e;
    
    // AXI4 response types
    typedef enum logic [1:0] {
        OKAY        = 2'b00,
        EXOKAY      = 2'b01,
        SLVERR      = 2'b10,
        DECERR      = 2'b11
    } axi_resp_e;
    
    // Register addresses (byte-aligned)
    parameter logic [3:0] REG_SRC_ADDR   = 4'h0;
    parameter logic [3:0] REG_DST_ADDR   = 4'h4;
    parameter logic [3:0] REG_LENGTH     = 4'h8;
    parameter logic [3:0] REG_CONTROL    = 4'hC;
    parameter logic [3:0] REG_STATUS     = 4'hD;
    parameter logic [3:0] REG_INT_STATUS = 4'hE;
    
    // Control register bit positions
    parameter int CTRL_START       = 0;
    parameter int CTRL_SRC_INC     = 1;
    parameter int CTRL_DST_INC     = 2;
    parameter int CTRL_INT_EN      = 3;
    parameter int CTRL_BURST_EN    = 4;
    parameter int CTRL_WIDTH_LSB   = 5;
    parameter int CTRL_WIDTH_MSB   = 6;
    
    // Status register bit positions
    parameter int STAT_BUSY        = 0;
    parameter int STAT_DONE        = 1;
    parameter int STAT_ERROR       = 2;
    
    // Burst configuration
    parameter int MAX_BURST_LEN    = 16;   // AXI4 max burst length
    parameter int MIN_BURST_LEN    = 4;    // Minimum efficient burst
    parameter int FIFO_DEPTH       = 32;   // Deep enough for bursts
    parameter int AXI_DATA_WIDTH   = 32;
    parameter int AXI_ADDR_WIDTH   = 32;
    parameter int AXI_ID_WIDTH     = 4;
    
endpackage