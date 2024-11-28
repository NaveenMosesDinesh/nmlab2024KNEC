module tb_top();

  // parameters
  parameter RESET_PERIOD = 2;
  parameter CLOCK_PERIOD = 10;

  // local variables
  logic clk;
  logic rst_n;
  logic valid_i;
  logic[1:0] customer_sel;
  logic customer_A_out;
  logic customer_B_out;
  logic customer_C_out;
  bit[1:0] exp_q[$], act_q[$];

  // DUT instantiation
  customer_based_car_distr i_dut(
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .customer_sel(customer_sel),
    .customer_A_out(customer_A_out),
    .customer_B_out(customer_B_out),
    .customer_C_out(customer_C_out)
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
    customer_sel = 'bx;
  endfunction

  // drive input stimulus
  task drive_input(int trans_count);
    @(posedge clk);
    repeat(trans_count) begin
      #1;
      valid_i = 1;
      customer_sel = $urandom_range(0, 2);
      @(posedge clk);
    end
    #1;
    reset_input_signals();
  endtask

  // monitor input stimulus
  task ip_monitor();
    forever begin
      if (valid_i) begin
        if (customer_sel == 0) exp_q.push_back(0);
        else if (customer_sel == 1) exp_q.push_back(1);
        else exp_q.push_back(2);
      end
      @(posedge clk);
    end
  endtask

  // monitor output from DUT
  task op_monitor();
    forever begin
      if (customer_A_out || customer_B_out || customer_C_out) begin
        if (customer_A_out) act_q.push_back(0);
        else if (customer_B_out) act_q.push_back(1);
        else act_q.push_back(2);
      end
      @(posedge clk);
    end
  endtask

  // check expected and actual data
  task check_exp_and_act();
    bit[1:0] exp, act;
    forever begin
      if (act_q.size() >= 1) begin
        if (exp_q.size() == 0) $error("Unexpected output given by DUT");
        else begin
          exp = exp_q.pop_front();
          act = act_q.pop_front();
          if (act == exp) $display("Exp data %0d Act data %0d match", exp, act);
          else $error("Exp data %0d Act data %0d don't match", exp, act);
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