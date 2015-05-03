module right(clk_16MHZ,sig_1HZ,sig_KHZ,rst,select,BCD,ctl,Dout,result,N);
	input clk_16MHZ;
	input sig_1HZ,sig_KHZ;
	input rst,select;
	
	reg decide = 0;
	
	//decide seclct
	reg temp_select;
	reg unsigned [4:0] select_counter;
	always @(posedge clk_1KHZ or negedge rst)
	begin
		if(!rst)
		begin
			temp_select <= select;
			select_counter <= 'd30;
		end
		
		else
		begin
			select_counter <= select_counter -'b1;
			if(select_counter == 'd0)
			begin
				if(temp_select == select)
				begin
					select_counter <= 'd30;
				end
				
				else
				begin
					decide <= ~decide;
					select_counter <= 'd30;
				end
			end
		end
	end
	//get 10HZ clock for cepin
	reg clk_10HZ = 0;
	reg unsigned [19:0] counter = 'd80_0000;
	
	always @(posedge clk_16MHZ)
	begin
		counter <= counter - 'b1;
		if(counter == 'd1)
		begin
			counter <= 'd80_0000;
			clk_10HZ <= ~clk_10HZ;
		end
	end
	
	//get 1KHZ clock for cezhou
	reg clk_1KHZ = 0;
	reg unsigned [12:0] counter_1KHZ = 'd8000;
	
	always @(posedge clk_16MHZ)
	begin
		counter_1KHZ <= counter_1KHZ - 'b1;
		if(counter_1KHZ == 'd1)
		begin
			counter_1KHZ <= 'd8000;
			clk_1KHZ <= ~clk_1KHZ;
		end
	end	
	
	//result for cepin
	reg en = 0;
	reg unsigned [10:0] cnt;
	always @(posedge sig_KHZ or negedge rst)
	begin
		if(!rst)
			cnt <= 'd0;
		else
			if(en)
				cnt <= cnt + 'b1; 	
	end
	
	//N for cezhou
	reg unsigned [10:0] temp_N;
	always @(posedge clk_1KHZ or negedge rst)
	begin
		if(!rst)
		begin
			temp_N <= 'd0;
		end
		
		else
			if(en)
				temp_N <= temp_N + 'b1;
				
	end
	//cezhou * cepin main state machine
	reg unsigned [3:0] state;
	output unsigned [10:0] result;
	reg unsigned [10:0] result;
	output unsigned [10:0] N;
	reg unsigned [10:0] N;
	reg unsigned [13:0] asd;      //result to asd
	reg unsigned [19:0] qwe;
	
	reg temp;
	always @(posedge clk_16MHZ or negedge rst)
	begin
		if(!rst)
		begin
			state <= 'd0;
			result <= 'd0;
			asd <= 'd0;
			N <= 'd0;
			temp <= 'b0;
			qwe = 'd100_0000;
		end
		
		else
		begin
			case(state)		
				'd0:			begin									
									state <= decide? 'd1:'d9;
									temp <= decide? clk_10HZ : sig_1HZ;
								end
								
				'd1:			begin
									if(temp == clk_10HZ)
									begin
										temp <= clk_10HZ;
										state <= 'd1;
									end
									
									else
									begin
										state <= 'd2;
										temp <= clk_10HZ;
										en <= 'b1;
									end
								end
								
				'd2:			begin
									if(temp == clk_10HZ)
									begin
										en <= 'b1;
										temp <= clk_10HZ;
										state <= 'd2;
									end
									
									else
									begin
										en <= 'b0;
										result <= cnt;
										state <= 'd3;
									end
								end
								
				'd9:			begin
									if(sig_1HZ == temp)
									begin
										temp <= sig_1HZ;
										state <= 'd9;
									end
									
									else
									begin
										state <= 'd10;
										temp <= sig_1HZ;
										en <= 'b1;
									end
								end
								
				'd10:			begin
									if(sig_1HZ == temp)
									begin
										temp <= sig_1HZ;
										state <= 'd10;
									end	
										
									else
									begin
										en <= 'b0;
										state <= 'd11;
										N <= temp_N;
									end
								end
								
				'd11:			begin
									if(qwe > N)
									begin
										state <= 'd11;
										qwe <= qwe - N;
										result <= result + 'b1;
									end
									
									else
									begin
										state <= 'd3;
										
									end
								end
								
				'd3:			begin
									if(result > 'd0)
									begin
										state <= 'd3;
										result <= result - 'b1;
										asd[3:0] <= asd[3:0] + 'b1;
										if(asd[3:0] == 'd9)
										begin
											asd[3:0] <= 'd0;
											asd[7:4] <= asd[7:4] + 'b1;

											if(asd[7:4] == 'd9)
											begin
												asd[7:4] <= 'd0;
												asd[11:8] <= asd[11:8] + 'b1;
										
												if(asd[11:8] == 'd9)
												begin
													asd[11:8] <= 'd0;
													asd[13:12] <= asd[13:12] + 'b1;
												end
											end
										end
									end
									
									else
										state <= 'd3;
								end
			endcase
		end
	end
	
	//----------------------led light
	reg unsigned [2:0] light_state;
	always @(posedge clk_1KHZ or negedge rst)
	begin
		if(!rst)
		begin
			light_state <= 'd0;
			ctl <= 4'b1111;
			BCD <= 'd6;
		end
		
		else
		begin
			case(light_state)
			'd0:	begin
						light_state <= 'd1;
						BCD <= 'd10;
						ctl <= decide? 4'b0100 : 4'b1000;
					end
					
			'd1:	begin
						light_state <= 'd2;
						ctl<=4'b0001;
						BCD <= asd[3:0];
					end
					
			'd2:	begin
						light_state <= 'd3;
						BCD <= asd[7:4];
						ctl<=4'b0010;
					end
					
			'd3:	begin
						light_state <= 'd4;
						BCD <= asd[11:8];
						ctl<=4'b0100;
					end
					
			'd4:	begin
						light_state <= 'd0;
						BCD <= asd[13:12];
						ctl<=4'b1000;
					end
			
			
			endcase
		end
	end
	//----------------------led light chushi----------
	output unsigned [3:0] BCD;
	reg unsigned [3:0] BCD;
	output unsigned [7:0] Dout;	
	output unsigned [3:0] ctl;
	reg unsigned [7:0] Dout;
	reg unsigned [3:0] ctl;
		
	always @(BCD)
	begin
		case(BCD)
			'd0: Dout<=8'b00000011;
			'd1: Dout<=8'b10011111;
			'd2: Dout<=8'b00100101;
			'd3: Dout<=8'b00001101;
			'd4: Dout<=8'b10011001;
			'd5: Dout<=8'b01001001;
			'd6: Dout<=8'b01000001;
			'd7: Dout<=8'b00011111;
			'd8: Dout<=8'b00000001;
			'd9: Dout<=8'b00001001;
			'd10:Dout<=8'b11111110;
		
			default:Dout<=8'b11111111;//LEDÈ«Ãð
		endcase
	end
endmodule