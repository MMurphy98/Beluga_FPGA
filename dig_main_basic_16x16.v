//Verilog HDL for "ISFET", "fpga_compen" "functional"

module dig_main_basic_16x16#(
      parameter NUM_RC_POW = 4,     // total number of row/column = 2**NUM_RC_POW, e.g. 16
      parameter WORD_WIDTH = 18,
      parameter ADC_BITS   = 18,
      parameter BIT_SETTLE = 4,
      parameter ROTAT_LOCA = 17,
      parameter ADC_INT_LOCA = 16
      )
   (  
      // power and gnd
	  inout   vddd,
	  inout   gndd,  
      // control and clock from external FPGA board
      input    clk_ext,
      input    rstb_ext,
      // signal communicate with ADC control block
      input    adc_data_ready,
      input    signed [ADC_BITS-1:0] din_adc,
      output   adc_ena,
      // signal control ISFET array
      output   [2**NUM_RC_POW-1:0] row_sel, 
      output   [2**NUM_RC_POW-1:0] col_sel, 
      // signal communicate with SPI block
      input    spi_fpga_wait,
      input    spi_si_ena,
      input    din_4_fpga,
      output   spi_so_flag,                  // indicating the spi block is sending data out 
      output   dout_2_fpga
      );


   // define the FSM for pixel compensation
   localparam  IDLE     = 0,
               SERIN    = 1,         // load external instruct
               PSEL     = 2,         // Pixel selection
               WFD      = 3,         // Wait for Data
               PARIN    = 4,         // load ADC'ed data into shift register
               SEROUT   = 5;         // call UART block to send data to PC

   // compensation state and next state
   reg [2:0]  ss, ss_next;  
   // variables for algorithms
   reg [WORD_WIDTH-1:0] data_shift;
   reg [2*NUM_RC_POW-1:0] addr_sel;
   reg rotate_flag,addr_flag,adc_ext_flag;
   reg din_4_fpga_L1;
   reg [BIT_SETTLE-1:0] settle_period,hold_period;
   reg [2*BIT_SETTLE:0] cnt_settle;
   reg adc_ena_reg_Lx,adc_ena_reg;
   reg [4:0] cnt_spi_out;
   wire [2*NUM_RC_POW-1:0] addr_4_spi;
   // register for output
   reg dout_2_fpga_reg;
   reg spi_so_flag_reg;


   ////////////////  states transferring   ///////////////////
   always @(posedge clk_ext or negedge rstb_ext) begin : ss_tran
      if(rstb_ext == 1'b0) begin
         ss <= IDLE;
      end else if(clk_ext == 1'b1) begin
         ss <= ss_next;
      end
   end

   //////////////  calculate the next state /////////////////
   always @(ss,spi_si_ena,adc_ext_flag,adc_data_ready,cnt_spi_out,spi_fpga_wait) begin : ss_calu
      ss_next = ss;
      case (ss)
         IDLE:       if(spi_si_ena == 1'b1) 
                        ss_next = SERIN;
         SERIN:      if(spi_si_ena == 1'b0)
                        ss_next = PSEL;                           
         PSEL:       ss_next = WFD;                           
         WFD:        if (adc_ext_flag == 1'b1)
                        ss_next = IDLE;
                     else if (adc_data_ready == 1'b1)     // read out has been ADC'ed
                        ss_next = PARIN;                   
         PARIN:      if (spi_fpga_wait == 1)
                        ss_next = SEROUT;
         SEROUT:     if(cnt_spi_out == ADC_BITS-1)
                        ss_next = WFD;
         default :   ss_next = IDLE;
      endcase
   end

   //////////  data processing in various states /////////////
   task signal_reset;
      begin 
         data_shift <=0;
         rotate_flag <= 0;
         settle_period <= 0;
         hold_period <= 0;
         addr_sel <= {2*NUM_RC_POW{1'b0}};   
         cnt_spi_out <=0 ;
         din_4_fpga_L1 <= 1'b0;
         addr_flag <= 0;
         adc_ext_flag <= 0;
         // register for output
         dout_2_fpga_reg <= 1'b0;
         adc_ena_reg <= 1'b0;
         adc_ena_reg_Lx <= 1'b0;
         spi_so_flag_reg <= 1'b0;
      end
   endtask
   task call_adc;
      begin
         
      end
   endtask
//   always @(posedge clk_ext or rstb_ext) begin : proc_
   always @(posedge clk_ext or negedge rstb_ext) begin : proc_


      if(rstb_ext == 1'b0) begin
         signal_reset;
//         adc_ena_reg_Lx <= 1'b0;
      end else if(clk_ext == 1'b1) begin
         case (ss)
            IDLE: begin
               signal_reset;
            end
            SERIN: begin
               data_shift[0] <= din_4_fpga_L1;
               data_shift[WORD_WIDTH-1:1] <= data_shift[WORD_WIDTH-2:0];
            end
            PSEL: begin 
                  addr_sel <= addr_4_spi;                            // selected pixel according to the address
                  settle_period <= data_shift[2*NUM_RC_POW+BIT_SETTLE-1:2*NUM_RC_POW];
                  hold_period <= data_shift[2*NUM_RC_POW+2*BIT_SETTLE-1:2*NUM_RC_POW+BIT_SETTLE];
                  rotate_flag <= data_shift[ROTAT_LOCA];             // check the running mode
                  if (data_shift[ADC_INT_LOCA]) begin                     // using internal ADC
                     adc_ena_reg <= 1'b1;                               // call ADC             
                  end else begin
                     adc_ext_flag <= 1'b1;
                  end
            end   
            WFD: begin
               spi_so_flag_reg <= 0;
               addr_flag <= 0;
               cnt_spi_out <=0;
            end  
            PARIN: begin
               data_shift <= 0;
               data_shift[WORD_WIDTH-1:WORD_WIDTH-ADC_BITS] <= din_adc; // set the top bits to be ADC results
               adc_ena_reg <= 0;
               // select the next pixel
               // if (rotate_flag == 1'b1 && addr_flag == 1'b0) begin      // read each pixel in the array
               //    addr_sel <= addr_sel+1;
               //    addr_flag <= 1;
               // end
            end     
            SEROUT: begin
               // function of this status
               spi_so_flag_reg <= 1'b1;
               dout_2_fpga_reg <= data_shift[WORD_WIDTH-1];
               data_shift[WORD_WIDTH-1:1] <= data_shift[WORD_WIDTH-2:0];
               data_shift[0] <= 1'b0;
               cnt_spi_out <= cnt_spi_out+1;
               // also call adc again
               adc_ena_reg <= 1;
            end
            default : signal_reset;
         endcase
         din_4_fpga_L1 <= din_4_fpga;
      end
   end
   
   assign addr_4_spi = data_shift[2*NUM_RC_POW-1:0];
   ////////////////// generate the delay signal of adc_ena /////////////////////
   always @(posedge clk_ext or negedge adc_ena_reg) begin
      if (adc_ena_reg == 0) begin
         // reset
         adc_ena_reg_Lx <= 0;
         cnt_settle <= 0;
         addr_flag <= 0;
      end
      else if (clk_ext == 1'b1) begin
            cnt_settle <= cnt_settle + 1;
         // wait a bit before enable the ADC
         if (cnt_settle == settle_period) begin
            adc_ena_reg_Lx <= 1;
         end
         // select the next pixel
         if (cnt_settle == settle_period+hold_period && addr_flag == 0) begin
            addr_sel <= addr_sel+1;
            addr_flag <= 1;
         end
      end
   end
   ////////////////// decoder for row and column selection /////////////////////
   reg [2**NUM_RC_POW-1:0] row_sel_reg;
   reg [2**NUM_RC_POW-1:0] col_sel_reg;
   always @(addr_sel) begin : proc_row_decoder
      row_sel_reg = {2**NUM_RC_POW{1'b0}};
      row_sel_reg[addr_sel[2*NUM_RC_POW-1:NUM_RC_POW]] = 1'b1;
   end
   always @(addr_sel) begin : proc_col_decoder
      col_sel_reg = {2**NUM_RC_POW{1'b0}};
      col_sel_reg[addr_sel[NUM_RC_POW-1:0]] = 1'b1;
   end
   assign row_sel = row_sel_reg;
   assign col_sel = col_sel_reg;

   // output assignment
   assign adc_ena = adc_ena_reg_Lx;
   assign dout_2_fpga = dout_2_fpga_reg;
   assign spi_so_flag = spi_so_flag_reg;

endmodule

