module tb_top();

  // parameters
  parameter RESET_PERIOD = 2;
  parameter CLOCK_PERIOD = 10;

  // local variables
  logic clk;
  logic rst_n;
  logic valid_i;
  logic[7:0] height;
  logic[7:0] weight;
  logic valid_o;
  logic[5:0] bmi_ratio;
  logic[1:0] hc_indicator;
  bit[5:0] exp_bmi_ratio_q[$], act_bmi_ratio_q[$];
  bit[1:0] exp_hc_indicator_q[$], act_hc_indicator_q[$];

  // DUT instantiation
  health_mon_sys i_dut(
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .height(height),
    .weight(weight),
    .valid_o(valid_o),
    .bmi_ratio(bmi_ratio),
    .hc_indicator(hc_indicator)
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
    height = 'bx;
    weight = 'bx;
  endfunction

  // drive input stimulus
  task drive_input(int trans_count);
    @(posedge clk);
    repeat(trans_count) begin
      #1;
      valid_i = 1;
      height = $urandom_range(55, 255);  // Height in cm
      weight = $urandom_range(10, 255); // Weight in kg
      @(posedge clk);
    end
    #1;
    reset_input_signals();
  endtask

  // monitor input stimulus
  task ip_monitor();
    bit[5:0] expected_bmi_ratio_l;
    forever begin
      if (valid_i) begin
        expected_bmi_ratio_l = (weight * 10000) / (height * height); // BMI formula
        exp_bmi_ratio_q.push_back(expected_bmi_ratio_l);

        // Determine health condition based on BMI ratio
        if ((expected_bmi_ratio_l >= 5) && (expected_bmi_ratio_l <= 18))
          exp_hc_indicator_q.push_back(0); // Underweight
        else if ((expected_bmi_ratio_l >= 19) && (expected_bmi_ratio_l <= 25))
          exp_hc_indicator_q.push_back(1); // Normal
        else if ((expected_bmi_ratio_l >= 26) && (expected_bmi_ratio_l <= 30))
          exp_hc_indicator_q.push_back(2); // Overweight
        else if (expected_bmi_ratio_l >= 31)
          exp_hc_indicator_q.push_back(3); // Obese
      end
      @(posedge clk);
    end
  endtask

  // monitor output from DUT
  task op_monitor();
    forever begin
      if (valid_o) begin
        act_bmi_ratio_q.push_back(bmi_ratio);
        act_hc_indicator_q.push_back(hc_indicator);
      end
      @(posedge clk);
    end
  endtask

  // check expected and actual data
  task check_exp_and_act();
    bit[1:0] exp_hc_indicator, act_hc_indicator;
    bit[5:0] exp_bmi_ratio, act_bmi_ratio;
    forever begin
      if (act_hc_indicator_q.size() >= 1 && act_bmi_ratio_q.size() >= 1) begin
        if (exp_hc_indicator_q.size() == 0 || exp_bmi_ratio_q.size() == 0)
          $error("Unexpected output given by DUT");
        else begin
          exp_hc_indicator = exp_hc_indicator_q.pop_front();
          act_hc_indicator = act_hc_indicator_q.pop_front();
          exp_bmi_ratio = exp_bmi_ratio_q.pop_front();
          act_bmi_ratio = act_bmi_ratio_q.pop_front();

          if (exp_bmi_ratio == act_bmi_ratio)
            $display("Exp BMI %0d Act BMI %0d match", exp_bmi_ratio, act_bmi_ratio);
          else
            $error("Exp BMI %0d Act BMI %0d don't match", exp_bmi_ratio, act_bmi_ratio);

          if (exp_hc_indicator == act_hc_indicator)
            $display("Exp HC %0d Act HC %0d match", exp_hc_indicator, act_hc_indicator);
          else
            $error("Exp HC %0d Act HC %0d don't match", exp_hc_indicator, act_hc_indicator);
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