`timescale 1ns / 1ps

`define DATA_WIDTH 8
`define PICTURE_LENGTH 200
`define PICTURE_WIDTH 200
`define PICTURE_MIX	40000

`define EOF		32'hFFFF_FFFF
`define NULL		0
`define LEN_HEADER	54   // 0x36

module canny_advanced(clk, reset);
	reg	[`DATA_WIDTH-1:0]		readsPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		readsPictureCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		gaussPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		gaussPictureCache[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		sobelPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		directPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		nmsPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		nmsdirectPicture[0:`PICTURE_MIX-1];
	reg	[`DATA_WIDTH-1:0]		thresPicture[0:`PICTURE_MIX-1];
	
	reg	[`DATA_WIDTH-1:0]		FILE_HEADER[0:`LEN_HEADER-1];
	reg 		[31:0]					tpSum, Sum;
	reg signed	 	[31:0] 			Gx, Gy, fGx, fGy, Gxadd, Gyadd, Gxyadd;
	reg 	readcache, gausscache;
	
	reg 	[`DATA_WIDTH-1:0]			gf[0:24];	// 5x5 Gaussian Filter
	integer			sobelX[0:8];//	3x3 SobelX Filter
	integer			sobelY[0:8];// 3x3 SobelY Filter
	
	integer rx, ry, gx, gy, sx, sy, dx, dy, nx, ny, ndx, ndy, tx, ty, wx, wy;
	integer i, j, k, count;
	integer gi, gj, si, sj;
	
	integer 				fileI, fileO, c, r;
	
	input clk, reset;
	
	always@(negedge reset)
		begin
			rx = 0; ry = 0;
			gx = 202; gy = 202; sx = 202; sy = 202;
			dx = 202; dy = 202; nx = 202; ny = 202;
			ndx = 202; ndy = 202; tx = 202; ty = 202;
			wx = 0; wy = 0;
			tpSum = 0; count = 0; readcache = 0; gausscache = 0;
			Gxadd = 0; Gyadd = 0; Gxyadd = 0; Gx = 0; Gy = 0;
 			gi = -2; gj = -2; si = -1; sj = -1;
			
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
				end
				
			fileI = $fopen("kodim22_200.bmp","rb");
			if (fileI == `NULL) $display("> FAIL: The file is not exist !!!\n");
			else	           $display("> SUCCESS : The file was read successfully.\n");
				
			r = $fread(FILE_HEADER, fileI, 0, `LEN_HEADER); 
			
			fileO = $fopen("2.OutputGradient.bmp","wb");
			for(k=1; k<55; k=k+1)
				begin
					$fwrite(fileO, "%c", FILE_HEADER[k]);
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && rx < 201 && ry < 201)
				begin
					c = $fgetc(fileI);
					c = $fgetc(fileI);
					readsPicture[(`PICTURE_LENGTH-rx-1)*`PICTURE_WIDTH+ry] = $fgetc(fileI);
					rx = rx + 1;
					if(rx == 200)
						begin
							rx = 0;
							ry = ry + 1;
						end
					if(ry == 200)
						begin
							rx = 201;
							ry = 201;
							readcache = 1;
							$fclose(fileI);
						end
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && readcache)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							readsPictureCache[i] = readsPicture[i];
							gaussPicture[i] = readsPicture[i];
						end
					readcache = 0;
					gx = 2;
					gy = 2;
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && gx < 201 && gy < 201)
				begin
					if(gx > 1 && gx < 198 && gy > 1 && gy < 198)
						begin
							Sum = readsPictureCache[(gx+gi)*`PICTURE_WIDTH+gy+gj]*gf[(2+gi)*5+(2+gj)];
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
									gaussPicture[gx*`PICTURE_WIDTH+gy] = (tpSum>>7);
									tpSum = 0;
									gx = gx + 1;
								end
							if(gx == 198)
								begin
									gx = 2;
									gy = gy + 1;
								end
							if(gy == 198)
								begin
									gx = 201;
									gy = 201;
									gausscache = 1;
								end
						end
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && gausscache)
				begin
					for (i = 0; i < `PICTURE_MIX; i=i+1)
						begin
							gaussPictureCache[i] = gaussPicture[i];
							sobelPicture[i] = gaussPicture[i];
						end
					gausscache = 0;
					sx = 1;
					sy = 1;
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && sx > 0 && sx < 199 && sy > 0 && sy < 199)
				begin
					Gxadd = gaussPictureCache[(sx+si)*`PICTURE_WIDTH+sy+sj]*sobelX[(1+si)*3+(1+sj)];
					Gx = Gx + Gxadd;
					Gyadd = gaussPictureCache[(sx+si)*`PICTURE_WIDTH+sy+sj]*sobelY[(1+si)*3+(1+sj)];
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
										
							sobelPicture[sx*`PICTURE_WIDTH+sy] = (Gxyadd>>3);
							Gx = 0;
							Gy = 0;
							sx = sx + 1;
						end
					if(sx == 199)
						begin
							sx = 1;
							sy = sy + 1;
						end
					if(sy == 199)
						begin
							sx = 201;
							sy = 201;
						end
				end
		end
		
	always@(posedge clk)
		begin
			if(reset && sx == 201 && sy == 201 && wx < 201 && wy < 201)
				begin
					$fwrite(fileO, "%c%c%c", sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],sobelPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					//$fwrite(fileO, "%c%c%c", gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],gaussPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					//$fwrite(fileO, "%c%c%c", readsPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],readsPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy],readsPicture[(`PICTURE_LENGTH-wx-1)*`PICTURE_WIDTH+wy]);
					wx = wx + 1;
					if(wx == 200)
						begin
							wx = 0;
							wy = wy + 1;
						end
					if(wy == 200)
						begin
							wx = 201;
							wy = 201;
							$display("> 0.OutputOrigin.bmp is created.\n");
							$fclose(fileO);
						end
				end
		end

endmodule
