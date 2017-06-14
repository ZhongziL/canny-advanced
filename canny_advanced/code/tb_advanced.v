`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   21:12:29 05/31/2017
// Design Name:   canny_advanced
// Module Name:   F:/case-analyse/canny_advanced/tb_advanced.v
// Project Name:  canny_advanced
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: canny_advanced
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_advanced;

	// Inputs
	reg clk;
	reg reset;

	// Instantiate the Unit Under Test (UUT)
	canny_advanced canny (
		.clk(clk), 
		.reset(reset)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 1;
		#10;
		reset = 0;

		// Wait 100 ns for global reset to finish
		#10;
      reset = 1;
		forever 
			begin
				#1;
				clk = ~clk;
			end
		// Add stimulus here

	end
      
endmodule

