module tb_top();

  // parameters
  parameter RESET_PERIOD = 2;
  parameter CLOCK_PERIOD = 10;

  // local variables
  logic clk;
  logic rst_n;
  logic valid_i;
  logic[6:0] goods_quality;
  logic valid_belt_a;
  logic[6:0] belt_a;
  logic valid_belt_b;
  logic[6:0] belt_b;
  bit[6:0] belt_a_exp_q[$], belt_b_exp_q[$];
  bit[6:0] belt_a_act_q[$], belt_b_act_q[$];

  // DUT instantiation
  goods_quality_ctrl i_dut(
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .goods_quality(goods_quality),
    .valid_belt_a(valid_belt_a),
    .belt_a(belt_a),
    .valid_belt_b(valid_belt_b),
    .belt_b(belt_b)
  );

  // clock generation
  task clock_generation();
    clk = 0;
    forever #(CLOCK_PERIOD / 2) clk = ~clk;
  endtask

  // reset generation
  task reset_generation();
    @(posedge clk);
    rst_n = 0;
    repeat(RESET_PERIOD) @(posedge clk);
    rst_n = 1;
  endtask

  // reset input signals
  function void reset_input_signals();
    valid_i = 'b0;
    goods_quality = 'bx;
  endfunction

  // drive input stimulus
  task drive_input(int trans_count);
    @(posedge clk);
    repeat(trans_count) begin
      #1;
      valid_i = 'b1;
      goods_quality = $urandom_range(0, 127);
      @(posedge clk);
    end
    #1;
    reset_input_signals();
  endtask

  // monitor input stimulus
  task ip_monitor();
    forever begin
      if (valid_i) begin
        if (goods_quality >= 61)
          belt_a_exp_q.push_back(goods_quality); // Belt A for higher quality
        else
          belt_b_exp_q.push_back(goods_quality); // Belt B for lower quality
      end
      @(posedge clk);
    end
  endtask

  // monitor output from DUT
  task op_monitor();
    forever begin
      if (valid_belt_a || valid_belt_b) begin
        if (valid_belt_a)
          belt_a_act_q.push_back(belt_a); // Capture Belt A output
        else
          belt_b_act_q.push_back(belt_b); // Capture Belt B output
      end
      @(posedge clk);
    end
  endtask

  // check expected and actual data
  task check_exp_and_act();
    bit[6:0] exp_a, act_a, exp_b, act_b;
    forever begin
      if (belt_a_act_q.size() >= 1 || belt_b_act_q.size() >= 1) begin
        if (belt_a_exp_q.size() == 0 && belt_b_exp_q.size() == 0)
          $error("Unexpected output from DUT");
        else begin
          if (belt_a_exp_q.size() != 0) begin
            exp_a = belt_a_exp_q.pop_front();
            act_a = belt_a_act_q.pop_front();
            if (exp_a == act_a)
              $display("Exp data %0d and Act data %0d match in belt A", exp_a, act_a);
            else
              $error("Exp data %0d and Act data %0d don't match in belt A", exp_a, act_a);
          end
          if (belt_b_exp_q.size() != 0) begin
            exp_b = belt_b_exp_q.pop_front();
            act_b = belt_b_act_q.pop_front();
            if (exp_b == act_b)
              $display("Exp data %0d and Act data %0d match in belt B", exp_b, act_b);
            else
              $error("Exp data %0d and Act data %0d don't match in belt B", exp_b, act_b);
          end
        end
      end
      @(posedge clk);
    end
  endtask

  initial begin
    clock_generation();
    reset_generation();
    drive_input(5);
    fork
      ip_monitor();
      op_monitor();
      check_exp_and_act();
    join
    #300;
    $finish;
  end

endmodule