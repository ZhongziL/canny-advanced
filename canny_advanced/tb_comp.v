// TESTBENCH
`timescale 1ns/10ps

`define EOF		32'hFFFF_FFFF
`define NULL		0
`define LEN_HEADER	54   // 0x36

module stimulus_comp;
	// FILE I/O
	integer 				fileI1, fileI2, c, r;
	reg		[7:0]		FILE_HEADER[0:`LEN_HEADER-1];
   reg    	[31:0] 	LHEADER;
	reg		[7:0]		memX[0:120000-1];	// 200x200x3
	reg		[7:0]		memY[0:120000-1];	// 200x200x3
	
  	reg   	[7:0]   	memLine[0:600-1];
   reg   	[31:0]   HeaderLine[0:12];
   reg   	[7:0]   	rG, rB, rR;
   
	parameter			dWidth = 600;
	parameter   		dHeight = 200;

	integer				i,j,k,l;
	integer				t;
   
	real					compratio;
	real					sum_diff;
	real					diff;

	initial
		begin
			$display(">> --------------------------------------\n");

			for (k=0; k<6; k=k+1)
				begin
					if(k==0) 
						begin
							fileI1 = $fopen("0.ref.bmp","rb");
							fileI2 = $fopen("0.OutputOrigin.bmp","rb");
						end
					
					else if(k==1) 
						begin
							fileI1 = $fopen("1.ref.bmp","rb");
							fileI2 = $fopen("1.OutputGauss.bmp","rb");
						end
						
					else if(k==2) 
						begin
							fileI1 = $fopen("2.ref.bmp","rb");
							fileI2 = $fopen("2.OutputGradient.bmp","rb");
						end
						
					else if(k==3) 
						begin
							fileI1 = $fopen("3.ref.bmp","rb");
							fileI2 = $fopen("3.OutputDirection.bmp","rb");
						end
					
					else if(k==4) 
						begin
							fileI1 = $fopen("4.ref.bmp","rb");
							fileI2 = $fopen("4.OutputNMS.bmp","rb");
						end
						
					else if(k==5) 
						begin
							fileI1 = $fopen("5.ref.bmp","rb");
							fileI2 = $fopen("5.OutputHysteresis.bmp","rb");
						end

					sum_diff=0;
					compratio = 0.0;
					if (fileI1 == `NULL || fileI2 == `NULL)	
						begin 
							$display("> FAIL: The centain file is not exist for %dth process 0!\n",k);
						end
						
					else 
						begin
							//$display("> SUCCESS : The file was read successfully.\n");
							r = $fread(FILE_HEADER, fileI1, 0, `LEN_HEADER); 
							//$display("$fread read %0d bytes: \n", r); 
				
							for(i=0; i<dHeight; i=i+1) 
								begin
									for(j=0; j<dWidth; j=j+1) 
										begin	
											memX[(dHeight-i-1)*dWidth+j] = $fgetc(fileI1);
										end
								end
								
							$fclose(fileI1);

							r = $fread(FILE_HEADER, fileI2, 0, `LEN_HEADER); 
							//$display("$fread read %0d bytes: \n", r); 
			
							for(i=0; i<dHeight; i=i+1) 
								begin
									for(j=0; j<dWidth; j=j+1)
										begin	
											memY[(dHeight-i-1)*dWidth+j] = $fgetc(fileI2);
										end
								end
								
							$fclose(fileI2);
				
							for(i=54; i<dHeight*dWidth; i=i+1) 
								begin
									diff = memX[i]-memY[i];
									//if(diff!=0)
									//	$display(">>> Addr:%d, memX:%d, memY:%d", i,memX[i], memY[i]);
									if(diff > 0)	sum_diff = sum_diff + diff;
									else		sum_diff = sum_diff - diff;
								end
								
							compratio = sum_diff / (dHeight*dWidth);
							compratio = 100.0 - compratio;
						end
						
					$display(">> %dth Comparison ratio : %3.5f percent\n",k, compratio);
				end

			$display(">> --------------------------------------\n");
		end

endmodule
