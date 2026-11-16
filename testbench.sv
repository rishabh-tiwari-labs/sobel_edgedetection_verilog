// ============================================================
//  Testbench for Sobel accelerator
//  Test 1: checks sobel_core on known 3x3 patterns
//  Test 2: streams a 16x16 image (bright square on dark
//          background) and prints the edge map as ASCII art
// ============================================================
`timescale 1ns/1ps

module tb;
  localparam W = 16, H = 16;

  // ---------- Test 1 signals (core only) ----------
  reg  [7:0] q0,q1,q2,q3,q4,q5,q6,q7,q8;
  wire [7:0] core_out;
  integer errors = 0;

  sobel_core unit(.p0(q0),.p1(q1),.p2(q2),.p3(q3),.p4(q4),
                  .p5(q5),.p6(q6),.p7(q7),.p8(q8),.edge_val(core_out));

  task check(input [8*12-1:0] name, input [7:0] expected);
    begin
      #1;
      if (core_out === expected)
        $display("PASS  %0s : got %3d", name, core_out);
      else begin
        $display("FAIL  %0s : got %3d, expected %3d", name, core_out, expected);
        errors = errors + 1;
      end
    end
  endtask

  // ---------- Test 2 signals (full pipeline) ----------
  reg        clk = 0, rst = 1, valid_in = 0;
  reg  [7:0] pix_in;
  wire       valid_out;
  wire [7:0] pix_out;
  reg  [7:0] image [0:W*H-1];
  integer r, c, n = 0;

  sobel_top #(.W(W)) dut(.clk(clk), .rst(rst), .valid_in(valid_in),
                         .pix_in(pix_in), .valid_out(valid_out), .pix_out(pix_out));

  always #5 clk = ~clk;               // 100 MHz clock

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);

    // ===== Test 1: core =====
    $display("\n===== TEST 1: sobel_core =====");
    {q0,q1,q2,q3,q4,q5,q6,q7,q8} = {9{8'd100}};            check("flat area  ", 8'd0);
    {q0,q1,q2} = {8'd0,8'd0,8'd255};
    {q3,q4,q5} = {8'd0,8'd0,8'd255};
    {q6,q7,q8} = {8'd0,8'd0,8'd255};                       check("vert edge  ", 8'd255);
    {q0,q1,q2} = {8'd0,8'd0,8'd0};
    {q3,q4,q5} = {8'd0,8'd0,8'd0};
    {q6,q7,q8} = {8'd255,8'd255,8'd255};                   check("horiz edge ", 8'd255);
    {q0,q1,q2} = {8'd10,8'd20,8'd30};
    {q3,q4,q5} = {8'd10,8'd20,8'd30};
    {q6,q7,q8} = {8'd10,8'd20,8'd30};                      check("soft edge  ", 8'd80);

    // ===== Test 2: build input image =====
    for (r = 0; r < H; r = r + 1)
      for (c = 0; c < W; c = c + 1)
        image[r*W+c] = (r >= 4 && r < 12 && c >= 4 && c < 12) ? 8'd255 : 8'd20;

    $display("\n===== TEST 2: input image (# = bright, . = dark) =====");
    for (r = 0; r < H; r = r + 1) begin
      for (c = 0; c < W; c = c + 1)
        $write("%s", image[r*W+c] > 128 ? "# " : ". ");
      $write("\n");
    end

    $display("\n===== Edge map from sobel_top (%0dx%0d) =====", W-2, H-2);
    #12 rst = 0;
    for (r = 0; r < H; r = r + 1)
      for (c = 0; c < W; c = c + 1) begin
        @(negedge clk);
        valid_in = 1;
        pix_in   = image[r*W+c];
      end
    @(negedge clk) valid_in = 0;
    #50;

    $display("\nOutput pixels: %0d (expected %0d)", n, (W-2)*(H-2));
    if (errors == 0 && n == (W-2)*(H-2)) $display("ALL TESTS PASSED");
    else                                 $display("SOME TESTS FAILED");
    $finish;
  end

  // print each output pixel as ASCII art
  always @(posedge clk)
    if (valid_out) begin
      if      (pix_out > 200) $write("@ ");
      else if (pix_out > 100) $write("+ ");
      else if (pix_out > 0)   $write("- ");
      else                    $write(". ");
      n = n + 1;
      if (n % (W-2) == 0) $write("\n");
    end
endmodule
