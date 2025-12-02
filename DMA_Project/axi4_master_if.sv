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
	// WRITE DATA CHANNEL - 
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
			
			//  Send data ONLY when fifo_data_valid is high 
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