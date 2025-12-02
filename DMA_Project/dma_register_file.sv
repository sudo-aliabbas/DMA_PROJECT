// ============================================================================
// File: dma_register_file.sv
// Description: Memory-mapped register file 
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
                REG_STATUS:     reg_rdata = {24'h0, 5'b0, 
                                         int_status_reg[STAT_ERROR],  // Sticky
                                         int_status_reg[STAT_DONE],   // Sticky
                                         busy_i};                      // Live
                REG_INT_STATUS: reg_rdata = {24'h0, int_status_reg};
                default:        reg_rdata = 32'h0;
            endcase
        end
    end
endmodule
