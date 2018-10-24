typedef enum {E_config,E_read,E_reset,E_nop,E_memory} icmd;//input command 

//Sequence item
class lcd_seq_item extends uvm_sequence_item;
     `uvm_object_utils(lcd_seq_item)
     //rand bit[1:0] inb;
     //Signal declaration
     	icmd opcode;
	reg [31:0]in_address;	
	reg [31:0]in_data;
	integer memory_lcd[integer];
	integer expect_lcd[$];
	integer expect_frame;	
	integer expect_pixel;	
	int out_reset;	
	reg[23:0] out_lcdvd;	
	reg[3:0] out_frame;
	logic out_lcdfp;
	integer out_counter_clock;
     function new(string name = "lcd_seq_item");
          super.new(name);
     endfunction: new
 
endclass: lcd_seq_item

//sequencer
typedef uvm_sequencer#(lcd_seq_item) lcd_seqr;

//Sequence
//
class lcd_seq extends uvm_sequence#(lcd_seq_item);
     `uvm_object_utils(lcd_seq)
     function new(string name = "lcd_seq");
          super.new(name);
     endfunction: new
	string comand;
       integer file_address,file_data; 
	integer File,status;
	integer memory_lcd[integer];	
	integer expect_lcd[$];
	integer  expect_pixel;	
	integer  expect_frame;	
		string line;
		string cmd_format[string] = '{
                              "w":"w %h %h",
                              "m":"m %h %h",
                              "d":"d %h",
                              "n":"n %d",
                              "a":"a %d",
                              "r":"r"
                              };

// from internet
/*nt code;
string line, command;

if (cmd_format.exists(command))
      code = $sscanf(line,cmd_format[command],a[0],a[1],a[2],a[3],a[4],a[5],... a[max]);
    else
    $error("bad command");
*/
// end
int test_file_number;
string test_file_name;
     task body();
          lcd_seq_item seq_itm;
          seq_itm = lcd_seq_item::type_id::create("seq_itm");
	for(test_file_number =0 ; test_file_number <= 15 ; test_file_number++) begin		
	       test_file_name = {"t",$sformatf("%0d",test_file_number),".txt"};
	       	File = $fopen(test_file_name,"r");
       		$display("file name : %s ", test_file_name);	       
	 while (!$feof(File)) begin
		status = $fgets(line,File);
		status = $sscanf(line,"%s",comand);
		if(cmd_format.exists(comand))
      			status= $sscanf(line,cmd_format[comand],file_address,file_data);
		//$display("insidde : %s : %h : %h : %s", comand,file_address,file_data,test_file_name);
    		//else
    		//	$error("bad command");
		if(comand == "w")begin
               	start_item(seq_itm);
			seq_itm.opcode = E_config;
			seq_itm.in_address = file_address;
			seq_itm.in_data = file_data;
                finish_item(seq_itm);
		end else if (comand == "r") begin
				start_item(seq_itm);
					seq_itm.opcode = E_reset;
               			finish_item(seq_itm);

		end else if (comand == "m") begin
			memory_lcd[file_address] = file_data;
		end else if (comand == "d") begin
			expect_lcd.push_back(file_address);
		end else if (comand == "n") begin
			expect_frame = file_address;
		end else if (comand == "a") begin
			expect_pixel = file_address;
		end 
	     		//$display(" me %s: %h", comand,file_address,test_file_name);
	end
	  $fclose (File);
               	start_item(seq_itm);
			seq_itm.opcode = E_nop;
                finish_item(seq_itm);
		start_item(seq_itm);
			seq_itm.opcode = E_memory;	
			seq_itm.memory_lcd = memory_lcd;
	     		seq_itm.expect_lcd = expect_lcd;
	     		seq_itm.expect_frame= expect_frame;
	     		seq_itm.expect_pixel= expect_pixel;
			//$display("\n\n\n%d: %d : %d",expect_frame,expect_pixel,expect_lcd.size());
			
                finish_item(seq_itm);
	repeat (600000) begin
               	start_item(seq_itm);
			seq_itm.opcode = E_nop;
                finish_item(seq_itm);
	end
	     		expect_lcd.delete();
end

     endtask: body
endclass: lcd_seq
//driver
class lcd_driver extends uvm_driver#(lcd_seq_item);
     `uvm_component_utils(lcd_driver)
	//message stuff
     uvm_analysis_port#(lcd_seq_item) sb_expect_out;
     //end of message stuff   
     //Interface declaration
     //protected virtual simpleadder_if vif;
     virtual AHBIF v_ahbif;
     lcd_seq_item seq_itm_dr;
     integer memory_lcd[integer];
     integer expect_lcd[$];
     integer expect_frame;
     integer expect_pixel;
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          sb_expect_out = new(.name("sb_expect_out"), .parent(this));
	  if(!uvm_config_db #(virtual AHBIF)::get(null,"uvm_test_top","ahbif",this.v_ahbif))
		  `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".v_ahbif"})
	  `uvm_info("FIFO_WR_DRIVER","This is Build Phase - fifo wr driver", UVM_LOW)

     endfunction: build_phase

 
     task run_phase(uvm_phase phase);
	     v_ahbif.mHGRANT<=1; 
	     v_ahbif.mHREADY<=1;
	     v_ahbif.mHRESP<=0;
	     //Slave 
	     v_ahbif.HSEL<=0; 
	     v_ahbif.HADDR<=0;
	     v_ahbif.HWRITE<=0;
	     v_ahbif.HTRANS<=0;
	     v_ahbif.HSIZE<=3'b010;
	     v_ahbif.HBURST<=0;
	     v_ahbif.HRESET<=0;
	fork
	     forever begin
		     @(posedge v_ahbif.HCLK)
		     seq_item_port.get_next_item(seq_itm_dr);
		     if(seq_itm_dr.opcode == E_reset)begin
	     			v_ahbif.HRESET<=1;
			repeat(10) @( v_ahbif.HCLK); 
	     		v_ahbif.HRESET<=0;
		     end else if(seq_itm_dr.opcode == E_config)begin
	     		v_ahbif.HWRITE<=1; 
	     		v_ahbif.HADDR<=seq_itm_dr.in_address;
	     		v_ahbif.HBURST<=0;
	     		v_ahbif.HSEL<=1;
	     		v_ahbif.HTRANS<=2'b10;
	     		v_ahbif.HWDATA<= #10 seq_itm_dr.in_data;

			//$display("data in config %h : %h\n",seq_itm_dr.in_address, seq_itm_dr.in_data);
		     end else if(seq_itm_dr.opcode == E_nop)begin
	     		v_ahbif.HWRITE<=0; 
	     		v_ahbif.HSEL<=1;
	     		v_ahbif.HBURST<=0;
	     		v_ahbif.HTRANS<=2'b0;
		     end else if(seq_itm_dr.opcode == E_memory)begin
			     memory_lcd = seq_itm_dr.memory_lcd;
			     expect_lcd = seq_itm_dr.expect_lcd;
			     expect_frame = seq_itm_dr.expect_frame;
			     expect_pixel = seq_itm_dr.expect_pixel;
			     seq_itm_dr = new();
	     		     seq_itm_dr.expect_lcd = expect_lcd;
	     		     seq_itm_dr.expect_frame = expect_frame;
	     		     seq_itm_dr.expect_pixel = expect_pixel;
	     		     sb_expect_out.write(seq_itm_dr);
		//$display("i am here %h: %h : %d",expect_frame,expect_pixel,expect_lcd.size());

		     end

		     seq_item_port.item_done();
		     //Code for read operation
		     if(v_ahbif.mHWRITE == 0 && v_ahbif.mHADDR != 0 ) begin
			     case(v_ahbif.mHTRANS)
				     	2'b00 : begin
						v_ahbif.mHRDATA<= 5;			
					end

				     	2'b01 : begin
						v_ahbif.mHRDATA<= 0;			
					end
				     	2'b10 : begin
						v_ahbif.mHRDATA<= memory_lcd[v_ahbif.mHADDR];
						//$display("\n\nI am here %h",memory_lcd[v_ahbif.mHADDR]);			
					end
				     	2'b11 : begin
						v_ahbif.mHRDATA<= memory_lcd[v_ahbif.mHADDR];
					end
			     endcase
		     end
		     if(v_ahbif.mHBUSREQ ==1 ) begin
	     					v_ahbif.mHGRANT<=  1; 

			end else begin
	     					v_ahbif.mHGRANT<= 0; 
		     end
		     //end of code for read operation

	     end
	               //Our code here
     join_none
          endtask: run_phase
endclass: lcd_driver

//Monitor
//
class lcd_monitor_after extends uvm_monitor;
     `uvm_component_utils(lcd_monitor_after)
 
     uvm_analysis_port#(lcd_seq_item) mon_ap_after;
 
     virtual LCDOUT v_lcdout;
     virtual AHBIF v_ahbif;
 
     lcd_seq_item sa_tx;
 
     /*covergroup simpleadder_cg;
          ina_cp:     coverpoint sa_tx_cg.ina;
          inb_cp:     coverpoint sa_tx_cg.inb;
          cross ina_cp, inb_cp;
     endgroup: simpleadder_cg
     */

     function new(string name, uvm_component parent);
          super.new(name, parent);
          //simpleadder_cg = new;
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          mon_ap_after= new("mon_ap_after", this);
	if(!uvm_config_db #(virtual LCDOUT)::get(null,"uvm_test_top","lcdout",this.v_lcdout))
		  `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".v_lcdout"})
	  `uvm_info("FIFO_MONITER","This is Build Phase - ", UVM_LOW)
  
  if(!uvm_config_db #(virtual AHBIF)::get(null,"uvm_test_top","ahbif",this.v_ahbif))
		  `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".v_ahbif"})
	  `uvm_info("FIFO_WR_DRIVER","This is Build Phase - fifo wr driver", UVM_LOW)
 

 
          void'(uvm_resource_db#(virtual LCDOUT)::read_by_name(.scope("uvm_test_top"), .name("lcdout"), .val(v_lcdout)));
     endfunction: build_phase
	bit [15:0] frame_track;
       logic [3:0] frame_rec;	
       integer control=0;
       bit track_frame = 0;
       integer counter_clock = 0;
     task run_phase(uvm_phase phase);
          //Our code here
	  fork
		  forever begin
			  @(posedge (v_lcdout.LCDDCLK) or posedge (v_ahbif.HRESET))
			  if(!v_ahbif.HRESET) begin
			  /*if(frame_track[v_lcdout.lcd_frame] == 0) begin
				case(control)
					'd0 : begin
						if(frame_track[v_lcdout.lcd_frame] == 0) begin 
							frame_rec = v_lcdout.lcd_frame;
							control = 'd1;	
						end
					end
					'd1 : begin
						if(frame_rec !=  v_lcdout.lcd_frame) begin
							frame_track[frame_rec] = 1;
							control = 'd0;
						$display("debug_me %h",v_lcdout.lcd_frame );	
						end
					end
				endcase
			end*/
		       /*case (track_frame)
			       'd0 : begin
			       end
			       'd1 : begin
			       end
		       endcase*/
		       if(v_lcdout.LCDENA_LCDM ==1  ) begin
	  			sa_tx = new();
				sa_tx.out_lcdvd = v_lcdout.LCDVD;
				sa_tx.out_frame = v_lcdout.lcd_frame;
				sa_tx.out_reset = v_ahbif.HRESET;
				mon_ap_after.write(sa_tx);
				//$display("I data: %h ",v_lcdout.LCDVD);
			  end

		      	if(v_lcdout.LCDFP && track_frame == 0)begin
				sa_tx = new();
				sa_tx.out_lcdfp = v_lcdout.LCDFP;
				sa_tx.out_counter_clock = counter_clock;
				mon_ap_after.write(sa_tx);
				track_frame = 1;
				$display("I valid: %h ",v_lcdout.LCDVD);
			end
			case (control) 
				00 : begin
					control = ((v_lcdout.LCDFP) && (track_frame == 0)) ? 1 : 0 ;
				end
				01 : begin
					counter_clock = counter_clock+1;
					control = (v_lcdout.LCDFP) ? 0 : 1;
				end
			endcase

			 			  //frame_rec = v_lcdout.lcd_frame;
		  	end else begin
				//frame_track = '{16{0}};
				control = 0;
				sa_tx = new();
				sa_tx.out_reset = v_ahbif.HRESET;
				mon_ap_after.write(sa_tx);
				track_frame = 0;
				$display("Reset: %h ",v_ahbif.HRESET);
			end	
		end
	  join_none;

     endtask: run_phase
endclass: lcd_monitor_after
//After monitor
class lcd_monitor_before extends uvm_monitor;
     `uvm_component_utils(lcd_monitor_before)
 
     uvm_analysis_port#(lcd_seq_item) mon_ap_before;
 
     virtual AHBIF v_ahbif;
     lcd_seq_item sa_rx;

 
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
	if(!uvm_config_db #(virtual AHBIF)::get(null,"uvm_test_top","ahbif",this.v_ahbif))
		  `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".v_ahbif"})
	  `uvm_info("FIFO_WR_DRIVER","This is Build Phase - fifo wr driver", UVM_LOW)
 
          //void'(uvm_resource_db#(virtual simpleadder_if)::read_by_name (.scope("ifs"), .name("simpleadder_if"), .val(vif)));
          mon_ap_before = new(.name("mon_ap_before"), .parent(this));
     endfunction: build_phase
 
     task run_phase(uvm_phase phase);
          //Our code here
	  /*fork
		  forever begin
			  @(posedge v_ahbif.HCLK);
			  if (v_ahbif.HWRITE) begin
			  	sa_rx = new();
                          	sa_rx.in_address<=v_ahbif.HADDR;
                          	sa_rx.in_data<=v_ahbif.HWDATA;
			  	mon_ap_before.write(sa_rx);
		  	  end
			  if((v_ahbif.mHWRITE==0) && (v_ahbif.mHTRANS == 2'b10 || v_ahbif.mHTRANS == 2'b11)) begin
			  	sa_rx = new();
                          	sa_rx.memory_lcd[v_ahbif.mHADDR]<=v_ahbif.mHRDATA;
			  	mon_ap_before.write(sa_rx);
		  	  end

			  //$display("%h : %h",v_ahbif.HADDR,v_ahbif.HWDATA);
		  end
	  join_none*/
     endtask: run_phase
endclass: lcd_monitor_before


//agent
class lcd_agent extends uvm_agent;
     `uvm_component_utils(lcd_agent)
 
     //Analysis ports to connect the monitors to the scoreboard
     uvm_analysis_port#(lcd_seq_item) agent_ap_before;
     uvm_analysis_port#(lcd_seq_item) agent_ap_after;
 
     lcd_seqr        sa_seqr;
     lcd_driver        sa_drvr;
     lcd_monitor_before    sa_mon_before;
     lcd_monitor_after    sa_mon_after;
 
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
 
          agent_ap_before    = new(.name("agent_ap_before"), .parent(this));
          agent_ap_after    = new(.name("agent_ap_after"), .parent(this));
 
          sa_seqr        = lcd_seqr::type_id::create("my_seqr",this);
          sa_drvr        = lcd_driver::type_id::create("my_driver",this);
          sa_mon_before    = lcd_monitor_before::type_id::create("my_monitor_before",this);
          sa_mon_after    = lcd_monitor_after::type_id::create("my_monitor_after",this);
     endfunction: build_phase
 
     function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          sa_drvr.seq_item_port.connect(sa_seqr.seq_item_export);
          sa_drvr.sb_expect_out.connect(agent_ap_before);
          //sa_mon_before.mon_ap_before.connect(agent_ap_before);
          sa_mon_after.mon_ap_after.connect(agent_ap_after);
     endfunction: connect_phase
endclass: lcd_agent

//scoreboard
class lcd_scoreboard extends uvm_scoreboard;
     `uvm_component_utils(lcd_scoreboard)
 
     uvm_analysis_export #(lcd_seq_item) sb_export_before;
     uvm_analysis_export #(lcd_seq_item) sb_export_after;
 
     uvm_tlm_analysis_fifo #(lcd_seq_item) before_fifo;
     uvm_tlm_analysis_fifo #(lcd_seq_item) after_fifo;
 
     lcd_seq_item transaction_before;
     lcd_seq_item transaction_after;
 
     function new(string name, uvm_component parent);
          super.new(name, parent);
          transaction_before    = new("transaction_before");
          transaction_after    = new("transaction_after");
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          sb_export_before    = new("sb_export_before", this);
          sb_export_after        = new("sb_export_after", this);
 
          before_fifo        = new("before_fifo", this);
          after_fifo        = new("after_fifo", this);
     endfunction: build_phase
 
     function void connect_phase(uvm_phase phase);
          sb_export_before.connect(before_fifo.analysis_export);
          sb_export_after.connect(after_fifo.analysis_export);
     endfunction: connect_phase
 //Declaration
 integer expect_lcd[$];
 integer expect_lcdvd;
 integer expect_frame;
 integer expect_pixel;
 int counter=0;
 int check_sm=0;
     task run();
	  //`uvm_info("RUN_PHASE_SCOARENOARD","This is Build Phase - ", UVM_LOW)
	 fork
	  forever begin
		  if(expect_lcd.size <=0 ) begin
               		before_fifo.get(transaction_before);
	       		expect_pixel = transaction_before.expect_pixel; 
	       		expect_frame = transaction_before.expect_frame; 
	       		expect_lcd = transaction_before.expect_lcd;
		       	
		end else if(expect_lcd.size >0) begin
               		after_fifo.get(transaction_after);
			counter = ((transaction_after.out_reset == 1) )  ? 0 : ((counter > 0 )? counter+1 : ((transaction_after.out_lcdfp === 1 ) ? 1 : 0)) ;
			check_sm = (transaction_after.out_lcdfp == 1 && !transaction_after.out_reset ) ? 1: 0;
			if ((transaction_after.out_reset == 1) ) begin
			       $display("reset did happen: %h", counter);	
			end
			$display("counter : %h :%h : reset : %h | state : %h " , counter, 2*transaction_before.expect_pixel,transaction_after.out_reset, check_sm );
	       					//$display("\n scoreboard %h : %d : %h: %d : %d | %d ",transaction_after.out_lcdvd,expect_lcd.size(),expect_lcdvd,counter,((expect_lcd.size()+(counter-expect_pixel-2) )),expect_pixel);
			if(((counter > (expect_pixel+1)) && (counter <= (2*expect_pixel+1) )) && (((expect_lcd.size()+(counter-expect_pixel-2) )) == expect_pixel))begin 
						expect_lcdvd=expect_lcd.pop_front();
               					compare();
			end
		end
          end
  	join_none
     endtask: run
 
     virtual function void compare();
       		 if(transaction_after.out_lcdvd == expect_lcdvd) begin
       		        `uvm_info("compare", {"Test: OK!",$sformatf("expected : %h ; got : %h",expect_lcdvd,transaction_after.out_lcdvd  )}, UVM_LOW);
       		   end else begin
       		        `uvm_info("compare", {"Test: Fail!",$sformatf("expected : %h ; got : %h",expect_lcdvd,transaction_after.out_lcdvd  )}, UVM_LOW);
       		 end
     endfunction: compare
endclass: lcd_scoreboard


//env
class lcd_env extends uvm_env;
     `uvm_component_utils(lcd_env)
 
     lcd_agent sa_agent;
     lcd_scoreboard sa_sb;
 
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          sa_agent    = lcd_agent::type_id::create("my_agent",this);
          sa_sb        = lcd_scoreboard::type_id::create("my_sb",this);
     endfunction: build_phase
 
     function void connect_phase(uvm_phase phase);
          super.connect_phase(phase);
          sa_agent.agent_ap_before.connect(sa_sb.sb_export_before);
          sa_agent.agent_ap_after.connect(sa_sb.sb_export_after);
     endfunction: connect_phase
endclass: lcd_env

//test
class lcd_test extends uvm_test;
     `uvm_component_utils(lcd_test)
 
     lcd_env sa_env;
 
     function new(string name, uvm_component parent);
          super.new(name, parent);
     endfunction: new
 
     function void build_phase(uvm_phase phase);
          super.build_phase(phase);
          sa_env = lcd_env::type_id::create("my_env",this);
     endfunction: build_phase
 
     task run_phase(uvm_phase phase);
          lcd_seq sa_seq;
 
          phase.raise_objection(.obj(this));
               sa_seq = lcd_seq::type_id::create("my_seq",this);
               assert(sa_seq.randomize());
               sa_seq.start(sa_env.sa_agent.sa_seqr);
          phase.drop_objection(.obj(this));
     endtask: run_phase
endclass: lcd_test

