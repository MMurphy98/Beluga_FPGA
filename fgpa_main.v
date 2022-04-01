`timescale 1ns / 1ps
//Verilog HDL for "ISFET", "fpga_compen" "functional"

// hahahahhh liangjing a a ahahh ni zhenkeai a 

module fpga_main #(
      parameter PIXEL_NUM  = 16,
      parameter WORD_WIDTH = 18,
      parameter ADDR_WIDTH = 8,
      parameter ROTAT_LOCA = 17,
      parameter ADC_INT_LOCA = 16,
      parameter BIT_SETTLE = 4,
      parameter ADC_BITS   = 18
      )
   (
      // control and clock from external FPGA board
      input    clk_ext,
      input    rstb_ext,
      input    pixel_rd_ena,
      input    rotate_flag,
      input    adc_int_flag,
      input    [ADDR_WIDTH-1:0] pixel_select,
		// LEDs for instruction
		output   [WORD_WIDTH-1:0] rleds,
		output   gled,
      // signal communicate with SPI & UART block
      // signal for sending & receiving data with chip
      input    spi_si4chip_ena,
      input    din_4_chip,
      output   reg spi_fpga_wait,
      output   spi_so2chip_flag,                  // indicating the spi block is sending data out 
      output   reg dout_2_chip,
      // output ports for debug during design phase
      output   reg signed [ADC_BITS-1:0] adc_received,
      output   clk_out,                          //output clk for dig_main
      output   rst_out,                           //output reset for dig_main
      
      input    ss_switch              //switch the state of CLK
      );
   
   // define the FSM for pixel compensation
   parameter   IDLE     = 0,
               INIT     = 1,         // Pixel selection
               SEROUT   = 2,
               WFD      = 3,         // Wait for Data
               SERIN    = 4,
               CALL_UART= 5,         // call UART block to send data to PC;         // array evaluation
               delay = 6,
               
               CLK_ZERO = 15;
   //wire clk_ext;
   // compensation state and next state
   reg [3:0]  ss, ss_next;  
   // variables used for algorithm
   // register for output
   reg spi_so2chip_ena_reg;
   reg din_4_chip_L1;
   reg uart_ena_reg;
   reg signed [WORD_WIDTH-1:0] data_spi_reg;
   integer cnt_spi_out;
//    CLK divider 
    clk_div clk_inst(
    .clk(clk_ext),
    .rstn(rstb_ext),
    .clk_div(clk_div)
    );
	// LEDs output
//	assign rleds[ADDR_WIDTH-1:0] = pixel_select;
//	assign rleds[ROTAT_LOCA] = rotate_flag;
//	assign rleds[ADC_INT_LOCA] = adc_int_flag;
//	assign rleds[ADC_INT_LOCA-1] = pixel_rd_ena;
//	assign rleds[ADC_INT_LOCA-2] = spi_si4chip_ena;
	assign gled = ~rstb_ext;
    
	LEDs_Line inst_LEDs_Line(
    .clk(clk_div),
    .rstn(rstb_ext),
    .din(dout_2_chip),
    .din_ena(spi_so2chip_flag),
    .leds(rleds)
    );
   ////////////////  states transferring   ///////////////////
   always @(posedge clk_div or negedge rstb_ext) begin : ss_tran_cpenF
      if(rstb_ext == 1'b0) begin
         ss <= IDLE;
      end else if(clk_div == 1'b1) begin
         ss <= ss_next;
      end
   end
    reg [7:0] cnt_delay;
   //////////////  calculate the next state /////////////////
   always @(ss,pixel_rd_ena,cnt_spi_out,spi_si4chip_ena,cnt_delay) begin : ss_calu
      ss_next = ss;
      case (ss)
         IDLE:       if(pixel_rd_ena == 1'b1) 
                        ss_next = INIT;
         INIT:       ss_next = SEROUT;
         SEROUT:     if (cnt_spi_out == WORD_WIDTH-1)begin
                       // if(ss_switch == 0)
                            ss_next = delay;                        
                      //  else                         //change the CLK
                       //     ss_next = CLK_ZERO;
                     end 
         delay:      if (cnt_delay == 8'd2) begin
                        ss_next = WFD;
                     end
                                    
         WFD:        if(spi_si4chip_ena == 1)begin
                        if(ss_switch == 0)
                            ss_next = SERIN;
                        else                         //change the CLK
                            ss_next = CLK_ZERO; 
                     end                  
         SERIN:      if(spi_si4chip_ena == 0)  
                        ss_next = CALL_UART;
         CALL_UART:  ss_next = WFD;
         CLK_ZERO:   ss_next = CLK_ZERO;
        
         default :   ss_next = IDLE;
      endcase
   end

   //////////  data processing in various states /////////////
   task signal_reset;
      begin 
         data_spi_reg <= 0;
         dout_2_chip <= 0;
         spi_fpga_wait <= 1'b0;
         din_4_chip_L1 <= 0;
         spi_so2chip_ena_reg <= 1'b0;
         uart_ena_reg <= 1'b0;
         cnt_spi_out <=0;
         adc_received <= 0;
      end
   endtask
   always @(posedge clk_div or negedge rstb_ext) begin : proc_
      if(rstb_ext == 1'b0) begin
         signal_reset;
         cnt_delay <= 0;
      end else if(clk_div == 1'b1) begin
         case (ss)
            IDLE: begin
               signal_reset;
            end
            INIT: begin 
               spi_so2chip_ena_reg <= 1'b1;
             //  data_spi_reg[ADDR_WIDTH-1:0] = 3;
               data_spi_reg[ADDR_WIDTH-1:0] = pixel_select;
               data_spi_reg[ADDR_WIDTH-1+BIT_SETTLE:ADDR_WIDTH] = 0;
			   data_spi_reg[ADDR_WIDTH-1+2*BIT_SETTLE:ADDR_WIDTH+BIT_SETTLE] = 7;
               data_spi_reg[ROTAT_LOCA] = rotate_flag;  
               data_spi_reg[ADC_INT_LOCA] = adc_int_flag;
            end
            SEROUT: begin
               dout_2_chip <= data_spi_reg[WORD_WIDTH-1];
               data_spi_reg[WORD_WIDTH-1:1] <= data_spi_reg[WORD_WIDTH-2:0];
               data_spi_reg[0] <= 1'b0;
               cnt_spi_out <= cnt_spi_out+1;
            end
            delay: begin
                spi_so2chip_ena_reg <= 1'b0;  
                cnt_delay <= cnt_delay + 8'd1;
            end
            WFD: begin 
                cnt_delay  <= 8'd0;
               // reset previous enable signal
               spi_so2chip_ena_reg <= 1'b0;  
               cnt_spi_out <= 0;
               spi_fpga_wait <= 1;
            end
            SERIN: begin
               spi_fpga_wait <= 0;
               data_spi_reg[0] <= din_4_chip_L1;
               data_spi_reg[WORD_WIDTH-1:1] <= data_spi_reg[WORD_WIDTH-2:0];
            end
            CALL_UART: begin 
               uart_ena_reg <= 1'b1; // send data to PC
               adc_received <= data_spi_reg;
            end
            CLK_ZERO:begin
                spi_fpga_wait <= 0;
            end
           
            default : signal_reset;
         endcase
         din_4_chip_L1 <= din_4_chip;
      end
   end

   assign spi_so2chip_flag = spi_so2chip_ena_reg;
   assign clk_out = ~(clk_div|ss[3]);
   //assign clk_out = clk_div;
endmodule
