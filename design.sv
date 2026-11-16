// ============================================================
//  Sobel Edge Detection Accelerator  (Verilog)
//  sobel_core : computes edge strength for one 3x3 window
//  sobel_top  : streams pixels in, builds 3x3 windows with
//               two line buffers, outputs one edge pixel/clock
// ============================================================

module sobel_core(
  input  [7:0] p0, p1, p2,      // top row    of 3x3 window
  input  [7:0] p3, p4, p5,      // middle row
  input  [7:0] p6, p7, p8,      // bottom row
  output [7:0] edge_val         // edge strength 0..255
);
  // Gx kernel: [-1 0 +1; -2 0 +2; -1 0 +1]  (vertical edges)
  wire [9:0] gx_pos = p2 + (p5 << 1) + p8;
  wire [9:0] gx_neg = p0 + (p3 << 1) + p6;
  // Gy kernel: [-1 -2 -1; 0 0 0; +1 +2 +1]  (horizontal edges)
  wire [9:0] gy_pos = p6 + (p7 << 1) + p8;
  wire [9:0] gy_neg = p0 + (p1 << 1) + p2;

  // |Gx| and |Gy| without signed maths
  wire [9:0] abs_gx = (gx_pos > gx_neg) ? gx_pos - gx_neg : gx_neg - gx_pos;
  wire [9:0] abs_gy = (gy_pos > gy_neg) ? gy_pos - gy_neg : gy_neg - gy_pos;

  // magnitude ~ |Gx| + |Gy|, clipped to 255
  wire [10:0] mag = abs_gx + abs_gy;
  assign edge_val = (mag > 255) ? 8'd255 : mag[7:0];
endmodule


module sobel_top #(parameter W = 16)(   // W = image width
  input            clk,
  input            rst,
  input            valid_in,            // 1 when pix_in is a real pixel
  input      [7:0] pix_in,              // pixels arrive row by row
  output reg       valid_out,           // 1 when pix_out is valid
  output     [7:0] pix_out
);
  reg [7:0] row1 [0:W-1];               // line buffer: previous row
  reg [7:0] row2 [0:W-1];               // line buffer: two rows back
  reg [7:0] w0,w1,w2,w3,w4,w5,w6,w7,w8; // 3x3 sliding window
  integer col, rowc;

  sobel_core core(.p0(w0),.p1(w1),.p2(w2),
                  .p3(w3),.p4(w4),.p5(w5),
                  .p6(w6),.p7(w7),.p8(w8),
                  .edge_val(pix_out));

  always @(posedge clk) begin
    if (rst) begin
      col <= 0; rowc <= 0; valid_out <= 0;
    end else begin
      // output is valid once the window is fully inside the image
      valid_out <= valid_in && (rowc >= 2) && (col >= 2);
      if (valid_in) begin
        // shift window left, bring in new column on the right
        w0 <= w1; w1 <= w2; w2 <= row2[col];
        w3 <= w4; w4 <= w5; w5 <= row1[col];
        w6 <= w7; w7 <= w8; w8 <= pix_in;
        // update line buffers
        row2[col] <= row1[col];
        row1[col] <= pix_in;
        // move to next pixel position
        if (col == W-1) begin col <= 0; rowc <= rowc + 1; end
        else            col <= col + 1;
      end
    end
  end
endmodule
