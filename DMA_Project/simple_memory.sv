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
				
				// Increment address HERE for INCR bursts
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
				
				// Increment address for INCR bursts (same as Read)
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

