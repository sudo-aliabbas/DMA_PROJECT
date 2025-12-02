// ============================================================================
// File: dma_controller_top.sv 
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
