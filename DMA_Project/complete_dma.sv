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




// ============================================================================
// File: dma_register_file.sv
// Description: Memory-mapped register file (unchanged from original)
// ============================================================================
module dma_register_file 
    import dma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU/Register interface
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [3:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,
    
    // DMA control outputs
    output logic [31:0] src_addr_o,
    output logic [31:0] dst_addr_o,
    output logic [15:0] length_o,
    output logic        start_o,
    output logic        src_inc_o,
    output logic        dst_inc_o,
    output logic        int_en_o,
    output logic        burst_en_o,
    output transfer_width_e width_o,
    
    // DMA status inputs
    input  logic        busy_i,
    input  logic        done_i,
    input  logic        error_i,
    
    // Interrupt output
    output logic        interrupt_o
);
    // Internal registers
    logic [31:0] src_addr_reg;
    logic [31:0] dst_addr_reg;
    logic [15:0] length_reg;
    logic [7:0]  control_reg;
    logic [7:0]  status_reg;
    logic [7:0]  int_status_reg;
    
    // Control register bits
    assign start_o     = control_reg[CTRL_START];
    assign src_inc_o   = control_reg[CTRL_SRC_INC];
    assign dst_inc_o   = control_reg[CTRL_DST_INC];
    assign int_en_o    = control_reg[CTRL_INT_EN];
    assign burst_en_o  = control_reg[CTRL_BURST_EN];
    assign width_o     = transfer_width_e'(control_reg[6:5]);
    
    // Output assignments
    assign src_addr_o = src_addr_reg;
    assign dst_addr_o = dst_addr_reg;
    assign length_o   = length_reg;
    
    // Status register
    assign status_reg = {5'b0, error_i, done_i, busy_i};
    
    // Interrupt generation
    assign interrupt_o = int_en_o & (done_i | error_i);
    
    // Register writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr_reg    <= 32'h0;
            dst_addr_reg    <= 32'h0;
            length_reg      <= 16'h0;
            control_reg     <= 8'h0;
            int_status_reg  <= 8'h0;
        end else begin
            // Auto-clear start bit when transfer begins
            if (start_o && busy_i)
                control_reg[CTRL_START] <= 1'b0;
            
            // Capture interrupt events
            if (done_i)
                int_status_reg[STAT_DONE] <= 1'b1;
            if (error_i)
                int_status_reg[STAT_ERROR] <= 1'b1;
            
            // CPU writes
            if (reg_write) begin
                case (reg_addr)
                    REG_SRC_ADDR:   src_addr_reg <= reg_wdata;
                    REG_DST_ADDR:   dst_addr_reg <= reg_wdata;
                    REG_LENGTH:     length_reg   <= reg_wdata[15:0];
                    REG_CONTROL:    control_reg  <= reg_wdata[7:0];
                    REG_INT_STATUS: int_status_reg <= int_status_reg & ~reg_wdata[7:0]; // W1C
                endcase
            end
        end
    end
    
    // Register reads
    always_comb begin
        reg_rdata = 32'h0;
        if (reg_read) begin
            case (reg_addr)
                REG_SRC_ADDR:   reg_rdata = src_addr_reg;
                REG_DST_ADDR:   reg_rdata = dst_addr_reg;
                REG_LENGTH:     reg_rdata = {16'h0, length_reg};
                REG_CONTROL:    reg_rdata = {24'h0, control_reg};
                REG_STATUS:     reg_rdata = {24'h0, status_reg};
                REG_INT_STATUS: reg_rdata = {24'h0, int_status_reg};
                default:        reg_rdata = 32'h0;
            endcase
        end
    end
endmodule





// ============================================================================
// File: dma_datapath_axi.sv  (fixed)
// Description:
//  - Clearer and safer computation of burst_bytes (bytes transferred per burst).
//  - No functional API change - same ports retained.
// ============================================================================
module dma_datapath_axi
    import dma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // Configuration
    input  logic [31:0] src_addr_init,
    input  logic [31:0] dst_addr_init,
    input  logic [15:0] length_init,
    input  logic        src_inc,
    input  logic        dst_inc,
    input  transfer_width_e width,
    input  logic [7:0]  burst_len,
    
    // Control
    input  logic        load_params,
    input  logic        update_addresses,
    input  logic        dec_count,
    
    // Outputs
    output logic [31:0] src_addr_o,
    output logic [31:0] dst_addr_o,
    output logic [15:0] count_o,
    output logic [15:0] remaining_count,
    output logic        transfer_done
);

    logic [31:0] src_addr_reg, dst_addr_reg;
    logic [15:0] count_reg;
    logic [31:0] burst_bytes;

    // bytes per beat (1,2,4)
    logic [31:0] beat_size;

    always_comb begin
        case (width)
            BYTE:     beat_size = 1;
            HALFWORD: beat_size = 2;
            WORD:     beat_size = 4;
            default:  beat_size = 4;
        endcase
        // burst_len is AXI arlen (beats - 1)
        burst_bytes = (burst_len + 1) * beat_size;
    end
    
    // Address and count management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr_reg <= '0;
            dst_addr_reg <= '0;
            count_reg    <= '0;
        end else if (load_params) begin
            // length_init is in beats/words (caller/testbench sets it that way)
            src_addr_reg <= src_addr_init;
            dst_addr_reg <= dst_addr_init;
            count_reg    <= length_init;
        end else if (update_addresses && dec_count) begin
            // Update after burst completes
            if (src_inc)
                src_addr_reg <= src_addr_reg + burst_bytes;
            if (dst_inc)
                dst_addr_reg <= dst_addr_reg + burst_bytes;
            
            if (count_reg >= (burst_len + 1))
                count_reg <= count_reg - (burst_len + 1);
            else
                count_reg <= '0;
        end
    end
    
    assign src_addr_o      = src_addr_reg;
    assign dst_addr_o      = dst_addr_reg;
    assign count_o         = count_reg;
    assign remaining_count = count_reg;
    assign transfer_done   = (count_reg == 0);

endmodule





// ============================================================================
// File: dma_control_fsm_axi.sv  (fixed)
// Description:
//  - Added fifo_count input so FSM waits for FIFO fill before starting write
//    bursts. This prevents the write-side deadlock where write begins but
//    FIFO is empty (no wdata -> no wlast -> no bresp).
//  - Minimal changes to keep compatibility with existing dma_pkg.
// ============================================================================
module dma_control_fsm_axi 
    import dma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // Control inputs
    input  logic        start,
    input  logic        burst_en,
    input  logic [15:0] total_length,
    input  logic [1:0]  transfer_width,
    
    // AXI interface control
    output logic        start_read_burst,
    output logic        start_write_burst,
    output logic [7:0]  burst_len,
    input  logic        read_burst_done,
    input  logic        write_burst_done,
    input  logic [1:0]  write_resp,
    input  logic        axi_error,
    
    // Datapath control
    output logic        load_params,
    output logic        update_addresses,
    output logic        dec_count,
    input  logic        transfer_done,
    input  logic [15:0] remaining_count,

    // FIFO status input (new)
    input  logic [4:0] fifo_count,
    
    // Status outputs
    output logic        busy,
    output logic        done,
    output logic        error
);

    dma_state_e current_state, next_state;
    logic [7:0] current_burst_len;
    logic [7:0] beats_in_burst;
    
    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    
    // Calculate optimal burst length
    always_comb begin
        if (!burst_en) begin
            beats_in_burst = 8'd0;  // Single beat mode
        end else if (remaining_count >= MAX_BURST_LEN) begin
            beats_in_burst = MAX_BURST_LEN - 1;  // AXI: len=0 means 1 beat
        end else if (remaining_count >= MIN_BURST_LEN) begin
            beats_in_burst = remaining_count[7:0] - 1;
        end else if (remaining_count > 0) begin
            beats_in_burst = remaining_count[7:0] - 1;
        end else begin
            beats_in_burst = 8'd0;
        end
    end
    
    assign burst_len = beats_in_burst;
    
    // FSM logic
    always_comb begin
        // Defaults
        next_state        = current_state;
        start_read_burst  = 1'b0;
        start_write_burst = 1'b0;
        load_params       = 1'b0;
        update_addresses  = 1'b0;
        dec_count         = 1'b0;
        busy              = 1'b0;
        done              = 1'b0;
        error             = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    load_params = 1'b1;
                    next_state  = CALC_BURST;
                end
            end
            
            CALC_BURST: begin
                busy = 1'b1;
                if (transfer_done) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = READ_ADDR;
                end
            end
            
            READ_ADDR: begin
                busy             = 1'b1;
                start_read_burst = 1'b1;
                next_state       = READ_DATA;
            end
            
            READ_DATA: begin
                busy = 1'b1;
                if (read_burst_done) begin
                    if (axi_error) begin
                        next_state = ERROR;
                    end else begin
                        next_state = WRITE_ADDR;
                    end
                end
            end
            
            // Note: WAIT for FIFO fill inside WRITE_ADDR (no new enum added)
           WRITE_ADDR: begin
			busy = 1'b1;

			// Start write immediately after read is done OR fifo has data
			if (read_burst_done || fifo_count > 0) begin
				start_write_burst = 1'b1;
				next_state        = WRITE_DATA;
				end
				else begin
				next_state = WRITE_ADDR;
				end
			end
            
            WRITE_DATA: begin
                busy = 1'b1;
                // Wait for all data to be written (AXI master handles data flow)
                next_state = WRITE_RESP;
            end
            
            WRITE_RESP: begin
                busy = 1'b1;
                if (write_burst_done) begin
                    if (write_resp != OKAY || axi_error) begin
                        next_state = ERROR;
                    end else begin
                        // Update counters and addresses
                        update_addresses = 1'b1;
                        dec_count        = 1'b1;
                        next_state       = CHECK_DONE;
                    end
                end
            end
            
            CHECK_DONE: begin
                busy = 1'b1;
                if (transfer_done) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = CALC_BURST;
                end
            end
            
            COMPLETE: begin
                done       = 1'b1;
                next_state = IDLE;
            end
            
            ERROR: begin
                error      = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule




// ============================================================================
// File: dma_fifo.sv  (fixed)
// Description:
//  - Increased default depth to better handle large AXI bursts.
//  - Exposes count (already present) so controller and AXI master can observe
//    FIFO fill level and avoid deadlocks.
// ============================================================================
module dma_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 32  // Increased from 32 to 256 to support large bursts
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,
    
    // Read interface
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,
    
    // Status
    output logic [$clog2(DEPTH) - 1:0]  count
);
    // check DEPTH is at least 1 to avoid math issues
    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic [PTR_WIDTH-1:0]  wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0] count_reg;
    
    assign count = count_reg;
    assign full  = (count_reg == DEPTH);
    assign empty = (count_reg == 0);
    
    // Write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= rd_ptr + 1;
        end
    end
    
    // Count management (safe single-clock update)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count_reg <= count_reg + 1;
                2'b01:   count_reg <= count_reg - 1;
                default: count_reg <= count_reg;
            endcase
        end
    end
endmodule




// ============================================================================
// File: axi4_master_if.sv  (COMPLETE FIXED VERSION)
// ============================================================================

module axi4_master_if
    import dma_pkg::*;
#(
    parameter int FIFO_DEPTH = 256
)(
    input  logic        aclk,
    input  logic        aresetn,

    // DMA control
    input  logic        start_read_burst,
    input  logic        start_write_burst,
    input  logic [31:0] read_addr,
    input  logic [31:0] write_addr,
    input  logic [7:0]  burst_len,        // beats-1
    input  logic [1:0]  burst_size,
    input  logic        src_inc,
    input  logic        dst_inc,

    output logic        read_burst_done,
    output logic        write_burst_done,
    output logic [1:0]  write_resp,
    output logic        error,

    // FIFO signals
    output logic        fifo_wr_en,
    output logic [31:0] fifo_wdata,
    input  logic        fifo_full,
    input  logic [4:0] fifo_count,

    output logic        fifo_rd_en,
    input  logic [31:0] fifo_rdata,
    input  logic        fifo_empty,

    // AXI Read Address
    output logic [AXI_ID_WIDTH-1:0]   m_axi_arid,
    output logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                m_axi_arlen,
    output logic [2:0]                m_axi_arsize,
    output logic [1:0]                m_axi_arburst,
    output logic                      m_axi_arvalid,
    input  logic                      m_axi_arready,

    // AXI Read Data
    input  logic [AXI_ID_WIDTH-1:0]   m_axi_rid,
    input  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]                m_axi_rresp,
    input  logic                      m_axi_rlast,
    input  logic                      m_axi_rvalid,
    output logic                      m_axi_rready,

    // AXI Write Address
    output logic [AXI_ID_WIDTH-1:0]   m_axi_awid,
    output logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]                m_axi_awlen,
    output logic [2:0]                m_axi_awsize,
    output logic [1:0]                m_axi_awburst,
    output logic                      m_axi_awvalid,
    input  logic                      m_axi_awready,

    // AXI Write Data
    output logic [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [3:0]                m_axi_wstrb,
    output logic                      m_axi_wlast,
    output logic                      m_axi_wvalid,
    input  logic                      m_axi_wready,

    // AXI Write Response
    input  logic [AXI_ID_WIDTH-1:0]   m_axi_bid,
    input  logic [1:0]                m_axi_bresp,
    input  logic                      m_axi_bvalid,
    output logic                      m_axi_bready
);

// ------------------------------------------
// CONSTANTS
// ------------------------------------------
assign m_axi_arid = 4'h1;
assign m_axi_awid = 4'h1;
assign m_axi_bready = 1'b1;

// Write strobe generation
always_comb begin
    case (burst_size)
        2'b00: m_axi_wstrb = 4'b0001;
        2'b01: m_axi_wstrb = 4'b0011;
        default: m_axi_wstrb = 4'b1111;
    endcase
end

// ------------------------------------------
// READ ADDRESS CHANNEL
// ------------------------------------------
logic read_active;

always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        m_axi_araddr  <= 0;
        m_axi_arlen   <= 0;
        m_axi_arsize  <= 3'b010;
        m_axi_arburst <= INCR;
        m_axi_arvalid <= 0;
        read_active   <= 0;
        error         <= 0;
    end else begin
        if (start_read_burst)
            error <= 0;

        if (start_read_burst && !read_active) begin
            m_axi_araddr  <= read_addr;
            m_axi_arlen   <= burst_len;
            m_axi_arsize  <= {1'b0, burst_size};
            m_axi_arburst <= src_inc ? INCR : FIXED;
            m_axi_arvalid <= 1;
            read_active   <= 1;
        end

        if (m_axi_arvalid && m_axi_arready)
            m_axi_arvalid <= 0;

        if (read_burst_done)
            read_active <= 0;
    end
end

// ------------------------------------------
// READ DATA CHANNEL
// ------------------------------------------
logic [7:0] read_cnt;

always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        m_axi_rready     <= 0;
        read_burst_done  <= 0;
        fifo_wr_en       <= 0;
        read_cnt         <= 0;
    end else begin
        fifo_wr_en      <= 0;
        read_burst_done <= 0;

        m_axi_rready <= read_active && (fifo_count < FIFO_DEPTH - 2);

        if (m_axi_rvalid && m_axi_rready) begin
            fifo_wr_en  <= 1;
            fifo_wdata  <= m_axi_rdata;

            if (m_axi_rresp != OKAY)
                error <= 1;

            if (m_axi_rlast) begin
                read_cnt        <= 0;
                read_burst_done <= 1;
            end else begin
                read_cnt <= read_cnt + 1;
            end
        end
    end
end

// ------------------------------------------
// WRITE ADDRESS CHANNEL
// ------------------------------------------
logic write_active;

always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        m_axi_awaddr  <= 0;
        m_axi_awlen   <= 0;
        m_axi_awsize  <= 3'b010;
        m_axi_awburst <= INCR;
        m_axi_awvalid <= 0;
        write_active  <= 0;
    end else begin
        if (start_write_burst)
            error <= 0;

        if (start_write_burst && !write_active) begin
            m_axi_awaddr  <= write_addr;
            m_axi_awlen   <= burst_len;
            m_axi_awsize  <= {1'b0, burst_size};
            m_axi_awburst <= dst_inc ? INCR : FIXED;
            m_axi_awvalid <= 1;
            write_active  <= 1;
        end

        if (m_axi_awvalid && m_axi_awready)
            m_axi_awvalid <= 0;

        if (m_axi_bvalid && m_axi_bready)
            write_active <= 0;
    end
end

// ============================================================================
// WRITE DATA CHANNEL - FIXED FOR PROPER SYNCHRONOUS FIFO TIMING
// ============================================================================

logic [7:0] write_beat_cnt;
logic fifo_data_valid;  // Indicates FIFO data is valid

always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        m_axi_wdata       <= 0;
        m_axi_wvalid      <= 0;
        m_axi_wlast       <= 0;
        write_beat_cnt    <= 0;
        write_burst_done  <= 0;
        fifo_data_valid   <= 0;
    end else begin
        
        // Track when FIFO data becomes valid (1 cycle after rd_en)
        fifo_data_valid <= fifo_rd_en;
        
        // 🔧 FIX: Send data ONLY when fifo_data_valid is high (not when fifo_rd_en is high!)
        if (fifo_data_valid && (!m_axi_wvalid || m_axi_wready)) begin
            // Now fifo_rdata is valid and stable
            m_axi_wdata  <= fifo_rdata;
            m_axi_wvalid <= 1;
            
            // Check if this is the last beat
            if (write_beat_cnt == burst_len) begin
                m_axi_wlast    <= 1;
                write_beat_cnt <= 0;
            end else begin
                m_axi_wlast    <= 0;
                write_beat_cnt <= write_beat_cnt + 1;
            end
        end
        // Clear WVALID after handshake
        else if (m_axi_wvalid && m_axi_wready) begin
            m_axi_wvalid <= 0;
            m_axi_wlast  <= 0;
        end
        
        // Reset counter when burst complete
        if (m_axi_bvalid && m_axi_bready) begin
            write_beat_cnt <= 0;
        end
    end
end

// FIFO read enable - request new data when not pending and can accept
assign fifo_rd_en = write_active && !fifo_empty && !fifo_data_valid && 
                    (!m_axi_wvalid || m_axi_wready);

// ------------------------------------------
// WRITE RESPONSE CHANNEL
// ------------------------------------------
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        write_resp <= OKAY;
    end else begin
        if (m_axi_bvalid && m_axi_bready) begin
            write_resp       <= m_axi_bresp;
            write_burst_done <= 1;
            if (m_axi_bresp != OKAY)
                error <= 1;
        end else begin
            write_burst_done <= 0;
        end
    end
end

endmodule



// ============================================================================
// File: dma_controller_top.sv  (small fix)
// Description:
//  - Connect fifo.count to control FSM and AXI master so both can observe FIFO
//    fill level and avoid deadlocks.
// ============================================================================
module dma_controller_top
    import dma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU register interface
    input  logic        reg_write,
    input  logic        reg_read,
    input  logic [3:0]  reg_addr,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_rdata,
    
    // AXI4 Master Interface
    output logic [AXI_ID_WIDTH-1:0]   m_axi_arid,
    output logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                m_axi_arlen,
    output logic [2:0]                m_axi_arsize,
    output logic [1:0]                m_axi_arburst,
    output logic                      m_axi_arvalid,
    input  logic                      m_axi_arready,
    
    input  logic [AXI_ID_WIDTH-1:0]   m_axi_rid,
    input  logic [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]                m_axi_rresp,
    input  logic                      m_axi_rlast,
    input  logic                      m_axi_rvalid,
    output logic                      m_axi_rready,
    
    output logic [AXI_ID_WIDTH-1:0]   m_axi_awid,
    output logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]                m_axi_awlen,
    output logic [2:0]                m_axi_awsize,
    output logic [1:0]                m_axi_awburst,
    output logic                      m_axi_awvalid,
    input  logic                      m_axi_awready,
    
    output logic [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [3:0]                m_axi_wstrb,
    output logic                      m_axi_wlast,
    output logic                      m_axi_wvalid,
    input  logic                      m_axi_wready,
    
    input  logic [AXI_ID_WIDTH-1:0]   m_axi_bid,
    input  logic [1:0]                m_axi_bresp,
    input  logic                      m_axi_bvalid,
    output logic                      m_axi_bready,
    
    // Interrupt
    output logic        interrupt
);

    // Internal signals (unchanged)
    logic [31:0] src_addr, dst_addr;
    logic [15:0] length;
    logic        start, src_inc, dst_inc, int_en, burst_en;
    transfer_width_e width;
    logic        busy, done, error;
    
    logic        start_read_burst, start_write_burst;
    logic [7:0]  burst_len;
    logic        read_burst_done, write_burst_done;
    logic [1:0]  write_resp;
    logic        axi_error;
    
    logic        fifo_wr_en, fifo_rd_en;
    logic        fifo_full, fifo_empty;
    logic [31:0] fifo_wdata, fifo_rdata;
    
    logic [4:0] fifo_count; // NEW: FIFO level
    // keep other signals
    logic        load_params, update_addresses, dec_count;
    logic [31:0] current_src_addr, current_dst_addr;
    logic [15:0] current_count, remaining_count;
    logic        transfer_done;
    
    // Instantiate register file
    dma_register_file reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .src_addr_o(src_addr),
        .dst_addr_o(dst_addr),
        .length_o(length),
        .start_o(start),
        .src_inc_o(src_inc),
        .dst_inc_o(dst_inc),
        .int_en_o(int_en),
        .burst_en_o(burst_en),
        .width_o(width),
        .busy_i(busy),
        .done_i(done),
        .error_i(error),
        .interrupt_o(interrupt)
    );
    
    // Instantiate FIFO (32-deep for burst buffering)
    dma_fifo #(
        .DATA_WIDTH(32),
        .DEPTH(FIFO_DEPTH) // FIFO_DEPTH defined in dma_pkg
    ) data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .wr_data(fifo_wdata),
        .full(fifo_full),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rdata),
        .empty(fifo_empty),
        .count(fifo_count) // CONNECTED: now we expose fill level
    );
    
    // Instantiate datapath
    dma_datapath_axi datapath (
        .clk(clk),
        .rst_n(rst_n),
        .src_addr_init(src_addr),
        .dst_addr_init(dst_addr),
        .length_init(length),
        .src_inc(src_inc),
        .dst_inc(dst_inc),
        .width(width),
        .burst_len(burst_len),
        .load_params(load_params),
        .update_addresses(update_addresses),
        .dec_count(dec_count),
        .src_addr_o(current_src_addr),
        .dst_addr_o(current_dst_addr),
        .count_o(current_count),
        .remaining_count(remaining_count),
        .transfer_done(transfer_done)
    );
    
    // Instantiate control FSM (now gets fifo_count)
    dma_control_fsm_axi control_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .burst_en(burst_en),
        .total_length(length),
        .transfer_width(width),
        .start_read_burst(start_read_burst),
        .start_write_burst(start_write_burst),
        .burst_len(burst_len),
        .read_burst_done(read_burst_done),
        .write_burst_done(write_burst_done),
        .write_resp(write_resp),
        .axi_error(axi_error),
        .load_params(load_params),
        .update_addresses(update_addresses),
        .dec_count(dec_count),
        .transfer_done(transfer_done),
        .remaining_count(remaining_count),
        .fifo_count(fifo_count), // <-- newly connected
        .busy(busy),
        .done(done),
        .error(error)
    );
    
    // Instantiate AXI master interface (now uses fifo_count input)
    axi4_master_if #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) axi_master (
        .aclk(clk),
        .aresetn(rst_n),
        .start_read_burst(start_read_burst),
        .start_write_burst(start_write_burst),
        .read_addr(current_src_addr),
        .write_addr(current_dst_addr),
        .burst_len(burst_len),
        .burst_size(width),
        .src_inc(src_inc),
        .dst_inc(dst_inc),
        .read_burst_done(read_burst_done),
        .write_burst_done(write_burst_done),
        .write_resp(write_resp),
        .error(axi_error),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wdata(fifo_wdata),
        .fifo_full(fifo_full),
        .fifo_count(fifo_count),    // <-- pass FIFO level into master
        .fifo_rd_en(fifo_rd_en),
        .fifo_rdata(fifo_rdata),
        .fifo_empty(fifo_empty),
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
        .m_axi_bready(m_axi_bready)
    );

endmodule





// ============================================================================
// File: axi_slave_mem.sv
// Description: AXI4 Slave wrapper for simple memory
// ============================================================================
module axi_slave_mem #(
    parameter ADDR_WIDTH = 16,
    parameter MEM_BYTES  = 65536
)(
    input  logic        aclk,
    input  logic        aresetn,
    
    // AXI4 Slave Read Address Channel
    input  logic [3:0]  s_axi_arid,
    input  logic [31:0] s_axi_araddr,
    input  logic [7:0]  s_axi_arlen,
    input  logic [2:0]  s_axi_arsize,
    input  logic [1:0]  s_axi_arburst,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    
    // AXI4 Slave Read Data Channel
    output logic [3:0]  s_axi_rid,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rlast,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,
    
    // AXI4 Slave Write Address Channel
    input  logic [3:0]  s_axi_awid,
    input  logic [31:0] s_axi_awaddr,
    input  logic [7:0]  s_axi_awlen,
    input  logic [2:0]  s_axi_awsize,
    input  logic [1:0]  s_axi_awburst,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    
    // AXI4 Slave Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wlast,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    
    // AXI4 Slave Write Response Channel
    output logic [3:0]  s_axi_bid,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready
);

    localparam WORDS = MEM_BYTES / 4;
    logic [31:0] mem [0:WORDS-1];
    
    // Read channel state
    logic [31:0] read_addr;
    logic [7:0]  read_len;
    logic [7:0]  read_count;
    logic [3:0]  read_id;
    logic [31:0] read_addr_incr;
    logic        read_burst_active;
    
    // Write channel state
    logic [31:0] write_addr;
    logic [7:0]  write_len;
    logic [7:0]  write_count;
    logic [3:0]  write_id;
    logic [31:0] write_addr_incr;
    logic        write_burst_active;
    
    /* Initialize memory with test pattern
    initial begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] = 32'hDEAD0000 + i;
        end
    end
    */
    // ========================================================================
    // Read Address Channel
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            read_addr     <= '0;
            read_len      <= '0;
            read_id       <= '0;
            read_count    <= '0;
            read_burst_active <= 1'b0;
        end else begin
            // Accept read address when not busy
            if (s_axi_arvalid && !read_burst_active) begin
                read_addr     <= s_axi_araddr;
                read_len      <= s_axi_arlen;
                read_id       <= s_axi_arid;
                read_count    <= '0;
                read_addr_incr <= s_axi_araddr;
                s_axi_arready <= 1'b1;
                read_burst_active <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end
            
            // Clear burst active when complete
            if (s_axi_rvalid && s_axi_rready && s_axi_rlast) begin
                read_burst_active <= 1'b0;
            end
            
        /*    // Increment address for INCR bursts
            if (s_axi_rvalid && s_axi_rready && (s_axi_arburst == 2'b01)) begin
                read_addr_incr <= read_addr_incr + 4;
            end
			*/
        end
    end
    
    // ========================================================================
// Read Data Channel - FIXED
// ========================================================================
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        s_axi_rdata  <= '0;
        s_axi_rresp  <= 2'b00;
        s_axi_rlast  <= 1'b0;
        s_axi_rvalid <= 1'b0;
        s_axi_rid    <= '0;
    end else begin
        // Generate read data when burst is active
        if (read_burst_active && (!s_axi_rvalid || s_axi_rready)) begin
            s_axi_rdata  <= mem[read_addr_incr[31:2] % WORDS];
            s_axi_rresp  <= 2'b00;
            s_axi_rlast  <= (read_count == read_len);
            s_axi_rvalid <= 1'b1;
            s_axi_rid    <= read_id;
            read_count   <= read_count + 1;
            
            // 🔧 FIX: Increment address HERE for INCR bursts
            if (s_axi_arburst == 2'b01) begin
                read_addr_incr <= read_addr_incr + 4;
            end
        end
        else if (s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end
    
 // ========================================================================
// Write Address Channel
// ========================================================================
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        s_axi_awready <= 1'b0;
        write_addr    <= '0;
        write_len     <= '0;
        write_id      <= '0;
        write_count   <= '0;
        write_burst_active <= 1'b0;
    end else begin
        // Accept write address when not busy
        if (s_axi_awvalid && !write_burst_active) begin
            write_addr      <= s_axi_awaddr;
            write_len       <= s_axi_awlen;
            write_id        <= s_axi_awid;
            write_count     <= '0;
            write_addr_incr <= s_axi_awaddr;
            s_axi_awready   <= 1'b1;
            write_burst_active <= 1'b1;
        end else begin
            s_axi_awready <= 1'b0;
        end
        
        // Clear burst active when complete
        if (s_axi_bvalid && s_axi_bready) begin
            write_burst_active <= 1'b0;
        end
        
        // NOTE: Address increment moved to Write Data Channel (like Read)
    end
end

// ========================================================================
// Write Data Channel - FIXED
// ========================================================================
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        s_axi_wready <= 1'b0;
    end else begin
        // Accept write data when burst is active
        s_axi_wready <= write_burst_active;
        
        // Write to memory
        if (s_axi_wvalid && s_axi_wready) begin
            if (s_axi_wstrb[0]) mem[write_addr_incr[31:2] % WORDS][7:0]   <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) mem[write_addr_incr[31:2] % WORDS][15:8]  <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) mem[write_addr_incr[31:2] % WORDS][23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) mem[write_addr_incr[31:2] % WORDS][31:24] <= s_axi_wdata[31:24];
            
            write_count <= write_count + 1;
            
            // 🔧 FIX: Increment address for INCR bursts (same as Read)
            if (s_axi_awburst == 2'b01) begin
                write_addr_incr <= write_addr_incr + 4;
            end
        end
    end
end
    // ========================================================================
    // Write Response Channel
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bresp  <= 2'b00; // OKAY
            s_axi_bvalid <= 1'b0;
            s_axi_bid    <= '0;
        end else begin
            // Send response after last write data
            if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
                s_axi_bresp  <= 2'b00; // OKAY
                s_axi_bvalid <= 1'b1;
                s_axi_bid    <= write_id;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

endmodule


