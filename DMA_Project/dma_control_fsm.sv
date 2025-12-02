// ============================================================================
// File: dma_control_fsm_axi.sv  
// Description:
//  - Added fifo_count input so FSM waits for FIFO fill before starting write
//    bursts. This prevents the write-side deadlock where write begins but
//    FIFO is empty (no wdata -> no wlast -> no bresp).
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
