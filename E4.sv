module tb_top();

  // parameters
  parameter RESET_PERIOD = 2;
  parameter CLOCK_PERIOD = 10;

  // local variables
  logic clk;
  logic rst_n;
  logic valid_i;
  logic[1:0] snack;
  logic[1:0] quantity;
  logic valid_o;
  logic[7:0] packed_snack;
  bit[7:0] exp_q[$], act_q[$];

  // DUT instantiation
  smart_vending_machine i_dut(
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .snack(snack),
    .quantity(quantity),
    .valid_o(valid_o),
    .packed_snack(packed_snack)
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
    snack = 'bx;
    quantity = 'bx;
  endfunction

  // drive input stimulus
  task drive_input(int trans_count);
    @(posedge clk);
    #1;
    repeat(trans_count) begin
      valid_i = 1;
      quantity = $urandom_range(0, 3);
      repeat(quantity + 1) begin
        snack = $urandom_range(0, 3);
        @(posedge clk);
        #1;
      end
    end
    reset_input_signals();
  endtask

  // monitor input stimulus
  task ip_monitor();
    forever begin
      if (valid_i) begin
        predictor(quantity, snack);
      end
      @(posedge clk);
    end
  endtask

  // monitor output from DUT
  task op_monitor();
    forever begin
      if (valid_o) begin
        act_q.push_back(packed_snack);
      end
      @(posedge clk);
    end
  endtask

  // checker
  task check_exp_and_act();
    bit[7:0] exp, act;
    forever begin
      if (act_q.size() >= 1) begin
        if (exp_q.size() == 0) $error("Unexpected Output from DUT");
        else begin
          exp = exp_q.pop_front();
          act = act_q.pop_front();
          if (exp == act) $display("Exp value %0b and Act value %0b match", exp, act);
          else $error("Exp value %0b and Act value %0b don't match", exp, act);
        end
      end
      @(posedge clk);
    end
  endtask

  // predictor function
  function void predictor(bit[1:0] quantity, snack);
    bit[1:0] local_Q1_q[$], local_Q2_q[$], local_Q3_q[$];
    bit[7:0] exp_data;
    case (quantity)
      'b00: exp_q.push_back(snack);
      'b01: begin
        local_Q1_q.push_back(snack);
        if (local_Q1_q.size() == 2) begin
          exp_data = {local_Q1_q.pop_back(), local_Q1_q.pop_back()};
          exp_q.push_back(exp_data);
          exp_data = 'b0;
        end
      end
      'b10: begin
        local_Q2_q.push_back(snack);
        if (local_Q2_q.size() == 3) begin
          exp_data = {local_Q2_q.pop_back(), local_Q2_q.pop_back(), local_Q2_q.pop_back()};
          exp_q.push_back(exp_data);
          exp_data = 'b0;
        end
      end
      'b11: begin
        local_Q3_q.push_back(snack);
        if (local_Q3_q.size() == 4) begin
          exp_data = {local_Q3_q.pop_back(), local_Q3_q.pop_back(), local_Q3_q.pop_back(), local_Q3_q.pop_back()};
          exp_q.push_back(exp_data);
          exp_data = 'b0;
        end
      end
    endcase
  endfunction

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