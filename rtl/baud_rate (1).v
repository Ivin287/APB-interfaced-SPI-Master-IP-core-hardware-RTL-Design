//=====================================================================
// Module  : baud_rate
// Project : APB interfaced SPI Master IP core (RTL design)
// Purpose : Divides PCLK down to SCLK, and produces one-cycle strobes
//           that tell the shift registers WHEN to sample MISO and
//           WHEN to drive a new MOSI bit.
//
// Notes in this file use three tags:
//   LEARNING : something worth understanding about the block
//   PITFALL  : an easy mistake (several appear in earlier versions of
//              this code) and how it was fixed
//   DOUBT    : something to re-check against the spec / slides / waveform
// Edit them freely and add your own experience, for example what the
// waveform looked like when something failed and how you found the cause.
//
// NOTE: this file has not been compiled or simulated by the person who
//       wrote these comments. Run it in your simulator before committing.
//=====================================================================
module baud_rate (
    pclk, preset_n,
    spi_mode, spiswai,
    sprr, spr,
    cpol, cpha, ss,
    sclk,
    miso_rcv_pos, miso_rcv_neg,
    mosi_snd_pos, mosi_snd_neg,
    baudratedivisor
);

  input        pclk, preset_n;     // preset_n : active-low ASYNC reset
  input        spiswai;            // stop SPI clock in wait mode
  input        cpol, cpha;         // SPI clock polarity / phase
  input        ss;                 // slave select, active low
  input  [1:0] spi_mode;           // 00 = run, 01 = wait, 10 = stop
  input  [2:0] sprr, spr;          // baud-rate selection fields

  output reg   sclk;               // generated serial clock
  output reg   miso_rcv_pos, miso_rcv_neg;   // "sample MISO now" strobes
  output reg   mosi_snd_pos, mosi_snd_neg;   // "drive MOSI now"  strobes
  output [11:0] baudratedivisor;

  // LEARNING: 12 bits is enough for the divisor and the counter.
  //   Max divisor = (7+1) * 2^(7+1) = 2048, and the counter only counts
  //   up to divisor/2 - 1 = 1023.
  // PITFALL: an earlier version declared count as [12:0] but reset it with
  //   12'd0 and cleared it with 13'd0. It is legal Verilog, but mixing
  //   widths is confusing. The microarchitecture slides use a 12-bit count.
  reg  [11:0] count;

  wire        pre_sclk;            // idle level of SCLK
  wire        enable;              // clock is allowed to run
  wire        edge_sel;            // 1 : CPOL != CPHA
  wire [11:0] miso_cmp, mosi_cmp;  // compare values for the strobes
  wire        miso_match, mosi_match;

  //-------------------------------------------------------------------
  // Baud rate divisor
  //   SCLK frequency = PCLK / baudratedivisor
  //-------------------------------------------------------------------
  // LEARNING: (sprr+1) * 2^(spr+1). 2^(spr+1) is at least 2, so the
  //   divisor is ALWAYS EVEN. That is what makes a 50 % duty-cycle SCLK
  //   possible: each half period is exactly divisor/2 PCLK cycles.
  // DOUBT (common worry): can (sprr+1) overflow 3 bits when sprr = 7?
  //   No. Verilog sizes the expression to the widest operand (the 12-bit
  //   output and the 32-bit unsized constants), so 7+1 = 8 is safe.
  assign baudratedivisor = (sprr + 1) * (2 ** (spr + 1));

  // Idle level of SCLK follows CPOL (the 0/1 mux on the slide is just cpol).
  assign pre_sclk = cpol;

  //-------------------------------------------------------------------
  // Enable : SCLK and the counter may run
  //-------------------------------------------------------------------
  // PITFALL (precedence): the original line was
  //     (mode==0) || (mode==1 && !spiswai) && (!ss)
  //   In Verilog && binds tighter than ||, so this parses as
  //     (mode==0) || ((mode==1 && !spiswai) && !ss)
  //   which means RUN mode ignored ss and the clock ran with no slave
  //   selected. Rule: whenever || and && are mixed, add parentheses.
  // LEARNING: the microarchitecture slide (OR of the two mode compares,
  //   ANDed with !ss and !spiswai) is the reference for this expression.
  // DOUBT: on the slide !spiswai is ANDed for BOTH modes, not only for
  //   wait mode. Confirm this against your SPI specification.
  assign enable = ((spi_mode == 2'b00) || (spi_mode == 2'b01))
                  && !ss && !spiswai;

  //-------------------------------------------------------------------
  // Compare values (counter starts at 0, so the last count of a half
  // period is divisor/2 - 1)
  //-------------------------------------------------------------------
  // LEARNING: because the divisor is even, (divisor-1)/2 (the slide's
  //   form, with integer division) equals divisor/2 - 1. Example, divisor 8:
  //   (8-1)/2 = 3 and 8/2 - 1 = 3. The counter runs 0,1,2,3 = 4 cycles
  //   = one half period, then SCLK toggles.
  assign miso_cmp = (baudratedivisor >> 1) - 12'd1;

  // MOSI strobes fire one PCLK cycle earlier than the MISO strobes.
  // PITFALL: "-2'b10" is the number 2 written in binary, not "minus
  //   one-zero". It reads very easily as a typo; plain 12'd2 is clearer.
  // DOUBT: this is divisor/2 - 2. The slide for the MOSI strobe shows
  //   (BaudRateDivisor - 2'b10) / 2 which would be divisor/2 - 1, one
  //   count later. The photo is hard to read and a handwritten "4"
  //   (divisor example?) sits next to it. Check which one your spec and
  //   testbench expect before finalising.
  // PITFALL (corner case): with divisor = 2 this value wraps to 4095 (12-bit),
  //   so the MOSI strobes never fire. Avoid divisor = 2 or special-case it.
  assign mosi_cmp = (baudratedivisor >> 1) - 12'd2;

  assign miso_match = (count == miso_cmp);
  assign mosi_match = (count == mosi_cmp);

  // LEARNING: CPOL != CPHA (modes 1 and 2) -> MISO sampled on the FALLING
  //   edge, MOSI changes on the RISING edge.
  //   CPOL == CPHA (modes 0 and 3)           -> MISO sampled on the RISING
  //   edge, MOSI changes on the FALLING edge.
  //   The slide's AND/AND/OR gates are just an XOR of cpol and cpha.
  assign edge_sel = cpol ^ cpha;

  //-------------------------------------------------------------------
  // SCLK generation and counter
  //-------------------------------------------------------------------
  // LEARNING: SCLK toggles every divisor/2 PCLK cycles, so one full SCLK
  //   period = divisor PCLK cycles.
  // PITFALL (idle behaviour): an earlier version only HELD sclk and count
  //   when disabled. The slides show a second mux (select = enable) that
  //   forces count to 0 and sclk to pre_sclk when disabled. Without this,
  //   an aborted transfer leaves a partial count and SCLK stuck at the
  //   wrong level, and a CPOL change is never picked up.
  always @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      sclk  <= pre_sclk;
      count <= 12'd0;
    end
    else if (enable) begin
      if (count == miso_cmp) begin
        sclk  <= ~sclk;
        count <= 12'd0;
      end
      else begin
        count <= count + 12'd1;
      end
    end
    else begin
      sclk  <= pre_sclk;
      count <= 12'd0;
    end
  end

  //-------------------------------------------------------------------
  // MISO "sample now" and MOSI "drive now" strobes
  //-------------------------------------------------------------------
  // LEARNING: the strobes are registered, so they are high for exactly
  //   one PCLK cycle.
  //   MISO strobe: set at the same PCLK edge where SCLK toggles, so it is
  //     high in the first cycle AFTER the SCLK edge.
  //   MOSI strobe: set one cycle earlier, so it is high in the last cycle
  //     BEFORE the SCLK edge and the shift register can update MOSI
  //     right at the edge.
  // PITFALL (stale values): in an earlier version only one of the two
  //   strobes in each pair was assigned per branch, so the other kept an
  //   old value if CPOL/CPHA changed. Now every strobe gets a default of
  //   0 first; the branch below overrides only the one that is needed.
  // PITFALL (MOSI condition): an earlier version used the SAME condition
  //   (cpol != cpha) for MOSI as for MISO, so MOSI changed at the sampling
  //   edge. MOSI must use the opposite edge, as below.
  // DOUBT: the strobes are not gated by enable (the slides do not gate
  //   them). When idle, count = 0, so a compare value of 0 (MOSI strobe
  //   with divisor 4) can assert a strobe while no transfer is running.
  //   The shift register must ignore strobes when not transferring.
  always @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      miso_rcv_pos <= 1'b0;
      miso_rcv_neg <= 1'b0;
      mosi_snd_pos <= 1'b0;
      mosi_snd_neg <= 1'b0;
    end
    else begin
      miso_rcv_pos <= 1'b0;
      miso_rcv_neg <= 1'b0;
      mosi_snd_pos <= 1'b0;
      mosi_snd_neg <= 1'b0;

      if (edge_sel) begin
        // CPOL != CPHA : sample on falling edge, change MOSI on rising edge
        miso_rcv_neg <=  sclk && miso_match;   // SCLK high, about to fall
        mosi_snd_pos <= !sclk && mosi_match;   // SCLK low,  about to rise
      end
      else begin
        // CPOL == CPHA : sample on rising edge, change MOSI on falling edge
        miso_rcv_pos <= !sclk && miso_match;   // SCLK low,  about to rise
        mosi_snd_neg <=  sclk && mosi_match;   // SCLK high, about to fall
      end
    end
  end

endmodule
