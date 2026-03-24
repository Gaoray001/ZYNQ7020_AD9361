module AD_CLK_PLL_PRIM (
    input  wire clk_in,
    input  wire rst_n_in,

    output wire clk_48M,
    output wire clk_200M,
    output wire clk_10M,
    output wire locked
);

    //====================================================
    // 1. 输入时钟缓冲
    //====================================================
    wire clk_in_bufg;

    BUFG u_bufg_in (
        .I(clk_in),
        .O(clk_in_bufg)
    );

    //====================================================
    // 2. PLL 反馈与输出中间信号
    //====================================================
    wire clkfb;
    wire clkfb_buf;

    wire pll_clk0;   // 48 MHz
    wire pll_clk1;   // 200 MHz
    wire pll_clk2;   // 10 MHz

    //====================================================
    // 3. PLL 主体
    //
    // 输入: 100 MHz
    // VCO = 100 * 12 / 1 = 1200 MHz
    // clk_48M  = 1200 /  25 = 48 MHz
    // clk_200M = 1200 /   6 = 200 MHz
    // clk_10M  = 1200 / 120 = 10 MHz
    //====================================================
    PLLE2_ADV #(
        .BANDWIDTH("OPTIMIZED"),
        .COMPENSATION("ZHOLD"),
        .STARTUP_WAIT("FALSE"),

        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT(12),
        .CLKFBOUT_PHASE(0.0),

        .CLKOUT0_DIVIDE(25),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT0_DUTY_CYCLE(0.5),

        .CLKOUT1_DIVIDE(6),
        .CLKOUT1_PHASE(0.0),
        .CLKOUT1_DUTY_CYCLE(0.5),

        .CLKOUT2_DIVIDE(120),
        .CLKOUT2_PHASE(0.0),
        .CLKOUT2_DUTY_CYCLE(0.5),

        .CLKOUT3_DIVIDE(1),
        .CLKOUT3_PHASE(0.0),
        .CLKOUT3_DUTY_CYCLE(0.5),

        .CLKOUT4_DIVIDE(1),
        .CLKOUT4_PHASE(0.0),
        .CLKOUT4_DUTY_CYCLE(0.5),

        .CLKOUT5_DIVIDE(1),
        .CLKOUT5_PHASE(0.0),
        .CLKOUT5_DUTY_CYCLE(0.5),

        .REF_JITTER1(0.010),
        .CLKIN1_PERIOD(10.000)
    ) u_pll (
        .CLKIN1   (clk_in_bufg),
        .CLKIN2   (1'b0),
        .CLKINSEL (1'b1),

        .RST      (~rst_n_in),

        .CLKFBIN  (clkfb_buf),
        .CLKFBOUT (clkfb),

        .CLKOUT0  (pll_clk0),
        .CLKOUT1  (pll_clk1),
        .CLKOUT2  (pll_clk2),
        .CLKOUT3  (),
        .CLKOUT4  (),
        .CLKOUT5  (),

        .LOCKED   (locked)
    );

    //====================================================
    // 4. PLL 反馈路径
    //====================================================
    BUFG u_bufg_fb (
        .I(clkfb),
        .O(clkfb_buf)
    );

    //====================================================
    // 5. 输出全局缓冲
    //====================================================
    BUFG u_bufg_out0 (
        .I(pll_clk0),
        .O(clk_48M)
    );

    BUFG u_bufg_out1 (
        .I(pll_clk1),
        .O(clk_200M)
    );

    BUFG u_bufg_out2 (
        .I(pll_clk2),
        .O(clk_10M)
    );

endmodule