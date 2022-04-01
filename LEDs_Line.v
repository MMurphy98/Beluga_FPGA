`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/03/11 22:14:20
// Design Name: 
// Module Name: LEDs_Line
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LEDs_Line #(
    parameter WORD_WIDTH = 18,
    parameter T_WIDTH = 10000)
    (
    input clk,
    input rstn,
    input din,
    input din_ena,
    output [WORD_WIDTH-1:0] leds
    );
    //reg [WORD_WIDTH-1:0] leds_reg;
    reg [WORD_WIDTH-1:0] din_L18;
//    reg [15:0] tcnt;
   // reg din_L1;
   // reg [7:0] bcnt;
    assign leds = din_L18;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            //din_L1 <= 0;
            din_L18 <=18'd0;
        end
        else begin
            if (din_ena) begin
                din_L18[WORD_WIDTH-1:1] <= din_L18[WORD_WIDTH-2:0];
                din_L18[0] <=din;
            end
        end
    end
    
//    always @(posedge clk or negedge rstn) begin
//        if (!rstn) begin
//            tcnt <= 16'd0;
//            //bcnt <= 8'd0;
//            leds_reg <= 18'd0;
//        end else begin
//            if (tcnt == 16'hFFFF) begin
//                tcnt <= 16'd0;
//                    leds_reg <= din_L18;
//                    //bcnt <= bcnt + 8'd1; 
//            end else
//                tcnt <= tcnt + 16'd1;
//                leds_reg <= leds_reg;
//        end 
//    end

    
endmodule
