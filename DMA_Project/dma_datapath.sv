// ============================================================================
// File: dma_datapath_axi.sv  
// Description:
//  - Clearer and safer computation of burst_bytes (bytes transferred per burst).
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

