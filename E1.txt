module tb_top();

  // parameters
  parameter RESET_PERIOD = 2;
  parameter CLOCK_PERIOD = 10;

  // local variables
  logic clk;
  logic rst_n;
  logic valid_i;
  logic[6:0] che_mark;
  logic[6:0] phy_mark;
  logic[6:0] mat_mark;
  logic valid_o;
  logic[6:0] cutoff;
  logic[1:0] department;
  bit [6:0] exp_cutoff_q[$], act_cutoff_q[$];
  bit [1:0] exp_dept_q[$], act_dept_q[$];

  // DUT instantiation
  cutoff_calculator i_dut(
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .che_mark(che_mark),
    .phy_mark(phy_mark),
    .mat_mark(mat_mark),
    .valid_o(valid_o),
    .cutoff(cutoff),
    .department(department)
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
    che_mark = 'bx;
    phy_mark = 'bx;
    mat_mark = 'bx;
  endfunction

  // drive input stimulus
  task drive_input(int trans_count);
    @(posedge clk);
    repeat(trans_count) begin
      #1;
      valid_i = 1;
      che_mark = $urandom_range(0, 100);
      phy_mark = $urandom_range(0, 100);
      mat_mark = $urandom_range(0, 100);
      @(posedge clk);
    end
    #1;
    reset_input_signals();
  endtask

  // monitor input stimulus
  task ip_monitor();
    forever begin
      if (valid_i) begin
        bit [6:0] exp_cutoff_data_l;
        exp_cutoff_data_l = (mat_mark + ((che_mark + phy_mark) / 2)) / 2;
        exp_cutoff_q.push_back(exp_cutoff_data_l);
        if (exp_cutoff_data_l > 90) exp_dept_q.push_back(0);
        else if (exp_cutoff_data_l > 80) exp_dept_q.push_back(1);
        else if (exp_cutoff_data_l > 60) exp_dept_q.push_back(2);
        else exp_dept_q.push_back(3);
      end
      @(posedge clk);
    end
  endtask

  // monitor output from DUT
  task op_monitor();
    forever begin
      if (valid_o) begin
        act_cutoff_q.push_back(cutoff);
        act_dept_q.push_back(department);
      end
      @(posedge clk);
    end
  endtask

  // check expected and actual data
  task check_exp_and_act();
    bit[6:0] exp_cutoff, act_cutoff;
    bit[1:0] exp_dept, act_dept;
    forever begin
      if (act_cutoff_q.size() >= 1 && act_dept_q.size() >= 1) begin
        if (exp_cutoff_q.size() == 0 || exp_dept_q.size() == 0)
          $error("Unexpected output given by DUT");
        else begin
          exp_cutoff = exp_cutoff_q.pop_front();
          act_cutoff = act_cutoff_q.pop_front();
          if (act_cutoff == exp_cutoff) $display("Exp cutoff data %0d Act cutoff data %0d match", exp_cutoff, act_cutoff);
          else $error("Exp cutoff data %0d Act cutoff data %0d don't match", exp_cutoff, act_cutoff);

          exp_dept = exp_dept_q.pop_front();
          act_dept = act_dept_q.pop_front();
          if (act_dept == exp_dept) $display("Exp department data %0d Act department data %0d match", exp_dept, act_dept);
          else $error("Exp department data %0d Act department data %0d don't match", exp_dept, act_dept);
        end
      end
      @(posedge clk);
    end
  endtask

  initial begin
    clock_generation();
    reset_generation();
    drive_input(5);
    #300;
    $finish;
  end

endmodule