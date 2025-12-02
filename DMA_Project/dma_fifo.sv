// ============================================================================
// File: dma_fifo.sv  
// Description:
//  - Exposes count so controller and AXI master can observe
//    FIFO fill level and avoid deadlocks.
// ============================================================================
module dma_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 32  
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
