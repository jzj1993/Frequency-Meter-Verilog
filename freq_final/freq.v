module freq (clk, key, mode, signal_f, signal_t, segdat, segpos,
calc, m, mt, div, clk_cnt, gate);

//======================= divider =======================//

input clk;
reg clk_1k;
reg unsigned [12:0]cnt = 0;
// 注：板子上使用16MHz时钟源，此处分频系数为'd8000 - 'd1
// 仿真时，为了让仿真速度更快，使用16kHz时钟源，将此处预分频系数改为'd8-'d1
parameter pre_div = 'd8 - 'd1; // 16k:8-1, 16M:8000-1

// 16M(16k) --> 1k , div = 8_000
always @(posedge clk) begin
	cnt <= cnt + 1'b1;
	if(cnt == pre_div) begin
		cnt <= 'd0;
		clk_1k <= ~clk_1k;
	end
end

reg [1:0]pos = 0; // 5ms*4  200Hz/4
reg unsigned [2:0]cnt_d = 0;

// 1k --> 5ms*4 = 20ms (200/4 = 50Hz) , div = 5
always @(posedge clk_1k) begin
	cnt_d <= cnt_d + 1'b1;
	if(cnt_d == 'd4) begin
		cnt_d <= 'd0;
		pos <= pos + 1'b1;
	end
end

input key;
// input mode;
output reg mode = 0;
reg [1:0]flag_key = 0;

// --> 100Hz, 10ms ( key_scan )
always @(posedge pos[1]) begin
	flag_key[0] = key;
	if(flag_key == 'b10)
		mode <= !mode;
	flag_key = flag_key << 1;
end

reg clk_10;
reg unsigned [2:0] cnt_10 = 0;

// 100Hz --> 10Hz, div = 5
always @(posedge pos[0]) begin
	cnt_10 <= cnt_10 + 1'b1;
	if(cnt_10 == 'd4) begin
		cnt_10 <= 'd0;
		clk_10 <= ~clk_10;
	end
end


//======================= counter and calculator =======================//

input signal_f; // 1~20kHz
input signal_t; // 1Hz
// output wire signal_t;

wire clk_gate, clk_in;

/** MUX
 *  mode: 0 测频法     1 测周法
 *  gate: clk_10       signal_t
 *  cnt:  signal_f     clk_1k
 */
assign clk_gate = ~mode & clk_10 | mode & signal_t;
assign clk_in   = ~mode & signal_f | mode & clk_1k;

// gate=1: count, gate=0: calculate
output reg gate;
always @(posedge clk_gate) gate=~gate;

reg [1:0] flag_gate;
output reg unsigned [15:0]m;  // 测频法和除法用的计数器(自动十进位)
output reg unsigned [11:0]mt; // < 4096 测周法用的计数器(直接增计数)

parameter ss_idle = 2'b00,
          ss_count_mt = 2'b01,
		  ss_count_m = 2'b10,
          ss_calc = 2'b11;

reg [1:0] ss = ss_idle;

// calc: 0 clk_in, 1: clk
output reg calc = 0;
output wire clk_cnt;
assign clk_cnt = ~calc & clk_in | calc & clk;

output reg unsigned [19:0]div; // < 1000_000

// clear and count
always @(posedge clk_cnt) begin
	flag_gate[0] = gate;
	case(ss)
	ss_idle:
		begin
			if(flag_gate == 'b01) begin // posedge of gate: clear and start count
				if(mode == 0) begin
					m <= 0;
					ss <= ss_count_m;
				end
				else begin
					mt <= 0;
					ss <= ss_count_mt;
				end
			end
		end
	ss_calc,
	ss_count_m:
		begin
			if(ss_calc == ss && div < mt) begin // calc finish
				digi_buf <= m;
				ss <= ss_idle;
				calc <= 0;
			end
			else if(ss_count_m == ss && flag_gate == 'b10) begin // negedge of gate: disp & idle
				digi_buf = m;
				ss <= ss_idle;
			end
			else begin
				if(ss_calc == ss) begin
					div = div - mt;
				end
				m[3:0] <= m[3:0] + 1'b1;
				if(m[3:0] == 'd9) begin
					m[3:0] <= 'd0;
					m[7:4] <= m[7:4] + 1'b1;
					if(m[7:4] == 'd9) begin
						m[7:4] <= 'd0;
						m[11:8] <= m[11:8] + 1'b1;
						if(m[11:8] == 'd9) begin
							m[11:8] <= 'd0;
							m[13:12] <= m[13:12] + 1'b1;
						end
					end
				end
			end
		end
	ss_count_mt:
		begin
			mt <= mt + 1'b1;
			if(flag_gate == 'b10) begin // negedge of gate: start calc
				if(mt > 200) begin
					m = 0;
					ss = ss_calc;
					div <= 1000_000;
					calc <= 1;
				end
				else begin // mt < 200: cancel calc
					ss <= ss_idle;
				end
			end
		end
	endcase
	flag_gate <= flag_gate << 1;
end


//======================= display =======================//

output reg [3:0]segpos;
output reg [7:0]segdat;
reg [15:0]digi_buf = 0;
reg [3:0]dispdat;
reg point;

// display
always @(pos) begin
	case(pos)
	0: begin segpos <= 4'b0001; dispdat[3:0] <= digi_buf[3:0]  ; point <= 1; end
	1: begin segpos <= 4'b0010; dispdat[3:0] <= digi_buf[7:4]  ; point <= 1; end
	2: begin segpos <= 4'b0100; dispdat[3:0] <= digi_buf[11:8] ; point <= mode; end //测频,小数点:左2
	3: begin segpos <= 4'b1000; dispdat[3:0] <= digi_buf[15:12]; point <= !mode; end //测周,小数点:左1
	endcase
end

always @(dispdat) begin
	case (dispdat)
	0:segdat[6:0] = 7'h40; // hC0  h40
	1:segdat[6:0] = 7'h79; // hF9  h79
	2:segdat[6:0] = 7'h24; // hA4  h24
	3:segdat[6:0] = 7'h30; // hB0  h30
	4:segdat[6:0] = 7'h19; // h99  h19
	5:segdat[6:0] = 7'h12; // h92  h12
	6:segdat[6:0] = 7'h02; // h82  h02
	7:segdat[6:0] = 7'h78; // hF8  h78
	8:segdat[6:0] = 7'h00; // h80  h00
	9:segdat[6:0] = 7'h10; // h90  h10
	default:segdat[6:0] = 7'h0;
	endcase
	segdat[7] = point;
end

endmodule
