`timescale 1ns / 1ps

`define DATA_WIDTH 8
`define PICTURE_LENGTH 1280
`define PICTURE_WIDTH 720
`define PICTURE_MIX	1280*720

`define EOF		32'hFFFF_FFFF
`define NULL		0
`define LEN_HEADER	54   // 0x36

module canny_advanced(clk, reset);
	reg	[`DATA_WIDTH-1:0]		readsPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		readsPictureCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		gaussPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		gaussPictureCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		sobelPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		sobelPictureCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		directPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		nmsPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		nmsdirectPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		thresPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		thresDirect[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		sobelCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		outputPicture[0:`PICTURE_MIX-1];
	
	reg	[`DATA_WIDTH-1:0]		FILE_HEADER[0:`LEN_HEADER-1];
	reg 		[31:0]					tpSum, Sum;
	reg signed	 	[31:0] 			Gx, Gy, fGx, fGy, Gxadd, Gyadd, Gxyadd, fGx_t;
	reg 	readcache, gausscache, sobelcache, nmscache;
	
	reg 	[`DATA_WIDTH-1:0]			gf[0:24];	// 5x5 Gaussian Filter
	integer			sobelX[0:8];//	3x3 SobelX Filter
	integer			sobelY[0:8];// 3x3 SobelY Filter
	
	integer rx, ry, gx, gy, sx, sy, dx, dy, nx, ny, ndx, ndy, tx, ty, wx, wy;
	integer gsignal, ssignal, nsignal, tsignal, osignal, outputsignal, rsignal;
	integer i, j, k, count, p;
	reg	[7:0]	number, num;
	reg	[7:0]	temp, temps;
	integer gi, gj, si, sj;
	reg   	[7:0] 	th;
	reg 	[16*8:0] 	fr, fw;
	reg signed	[1:0]					directx, directy;
	reg signed	[1:0]					thresx, thresy;
	reg [`DATA_WIDTH:0]	nmsA, nmsB;
	reg [`DATA_WIDTH:0]	thresA, thresB;
	parameter 							dThresHigh = 15;
	parameter							dThresLow = 10;
	
	integer 				fileI, fileO, c, r, fileT;
	
	input clk, reset;
	
	always@(negedge reset)
		begin
			rx = 0; ry = 0;
			gx = 722; gy = 1282; sx = 722; sy = 1282;
			dx = 722; dy = 1282; nx = 722; ny = 1282;
			ndx = 722; ndy = 1282; tx = 722; ty = 1282;
			wx = 722; wy = 1282;
			tpSum = 0; count = 0; readcache = 0; gausscache = 0; sobelcache = 0;
			nmscache = 0;
			gsignal = 1; ssignal = 1; nsignal = 1; tsignal = 1; osignal = 1; outputsignal = 0; rsignal = 0;
			Gxadd = 0; Gyadd = 0; Gxyadd = 0; Gx = 0; Gy = 0;
 			gi = -2; gj = -2; si = -1; sj = -1;
			number = 11; num = 101;
			
			gf[0] =1;  gf[1] =3;  gf[2]=4;   gf[3]=3;   gf[4]=1;
			gf[5] =3;  gf[6] =7;  gf[7]=10;  gf[8]=7;   gf[9]=3;
			gf[10]=4;  gf[11]=10; gf[12]=16; gf[13]=10; gf[14]=4;
			gf[15]=3;  gf[16]=7;  gf[17]=10; gf[18]=7;  gf[19]=3;
			gf[20]=1;  gf[21]=3;  gf[22]=4;  gf[23]=3;  gf[24]=1;
					
			sobelX[0]=-1;	sobelX[1]=0; sobelX[2]=1;
			sobelX[3]=-2;	sobelX[4]=0; sobelX[5]=2;
			sobelX[6]=-1;	sobelX[7]=0; sobelX[8]=1;
					
			sobelY[0]=1;	sobelY[1]=2; sobelY[2]=1;
			sobelY[3]=0;	sobelY[4]=0; sobelY[5]=0;
			sobelY[6]=-1;	sobelY[7]=-2; sobelY[8]=-1;
			
			for (i = 0; i < `PICTURE_MIX; i=i+1)
				begin
					readsPicture[i] = 0;
					gaussPicture[i] = 0;
					sobelPicture[i] = 0;
					directPicture[i] = 0;
					nmsPicture[i] = 0;
					nmsdirectPicture[i] = 0;
					thresPicture[i] = 0;
					outputPicture[i] = 0;
				end
				
			fileI = $fopen("./output/10.bmp","rb");
			//fileI = $fopen("kodim22_200.bmp", "rb");
			if (fileI == `NULL) $display("> FAIL: The file is not exist !!!\n");
			else	           $display("> SUCCESS : The file was read successfully.\n");
				
			r = $fread(FILE_HEADER, fileI, 0, `LEN_HEADER); 
			
			fw = "./output/100.bmp";
			fileO = $fopen("./output/100.bmp","wb");
			for(k=1; k<55; k=k+1)
				begin
					$fwrite(fileO, "%c", FILE_HEADER[k]);
				end

		end
		
	//read a picture 1280*720
	always@(posedge clk)
		begin
			if(reset && rx < `PICTURE_LENGTH+1 && ry < `PICTURE_WIDTH+1)
				begin
					c = $fgetc(fileI);
					c = $fgetc(fileI);
					readsPicture[(`PICTURE_LENGTH-rx-1)*`PICTURE_WIDTH+ry] = $fgetc(fileI);
					rx = rx + 1;
					if(rx == `PICTURE_LENGTH)
						begin
							rx = 0;
							ry = ry + 1;
						end
					if(ry == `PICTURE_WIDTH)
						begin
							rx = `PICTURE_WIDTH+1;
							ry = `PICTURE_LENGTH+1;
							readcache = 1;
							$fclose(fileI);
						end
				end
		end
		
	//store and start gauss and read next
	always@(posedge clk)
		begin
			if(reset && readcache && gsignal)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							readsPictureCache[i] = readsPicture[i];
							gaussPicture[i] = readsPicture[i];
						end
					readcache = 0;
					gsignal = 0;
					gx = 2;
					gy = 2;

					if(number < 25)
						begin
							rx = 0;
							ry = 0;
							temp = number%10;
							temps = number/10;
							fr = {"./output/", "0"+temps, "0"+temp, ".bmp"};
							fileI = $fopen(fr, "rb");
							number = number + 1;
							
							if (fileI == `NULL) $display("> FAIL: The file %s is not exist !!!\n", fr);
							else	           $display("> SUCCESS : The file %s was read successfully.\n", fr);
								
							r = $fread(FILE_HEADER, fileI, 0, `LEN_HEADER);
						end
				end
		end
		
	//gauss
	always@(posedge clk)
		begin
			if(reset && gy < `PICTURE_LENGTH+1 && gx < `PICTURE_WIDTH+1)
				begin
					if(gx > 1 && gy < `PICTURE_LENGTH-2 && gy > 1 && gx < `PICTURE_WIDTH-2)
						begin
							Sum = readsPictureCache[(gy+gi)*`PICTURE_WIDTH+gx+gj]*gf[(2+gi)*5+(2+gj)];
							tpSum = tpSum + Sum;
							gi = gi+1;
							if(gi == 3)
								begin
									gi = -2;
									gj = gj + 1;
								end
							if(gj == 3)
								begin
									gj = -2;
									gaussPicture[gy*`PICTURE_WIDTH+gx] = (tpSum>>7);
									tpSum = 0;
									gx = gx + 1;
								end
							if(gx == `PICTURE_WIDTH-2)
								begin
									gx = 2;
									gy = gy + 1;
								end
							if(gy == `PICTURE_LENGTH-2)
								begin
									gx = `PICTURE_WIDTH+1;
									gy = `PICTURE_LENGTH+1;
									gausscache = 1;
									gsignal = 1;
								end
						end
				end
		end
	
	//store and start sobel and direction
	always@(posedge clk)
		begin
			if(reset && gausscache && ssignal)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							gaussPictureCache[i] = gaussPicture[i];
							directPicture[i] = 0;
						end
					gausscache = 0;
					ssignal = 0;
					sx = 0;
					sy = 0;
				end
		end
		
	//sobel and direction
	always@(posedge clk)
		begin
			if(reset && sx < `PICTURE_WIDTH+1 && sy < `PICTURE_LENGTH+1)
				begin
					if(sx+si < 0 || sy+sj < 0 || sx+si >= `PICTURE_WIDTH || sy+sj >= `PICTURE_LENGTH)
						begin
							Gxadd = 0;
							Gyadd = 0;
						end
					else
						begin
							Gxadd = gaussPictureCache[(sy+sj)*`PICTURE_WIDTH+sx+si]*sobelX[(1+si)*3+(1+sj)];
							Gyadd = gaussPictureCache[(sy+sj)*`PICTURE_WIDTH+sx+si]*sobelY[(1+si)*3+(1+sj)];
						end	
					Gx = Gx + Gxadd;
					Gy = Gy + Gyadd;
					si = si + 1;
					if(si == 2)
						begin
							si = -1;
							sj = sj + 1;
						end
					if(sj == 2)
						begin
							sj = -1;
							if(Gx<0 && Gy<0)
								begin
									Gxyadd = (-Gx) + (-Gy);
								end
							else if(Gx>0 && Gy<0)
								begin
									Gxyadd = Gx + (-Gy);
								end
							else if(Gx<0 && Gy>0)
								begin
									Gxyadd = (-Gx) + Gy;
								end
							else 
								begin
									Gxyadd = Gx + Gy;
								end
										
							if(Gxyadd < 0)	Gxyadd = -Gxyadd;
												
							sobelPicture[sy*`PICTURE_WIDTH+sx] = (Gxyadd>>3);
									
							if(Gy < 0)
								begin
									fGx = -Gx;
									fGy = -Gy;
								end
							else
								begin
									fGx = Gx;
									fGy = Gy;
								end
										
							if(fGx >= 0)
								begin
									fGx_t = (5*fGx)>>1;
									if(fGx_t < 0) fGx_t = -fGx_t;
														
									if(fGy <= (fGx>>1))
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 0;
										end
									else if(fGy <= fGx_t)
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 45;
										end
									else
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 90;
										end
								end
							else // if(fGx<0)
								begin
									fGx_t = ((-5)*fGx)>>1;
									if(fGx_t < 0) fGx_t = -fGx_t;
														
									if(fGy <= ((-fGx)>>1))
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 0;
										end
									else if(fGy <= fGx_t)
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 135;
										end
									else
										begin
											directPicture[sy*`PICTURE_WIDTH+sx] = 90;
										end
								end
														
							Gx = 0;
							Gy = 0;
							sx = sx + 1;
						end
					if(sx == `PICTURE_WIDTH)
						begin
							sx = 0;
							sy = sy + 1;
						end
					if(sy == `PICTURE_LENGTH)
						begin
							sx = `PICTURE_WIDTH+1;
							sy = `PICTURE_LENGTH+1;
							sobelcache = 1;
							ssignal = 1;
						end
				end
		end
		
	//store and start nms
	always@(posedge clk)
		begin
			if(reset && sobelcache && nsignal)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							sobelPictureCache[i] = sobelPicture[i];
							nmsdirectPicture[i] = directPicture[i];
						end
					sobelcache = 0;
					nsignal = 0;
					nx = 0;
					ny = 0;
				end
		end
		
	//nms
	always@(posedge clk)
		begin
			if(reset && nx < `PICTURE_WIDTH && ny < `PICTURE_LENGTH)
				begin
					if(nmsdirectPicture[ny*`PICTURE_WIDTH+nx] == 0)
						begin
							directx = 1;
							directy = 0;
							nmsA = sobelPictureCache[ny*`PICTURE_WIDTH+nx-1];
							nmsB = sobelPictureCache[ny*`PICTURE_WIDTH+nx+1];
							if(ny+1 >= 1280)
								begin
									nmsB = 0;
								end
							else if(ny-1 < 0)
								begin
									nmsA = 0;
								end
						end
					else if(nmsdirectPicture[ny*`PICTURE_WIDTH+nx] == 45)
						begin
							directx = 1;
							directy = -1;
							nmsA = sobelPictureCache[(ny+1)*`PICTURE_WIDTH+nx-1];
							nmsB = sobelPictureCache[(ny-1)*`PICTURE_WIDTH+nx+1];
							if(ny+1 >= `PICTURE_LENGTH || nx-1<0)
								begin
									nmsB = 0;
								end
							else if(ny-1 < 0 || nx+1>=`PICTURE_WIDTH)
								begin
									nmsA = 0;
								end
						end
					else if(nmsdirectPicture[nx*`PICTURE_WIDTH+ny] == 90)
						begin
							directx = 0;
							directy = -1;
							nmsA = sobelPictureCache[(ny-1)*`PICTURE_WIDTH+nx];
							nmsB = sobelPictureCache[(ny+1)*`PICTURE_WIDTH+nx];
							if(ny+1 >= `PICTURE_LENGTH)
								begin
									nmsB = 0;
								end
							else if(ny-1 < 0)
								begin
									nmsA = 0;
								end
						end
					else
						begin
							directx = -1;
							directy = -1;
							nmsA = sobelPictureCache[(ny-1)*`PICTURE_WIDTH+nx-1];
							nmsB = sobelPictureCache[(ny+1)*`PICTURE_WIDTH+nx+1];
							if(ny+1 >= `PICTURE_LENGTH || nx+1>=`PICTURE_WIDTH)
								begin
									nmsB = 0;
								end
							else if(ny-1 < 0 || nx-1<0)
								begin
									nmsA = 0;
								end
						end
					
					if(sobelPictureCache[ny*`PICTURE_WIDTH+nx] >= nmsA && sobelPictureCache[ny*`PICTURE_WIDTH+nx] >= nmsB)
						begin
							if(nx+directy >= 0 && nx+directy < `PICTURE_WIDTH && ny+directx >= 0 && ny+directx < `PICTURE_LENGTH)
								begin
									sobelPictureCache[(ny+directx)*`PICTURE_WIDTH+(nx+directy)] = 0;
								end
							if(nx-directy >= 0 && nx-directy < `PICTURE_WIDTH && ny-directx >= 0 && ny-directx < `PICTURE_LENGTH)
								begin
									sobelPictureCache[(ny+directx)*`PICTURE_WIDTH+(nx+directy)] = 0;
								end
						end
					else	
						begin
							sobelPictureCache[ny*`PICTURE_WIDTH+nx] = 0;
						end
					
					nx = nx + 1;
					if(nx == `PICTURE_WIDTH)
						begin
							nx = 0;
							ny = ny + 1;
						end
					if(ny == `PICTURE_LENGTH)
						begin
							nx = `PICTURE_WIDTH+1;
							ny = `PICTURE_LENGTH+1;
							nmscache = 1;
							nsignal = 1;
						end
				
				end
		end
		
	//store and start threshold
	always@(posedge clk)
		begin
			if(reset && nmscache && tsignal)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							sobelCache[i] = sobelPictureCache[i];
							thresDirect[i] = nmsdirectPicture[i];
						end
					nmscache = 0;
					tsignal = 0;
					tx = 0;
					ty = 0;
				end
		end
		
	//threshold
	always@(posedge clk)
		begin
			if(reset && tx < `PICTURE_WIDTH+1 && ty < `PICTURE_LENGTH+1)
				begin
					if(thresDirect[ty*`PICTURE_WIDTH+tx] == 90)
						begin
							thresx = 1;
							thresy = 0;
							thresA = sobelCache[ty*`PICTURE_WIDTH+tx-1];
							thresB = sobelCache[ty*`PICTURE_WIDTH+tx+1];
							if(tx+1 >= `PICTURE_WIDTH)
								begin
									thresB = 0;
								end
							else if(tx-1 < 0)
								begin
									thresA = 0;
								end
						end
					else if(thresDirect[ty*`PICTURE_WIDTH+tx] == 135)
						begin
							thresx = 1;
							thresy = -1;
							thresA = sobelCache[(ty+1)*`PICTURE_WIDTH+tx-1];
							thresB = sobelCache[(ty-1)*`PICTURE_WIDTH+tx+1];
							if(ty+1 >= `PICTURE_LENGTH || tx-1<0)
								begin
									thresB = 0;
								end
							else if(ty-1 < 0 || tx+1>=`PICTURE_WIDTH)
								begin
									thresA = 0;
								end
						end
					else if(thresDirect[ty*`PICTURE_WIDTH+tx] == 0)
						begin
							thresx = 0;
							thresy = -1;
							thresA = sobelCache[(ty-1)*`PICTURE_WIDTH+tx];
							thresB = sobelCache[(ty+1)*`PICTURE_WIDTH+tx];
							if(ty+1 >= `PICTURE_LENGTH)
								begin
									thresB = 0;
								end
							else if(ty-1 < 0)
								begin
									thresA = 0;
								end
						end
					else
						begin
							thresx = -1;
							thresy = -1;
							thresA = sobelCache[(ty-1)*`PICTURE_WIDTH+tx-1];
							thresB = sobelCache[(ty+1)*`PICTURE_WIDTH+tx+1];
							if(ty+1 >= `PICTURE_LENGTH || tx+1>=`PICTURE_WIDTH)
								begin
									thresB = 0;
								end
							else if(ty-1 < 0 || tx-1<0)
								begin
									thresA = 0;
								end
						end
						
					if(sobelCache[ty*`PICTURE_WIDTH+tx] >= dThresHigh)		// Keep Edge Info
							thresPicture[ty*`PICTURE_WIDTH+tx] = 1;
					else if(sobelCache[ty*`PICTURE_WIDTH+tx] <= dThresLow)		// Discard Pixel
							thresPicture[ty*`PICTURE_WIDTH+tx] = 0;
					else					// Follow Edge Trace
						begin
							if(thresA >= dThresHigh || thresB >= dThresHigh)
									thresPicture[ty*`PICTURE_WIDTH+tx] = 1;
							else if(thresPicture[(ty+thresx)*`PICTURE_WIDTH+(tx+thresy)] == 1 || thresPicture[(ty-thresx)*`PICTURE_WIDTH+(tx-thresy)] == 1)
									thresPicture[ty*`PICTURE_WIDTH+tx] = 1;
							else
									thresPicture[ty*`PICTURE_WIDTH+tx] = 0;
						end
						
					tx = tx + 1;
					if(tx == `PICTURE_WIDTH)
						begin
							tx = 0;
							ty = ty+1;
						end
					if(ty == `PICTURE_LENGTH)
						begin
							tx = `PICTURE_WIDTH+1;
							ty = `PICTURE_LENGTH+1;
							tsignal = 1;
							outputsignal = 1;
						end
				end
		end
		
	//store and start write
	always@(posedge clk)
		begin
			if(reset && outputsignal && osignal)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							outputPicture[i] = thresPicture[i];
						end
					outputsignal = 0;
					osignal = 0;
					wx = 0;
					wy = 0;
				end
		end
		
	//write and output
	always@(posedge clk)
		begin
			if(reset && wx < `PICTURE_LENGTH+1 && wy < `PICTURE_WIDTH+1)
				begin
					if (outputPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy] != 0)
						th = 8'hff;
					else th = 8'h00;
					//if(thresDirect[wx*`PICTURE_WIDTH+wy] == 0)
					//$fwrite(fileO, "%c%c%c", sobelCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					$fwrite(fileO, "%c%c%c", th,th,th);
					//$fwrite(fileO, "%c%c%c", sobelPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					//$fwrite(fileO, "%c%c%c", sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					//$fwrite(fileO, "%c%c%c", gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					//$fwrite(fileO, "%c%c%c", readsPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],readsPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],readsPictureCache[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					wx = wx + 1;
					if(wx == `PICTURE_LENGTH)
						begin
							wx = 0;
							wy = wy + 1;
						end
					if(wy == `PICTURE_WIDTH)
						begin
							wx = `PICTURE_WIDTH+1;
							wy = `PICTURE_LENGTH+1;
							$display("> %s is created.\n", fw);
							$fclose(fileO);
							osignal = 1;
							
							temp = num%10;
							temps = num/10;
							temps = temps%10;
							fw = {"./output/", "1", "0"+temps, "0"+temp, ".bmp"};
							num = num + 1;
							if(num == 116)
								begin
									$stop;
								end
							fileO = $fopen(fw, "wb");
							
							for(p=1; p<55; p=p+1)
								begin
									$fwrite(fileO, "%c", FILE_HEADER[p]);
								end
						end
				end
		end

endmodule
