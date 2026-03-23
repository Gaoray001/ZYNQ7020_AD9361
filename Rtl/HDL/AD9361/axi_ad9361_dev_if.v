`timescale 1ns/100ps

module axi_ad9361_dev_if (

  // ---------------------------------------------------------------------------
  // Physical interface : Receive
  // ---------------------------------------------------------------------------
  rx_clk_in_p,
  rx_clk_in_n,
  rx_frame_in_p,
  rx_frame_in_n,
  rx_data_in_p,
  rx_data_in_n,

  // ---------------------------------------------------------------------------
  // Physical interface : Transmit
  // ---------------------------------------------------------------------------
  tx_clk_out_p,
  tx_clk_out_n,
  tx_frame_out_p,
  tx_frame_out_n,
  tx_data_out_p,
  tx_data_out_n,

  // ---------------------------------------------------------------------------
  // Clocks / Reset
  // clk   : common/system clock domain
  // l_clk : device interface clock domain, generated from rx_clk_in_p/n
  // ---------------------------------------------------------------------------
  rst,
  clk,
  l_clk,

  // ---------------------------------------------------------------------------
  // Receive data path interface
  // ---------------------------------------------------------------------------
  adc_valid,
  adc_data,
  adc_status,
  adc_r1_mode,

  // ---------------------------------------------------------------------------
  // Transmit data path interface
  // ---------------------------------------------------------------------------
  dac_valid,
  dac_data,
  dac_r1_mode,

  // ---------------------------------------------------------------------------
  // Delay control interface
  // ---------------------------------------------------------------------------
  delay_clk,
  delay_rst,
  delay_sel,
  delay_rwn,
  delay_addr,
  delay_wdata,
  delay_rdata,
  delay_ack_t,
  delay_locked,

  // ---------------------------------------------------------------------------
  // Debug interface
  // ---------------------------------------------------------------------------
  dev_dbg_data,
  dev_l_dbg_data
);

  // ===========================================================================
  // Module overview
  // ===========================================================================
  //
  //  ┌───────────────────────────────────────────────────────────────────────┐
  //  │                        axi_ad9361_dev_if                              │
  //  ├───────────────────────────────────────────────────────────────────────┤
  //  │                                                                       │
  //  │   RX side (AD9361 -> FPGA)                                            │
  //  │                                                                       │
  //  │   rx_clk_in_p/n  ---> ad_lvds_clk ------------------------------> l_clk
  //  │                               │                                       │
  //  │                               ├--> ad_lvds_in(frame) ----> rx_frame_* │
  //  │                               └--> ad_lvds_in(data[5:0])-> rx_data_*  │
  //  │                                                            │           │
  //  │                                                            v           │
  //  │                                                   RX unpack @ l_clk    │
  //  │                                               (R1 / R2 mode decode)    │
  //  │                                                            │           │
  //  │                                                            v           │
  //  │                                             adc_p_*  (l_clk domain)    │
  //  │                                                            │           │
  //  │                                               negedge l_clk transfer    │
  //  │                                                            │           │
  //  │                                                            v           │
  //  │                                             adc_n_*                  │
  //  │                                                            │           │
  //  │                                                   posedge clk sync     │
  //  │                                                            │           │
  //  │                                                            v           │
  //  │                                             adc_valid/data/status      │
  //  │                                                                       │
  //  │   TX side (FPGA -> AD9361)                                            │
  //  │                                                                       │
  //  │   dac_valid/data @ clk ---> TX mux / serialize scheduling              │
  //  │                                  │                                    │
  //  │                                  v                                    │
  //  │                             tx_frame / tx_data_p/n                    │
  //  │                                  │                                    │
  //  │                       negedge clk transfer to tx_n_*                  │
  //  │                                  │                                    │
  //  │                                  v                                    │
  //  │                       posedge l_clk transfer to tx_p_*                │
  //  │                                  │                                    │
  //  │                                  v                                    │
  //  │                  ad_lvds_out(data/frame/clk) ---> AD9361 LVDS         │
  //  │                                                                       │
  //  │   Delay control                                                        │
  //  │                                                                       │
  //  │   delay_clk/rst/sel/rwn/addr/wdata ---> ad_lvds_in delay elements     │
  //  │                                         <--- rdata / ack / locked      │
  //  │                                                                       │
  //  └───────────────────────────────────────────────────────────────────────┘
  //
  //  Notes:
  //  1) 本模块保留原工程的跨时钟方式：
  //     - l_clk -> clk 采用 negedge l_clk + posedge clk
  //     - clk   -> l_clk 采用 negedge clk   + posedge l_clk
  //  2) 该实现默认 clk 与 l_clk 为“同步相关时钟”，而非完全异步时钟。
  //  3) 本版本仅做工程整理与注释增强，不改变逻辑与接口。
  //
  // ===========================================================================

  // ===========================================================================
  // Parameters
  // ===========================================================================

  // Controls the buffer type based on target device
  parameter   PCORE_DEVICE_TYPE  = 0;
  parameter   PCORE_IODELAY_GROUP = "dev_if_delay_group";

  localparam  PCORE_7SERIES      = 0;
  localparam  PCORE_VIRTEX6      = 1;

  // ===========================================================================
  // Port declarations
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Physical interface : Receive
  // ---------------------------------------------------------------------------
  input           rx_clk_in_p;
  input           rx_clk_in_n;
  input           rx_frame_in_p;
  input           rx_frame_in_n;
  input   [ 5:0]  rx_data_in_p;
  input   [ 5:0]  rx_data_in_n;

  // ---------------------------------------------------------------------------
  // Physical interface : Transmit
  // ---------------------------------------------------------------------------
  output          tx_clk_out_p;
  output          tx_clk_out_n;
  output          tx_frame_out_p;
  output          tx_frame_out_n;
  output  [ 5:0]  tx_data_out_p;
  output  [ 5:0]  tx_data_out_n;

  // ---------------------------------------------------------------------------
  // Clocks / Reset
  // ---------------------------------------------------------------------------
  input           rst;
  input           clk;
  output          l_clk;

  // ---------------------------------------------------------------------------
  // Receive data path interface
  // ---------------------------------------------------------------------------
  output          adc_valid;
  output  [47:0]  adc_data;
  output          adc_status;
  input           adc_r1_mode;

  // ---------------------------------------------------------------------------
  // Transmit data path interface
  // ---------------------------------------------------------------------------
  input           dac_valid;
  input   [47:0]  dac_data;
  input           dac_r1_mode;

  // ---------------------------------------------------------------------------
  // Delay control interface
  // ---------------------------------------------------------------------------
  input           delay_clk;
  input           delay_rst;
  input           delay_sel;
  input           delay_rwn;
  input   [ 7:0]  delay_addr;
  input   [ 4:0]  delay_wdata;
  output  [ 4:0]  delay_rdata;
  output          delay_ack_t;
  output          delay_locked;

  // ---------------------------------------------------------------------------
  // Debug interface
  // ---------------------------------------------------------------------------
  output [111:0]  dev_dbg_data;
  output [ 61:0]  dev_l_dbg_data;

  // ===========================================================================
  // Internal registers
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // RX capture and frame history (l_clk domain)
  // ---------------------------------------------------------------------------
  reg     [11:0]  rx_data       = 'd0;
  reg     [ 1:0]  rx_frame      = 'd0;
  reg     [11:0]  rx_data_d     = 'd0;
  reg     [ 1:0]  rx_frame_d    = 'd0;

  // ---------------------------------------------------------------------------
  // RX decode result : R1 mode
  // ---------------------------------------------------------------------------
  reg             rx_error_r1   = 'd0;
  reg             rx_valid_r1   = 'd0;
  reg     [23:0]  rx_data_r1    = 'd0;

  // ---------------------------------------------------------------------------
  // RX decode result : R2 mode
  // ---------------------------------------------------------------------------
  reg             rx_error_r2   = 'd0;
  reg             rx_valid_r2   = 'd0;
  reg     [47:0]  rx_data_r2    = 'd0;

  // ---------------------------------------------------------------------------
  // RX path crossing registers
  // adc_p_* : l_clk posedge domain result
  // adc_n_* : captured on negedge l_clk before transfer to clk domain
  // ---------------------------------------------------------------------------
  reg             adc_p_valid   = 'd0;
  reg     [47:0]  adc_p_data    = 'd0;
  reg             adc_p_status  = 'd0;

  reg             adc_n_valid   = 'd0;
  reg     [47:0]  adc_n_data    = 'd0;
  reg             adc_n_status  = 'd0;

  reg             adc_valid_int = 'd0;
  reg     [47:0]  adc_data_int  = 'd0;
  reg             adc_status_int= 'd0;

  reg             adc_valid     = 'd0;
  reg     [47:0]  adc_data      = 'd0;
  reg             adc_status    = 'd0;

  // ---------------------------------------------------------------------------
  // TX path scheduling and crossing registers
  // ---------------------------------------------------------------------------
  reg     [ 2:0]  tx_data_cnt   = 'd0;
  reg     [47:0]  tx_data       = 'd0;
  reg             tx_frame      = 'd0;
  reg     [ 5:0]  tx_data_p     = 'd0;
  reg     [ 5:0]  tx_data_n     = 'd0;

  reg             tx_n_frame    = 'd0;
  reg     [ 5:0]  tx_n_data_p   = 'd0;
  reg     [ 5:0]  tx_n_data_n   = 'd0;

  reg             tx_p_frame    = 'd0;
  reg     [ 5:0]  tx_p_data_p   = 'd0;
  reg     [ 5:0]  tx_p_data_n   = 'd0;

  // ---------------------------------------------------------------------------
  // Delay control registers
  // ---------------------------------------------------------------------------
  reg     [ 6:0]  delay_ld      = 'd0;
  reg     [ 4:0]  delay_rdata   = 'd0;
  reg             delay_ack_t   = 'd0;

  // ===========================================================================
  // Internal wires
  // ===========================================================================

  // RX frame history used by pattern detection
  wire    [ 3:0]  rx_frame_s;

  // TX selector
  wire    [ 3:0]  tx_data_sel_s;

  // Delay readback for 6 data lanes + 1 frame lane
  wire    [ 4:0]  delay_rdata_s[6:0];

  // DDR-decomposed RX data/frame from ad_lvds_in
  wire    [ 5:0]  rx_data_p_s;
  wire    [ 5:0]  rx_data_n_s;
  wire            rx_frame_p_s;
  wire            rx_frame_n_s;

  // Device interface clock from rx_clk_in_p/n
  wire            l_clk;

  genvar          l_inst;

  // ===========================================================================
  // Debug bus mapping
  // ===========================================================================

  assign dev_dbg_data[  5:  0] = tx_data_n;
  assign dev_dbg_data[ 11:  6] = tx_data_p;
  assign dev_dbg_data[ 23: 12] = dac_data[11: 0];
  assign dev_dbg_data[ 35: 24] = dac_data[23:12];
  assign dev_dbg_data[ 47: 36] = dac_data[35:24];
  assign dev_dbg_data[ 59: 48] = dac_data[47:36];
  assign dev_dbg_data[ 71: 60] = adc_data[11: 0];
  assign dev_dbg_data[ 83: 72] = adc_data[23:12];
  assign dev_dbg_data[ 95: 84] = adc_data[35:24];
  assign dev_dbg_data[107: 96] = adc_data[47:36];
  assign dev_dbg_data[108:108] = tx_frame;
  assign dev_dbg_data[109:109] = dac_valid;
  assign dev_dbg_data[110:110] = adc_status;
  assign dev_dbg_data[111:111] = adc_valid;

  assign dev_l_dbg_data[  5:  0] = tx_p_data_n;
  assign dev_l_dbg_data[ 11:  6] = tx_p_data_p;
  assign dev_l_dbg_data[ 23: 12] = adc_p_data[11: 0];
  assign dev_l_dbg_data[ 35: 24] = adc_p_data[23:12];
  assign dev_l_dbg_data[ 47: 36] = adc_p_data[35:24];
  assign dev_l_dbg_data[ 59: 48] = adc_p_data[47:36];
  assign dev_l_dbg_data[ 60: 60] = tx_p_frame;
  assign dev_l_dbg_data[ 61: 61] = adc_p_valid;

  // ===========================================================================
  // RX path : capture DDR-decomposed data/frame in l_clk domain
  // ===========================================================================

  assign rx_frame_s = {rx_frame_d, rx_frame};

  always @(posedge l_clk) begin
    rx_data   <= {rx_data_n_s,  rx_data_p_s};
    rx_frame  <= {rx_frame_n_s, rx_frame_p_s};
    rx_data_d <= rx_data;
    rx_frame_d<= rx_frame;
  end

  // ===========================================================================
  // RX path : single-RF mode decode
  // Frame is expected to qualify I/Q MSB only
  // Valid pattern  : 1100
  // No-error paths : 1100 / 0011
  // ===========================================================================

  always @(posedge l_clk) begin
    rx_error_r1 <= ((rx_frame_s == 4'b1100) || (rx_frame_s == 4'b0011)) ? 1'b0 : 1'b1;
    rx_valid_r1 <= (rx_frame_s == 4'b1100) ? 1'b1 : 1'b0;

    if (rx_frame_s == 4'b1100) begin
      rx_data_r1[11: 0] <= {rx_data_d[11:6], rx_data[11:6]};
      rx_data_r1[23:12] <= {rx_data_d[ 5:0], rx_data[ 5:0]};
    end
  end

  // ===========================================================================
  // RX path : dual-RF mode decode
  // Frame is expected to qualify I/Q MSB and LSB for RF-1 only
  // Valid output timing : 0000
  // No-error paths      : 1111 / 1100 / 0000 / 0011
  // ===========================================================================

  always @(posedge l_clk) begin
    rx_error_r2 <= ((rx_frame_s == 4'b1111) || (rx_frame_s == 4'b1100) ||
                    (rx_frame_s == 4'b0000) || (rx_frame_s == 4'b0011)) ? 1'b0 : 1'b1;
    rx_valid_r2 <= (rx_frame_s == 4'b0000) ? 1'b1 : 1'b0;

    if (rx_frame_s == 4'b1111) begin
      rx_data_r2[11: 0] <= {rx_data_d[11:6], rx_data[11:6]};
      rx_data_r2[23:12] <= {rx_data_d[ 5:0], rx_data[ 5:0]};
    end

    if (rx_frame_s == 4'b0000) begin
      rx_data_r2[35:24] <= {rx_data_d[11:6], rx_data[11:6]};
      rx_data_r2[47:36] <= {rx_data_d[ 5:0], rx_data[ 5:0]};
    end
  end

  // ===========================================================================
  // RX path : mode select mux in l_clk domain
  // adc_r1_mode = 1 : output R1 format, zero-extend to 48 bits
  // adc_r1_mode = 0 : output R2 format, full 48 bits
  // ===========================================================================

  always @(posedge l_clk) begin
    if (adc_r1_mode == 1'b1) begin
      adc_p_valid  <= rx_valid_r1;
      adc_p_data   <= {24'd0, rx_data_r1};
      adc_p_status <= ~rx_error_r1;
    end else begin
      adc_p_valid  <= rx_valid_r2;
      adc_p_data   <= rx_data_r2;
      adc_p_status <= ~rx_error_r2;
    end
  end

  // ===========================================================================
  // RX path : transfer to synchronous common clk domain
  // Original design keeps:
  //   l_clk posedge result -> l_clk negedge staging -> clk posedge sync
  // ===========================================================================

  always @(negedge l_clk) begin
    adc_n_valid  <= adc_p_valid;
    adc_n_data   <= adc_p_data;
    adc_n_status <= adc_p_status;
  end

  always @(posedge clk) begin
    adc_valid_int  <= adc_n_valid;
    adc_data_int   <= adc_n_data;
    adc_status_int <= adc_n_status;

    adc_valid <= adc_valid_int;
    if (adc_valid_int == 1'b1) begin
      adc_data <= adc_data_int;
    end
    adc_status <= adc_status_int;
  end

  // ===========================================================================
  // TX path : mux / schedule
  // Reverse of receive-side packing.
  // tx_data_cnt controls which segment is driven out on DDR outputs.
  // ===========================================================================

  assign tx_data_sel_s = {tx_data_cnt[2], dac_r1_mode, tx_data_cnt[1:0]};

  always @(posedge clk) begin
    if (dac_valid == 1'b1) begin
      tx_data_cnt <= 3'b100;
    end else if (tx_data_cnt[2] == 1'b1) begin
      tx_data_cnt <= tx_data_cnt + 1'b1;
    end

    if (dac_valid == 1'b1) begin
      tx_data <= dac_data;
    end

    case (tx_data_sel_s)
      4'b1111: begin
        tx_frame  <= 1'b0;
        tx_data_p <= tx_data[ 5: 0];
        tx_data_n <= tx_data[17:12];
      end
      4'b1110: begin
        tx_frame  <= 1'b1;
        tx_data_p <= tx_data[11: 6];
        tx_data_n <= tx_data[23:18];
      end
      4'b1101: begin
        tx_frame  <= 1'b0;
        tx_data_p <= tx_data[ 5: 0];
        tx_data_n <= tx_data[17:12];
      end
      4'b1100: begin
        tx_frame  <= 1'b1;
        tx_data_p <= tx_data[11: 6];
        tx_data_n <= tx_data[23:18];
      end
      4'b1011: begin
        tx_frame  <= 1'b0;
        tx_data_p <= tx_data[29:24];
        tx_data_n <= tx_data[41:36];
      end
      4'b1010: begin
        tx_frame  <= 1'b0;
        tx_data_p <= tx_data[35:30];
        tx_data_n <= tx_data[47:42];
      end
      4'b1001: begin
        tx_frame  <= 1'b1;
        tx_data_p <= tx_data[ 5: 0];
        tx_data_n <= tx_data[17:12];
      end
      4'b1000: begin
        tx_frame  <= 1'b1;
        tx_data_p <= tx_data[11: 6];
        tx_data_n <= tx_data[23:18];
      end
      default: begin
        tx_frame  <= 1'b0;
        tx_data_p <= 6'd0;
        tx_data_n <= 6'd0;
      end
    endcase
  end

  // ===========================================================================
  // TX path : transfer from clk domain to l_clk domain
  // Original design keeps:
  //   clk posedge result -> clk negedge staging -> l_clk posedge sync
  // ===========================================================================

  always @(negedge clk) begin
    tx_n_frame  <= tx_frame;
    tx_n_data_p <= tx_data_p;
    tx_n_data_n <= tx_data_n;
  end

  always @(posedge l_clk) begin
    tx_p_frame  <= tx_n_frame;
    tx_p_data_p <= tx_n_data_p;
    tx_p_data_n <= tx_n_data_n;
  end

  // ===========================================================================
  // Delay write interface
  // Each delay element can be individually addressed.
  // Delay value is directly loaded (no inc/dec protocol here).
  // Lane map:
  //   0~5 : rx_data lanes
  //   6   : rx_frame lane
  // ===========================================================================

  always @(posedge delay_clk) begin
    if ((delay_sel == 1'b1) && (delay_rwn == 1'b0)) begin
      case (delay_addr)
        8'h06: delay_ld <= 7'h40;
        8'h05: delay_ld <= 7'h20;
        8'h04: delay_ld <= 7'h10;
        8'h03: delay_ld <= 7'h08;
        8'h02: delay_ld <= 7'h04;
        8'h01: delay_ld <= 7'h02;
        8'h00: delay_ld <= 7'h01;
        default: delay_ld <= 7'h00;
      endcase
    end else begin
      delay_ld <= 7'h00;
    end
  end

  // ===========================================================================
  // Delay read interface
  // delay_ack_t toggles on access; delay_locked is independently exported.
  // ===========================================================================

  always @(posedge delay_clk) begin
    case (delay_addr)
      8'h06: delay_rdata <= delay_rdata_s[6];
      8'h05: delay_rdata <= delay_rdata_s[5];
      8'h04: delay_rdata <= delay_rdata_s[4];
      8'h03: delay_rdata <= delay_rdata_s[3];
      8'h02: delay_rdata <= delay_rdata_s[2];
      8'h01: delay_rdata <= delay_rdata_s[1];
      8'h00: delay_rdata <= delay_rdata_s[0];
      default: delay_rdata <= 5'd0;
    endcase

    if (delay_sel == 1'b1) begin
      delay_ack_t <= ~delay_ack_t;
    end
  end

  // ===========================================================================
  // RX LVDS input instances
  // data path : IBUF -> IDELAY -> IDDR
  // ===========================================================================

  generate
  for (l_inst = 0; l_inst <= 5; l_inst = l_inst + 1) begin: g_rx_data
    //  ad_lvds_in #(
    //    .BUFTYPE      (PCORE_DEVICE_TYPE),
    //    .IODELAY_CTRL (0),
    //    .IODELAY_GROUP(PCORE_IODELAY_GROUP))
    ad_lvds_in i_rx_data (
      .rx_clk       (l_clk),
      .rx_data_in_p (rx_data_in_p[l_inst]),
      .rx_data_in_n (rx_data_in_n[l_inst]),
      .rx_data_p    (rx_data_p_s[l_inst]),
      .rx_data_n    (rx_data_n_s[l_inst]),
      .delay_clk    (delay_clk),
      .delay_rst    (delay_rst),
      .delay_ld     (delay_ld[l_inst]),
      .delay_wdata  (delay_wdata),
      .delay_rdata  (delay_rdata_s[l_inst]),
      .delay_locked ()
    );
  end
  endgenerate

  // ===========================================================================
  // RX LVDS frame input instance
  // ===========================================================================

  //  ad_lvds_in #(
  //    .BUFTYPE      (PCORE_DEVICE_TYPE),
  //    .IODELAY_CTRL (1),
  //    .IODELAY_GROUP(PCORE_IODELAY_GROUP))
  ad_lvds_in i_rx_frame (
    .rx_clk       (l_clk),
    .rx_data_in_p (rx_frame_in_p),
    .rx_data_in_n (rx_frame_in_n),
    .rx_data_p    (rx_frame_p_s),
    .rx_data_n    (rx_frame_n_s),
    .delay_clk    (delay_clk),
    .delay_rst    (delay_rst),
    .delay_ld     (delay_ld[6]),
    .delay_wdata  (delay_wdata),
    .delay_rdata  (delay_rdata_s[6]),
    .delay_locked (delay_locked)
  );

  // ===========================================================================
  // TX LVDS output instances
  // data / frame / forwarded clock : ODDR -> OBUF
  // ===========================================================================

  generate
  for (l_inst = 0; l_inst <= 5; l_inst = l_inst + 1) begin: g_tx_data
    ad_lvds_out #(
      .BUFTYPE (PCORE_DEVICE_TYPE)
    ) i_tx_data (
      .tx_clk      (l_clk),
      .tx_data_p   (tx_p_data_p[l_inst]),
      .tx_data_n   (tx_p_data_n[l_inst]),
      .tx_data_out_p (tx_data_out_p[l_inst]),
      .tx_data_out_n (tx_data_out_n[l_inst]) 
    );
  end
  endgenerate

  ad_lvds_out #(
    .BUFTYPE (PCORE_DEVICE_TYPE)
  ) i_tx_frame (
    .tx_clk       (l_clk),
    .tx_data_p    (tx_p_frame),
    .tx_data_n    (tx_p_frame),
    .tx_data_out_p(tx_frame_out_p),
    .tx_data_out_n(tx_frame_out_n)
  );

  ad_lvds_out #(
    .BUFTYPE (PCORE_DEVICE_TYPE)
  ) i_tx_clk (
    .tx_clk       (l_clk),
    .tx_data_p    (1'b0),
    .tx_data_n    (1'b1),
    .tx_data_out_p(tx_clk_out_p),
    .tx_data_out_n(tx_clk_out_n)
  );

  // ===========================================================================
  // Device interface clock instance
  // l_clk is derived from the incoming RX LVDS clock.
  // ===========================================================================

  ad_lvds_clk #(
    .BUFTYPE (PCORE_DEVICE_TYPE)
  ) i_clk (
    .clk_in_p (rx_clk_in_p),
    .clk_in_n (rx_clk_in_n),
    .clk      (l_clk)
  );


endmodule