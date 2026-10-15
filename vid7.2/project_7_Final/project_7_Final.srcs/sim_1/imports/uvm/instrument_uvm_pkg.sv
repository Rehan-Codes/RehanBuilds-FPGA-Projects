`timescale 1ns / 1ps
package instrument_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    localparam int UART_BIT_TICKS = 32; // Accelerated 32 kHz/1000 baud DUT only.
    `uvm_analysis_imp_decl(_cmd)
    `uvm_analysis_imp_decl(_rsp)

    // UART pin transaction; reset is a control item, not a UART byte.
    class instrument_uart_item extends uvm_sequence_item;
        rand bit [7:0] data;
        rand bit [3:0] idle_bits;
        bit bad_stop = 0;
        bit do_reset = 0;
        bit is_random = 0;
        bit is_burst = 0;
        `uvm_object_utils(instrument_uart_item)
        function new(string name="instrument_uart_item"); super.new(name); endfunction
    endclass

    class instrument_uart_sequencer extends uvm_sequencer #(instrument_uart_item);
        `uvm_component_utils(instrument_uart_sequencer)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
    endclass

    class instrument_uart_driver extends uvm_driver #(instrument_uart_item);
        `uvm_component_utils(instrument_uart_driver)
        virtual instrument_uvm_if vif;
        uvm_analysis_port #(instrument_uart_item) cmd_ap;
        function new(string name, uvm_component parent);
            super.new(name,parent); cmd_ap=new("cmd_ap",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual instrument_uvm_if)::get(this,"","vif",vif))
                `uvm_fatal("NO_VIF","driver virtual interface unavailable")
        endfunction
        task drive_reset(instrument_uart_item req);
            // Let outstanding UART TX replies drain before changing the golden model.
            repeat (80 * UART_BIT_TICKS) @(negedge vif.clk);
            if (vif.tx_busy || !vif.fifo_empty)
                `uvm_error("RESET_DRAIN", "UART/FIFO did not drain before reset")
            cmd_ap.write(req); // Reset prediction ONLY AFTER old replies have drained.
            vif.btnC = 1'b1;
            repeat (9) @(negedge vif.clk);
            vif.btnC = 1'b0;
            repeat (20) @(negedge vif.clk);
            if (vif.led[3:0] !== 4'd0 || vif.led[6:5] !== 2'b00)
                `uvm_error("RESET", "Configuration and sticky error flags were not cleared")
        endtask
        task drive_uart(instrument_uart_item req);
            @(negedge vif.clk);
            vif.RsRx = 1'b0;
            repeat (UART_BIT_TICKS) @(negedge vif.clk);
            for (int i=0;i<8;i++) begin
                vif.RsRx = req.data[i];
                repeat (UART_BIT_TICKS) @(negedge vif.clk);
            end
            vif.RsRx = req.bad_stop ? 1'b0 : 1'b1;
            repeat (UART_BIT_TICKS) @(negedge vif.clk);
            vif.RsRx = 1'b1;
            repeat (int'(req.idle_bits) * UART_BIT_TICKS) @(negedge vif.clk);
            if (req.bad_stop) begin
                // Allow the synchronized framing-error flag to reach the LED.
                repeat (2 * UART_BIT_TICKS) @(negedge vif.clk);
                if (vif.led[6] !== 1'b1)
                    `uvm_error("BAD_STOP", "Malformed stop bit did not latch LED6")
            end
        endtask
        task run_phase(uvm_phase phase);
            instrument_uart_item req;
            vif.RsRx = 1'b1;
            forever begin
                seq_item_port.get_next_item(req);
                if (req.do_reset) drive_reset(req);
                else begin
                    cmd_ap.write(req);  // Predict normal UART commands in transmission order.
                    drive_uart(req);
                end
                seq_item_port.item_done();
            end
        endtask
    endclass

    // Passive UART TX monitor (samples the external serial pin, not DUT internals).
    class instrument_uart_monitor extends uvm_monitor;
        `uvm_component_utils(instrument_uart_monitor)
        virtual instrument_uvm_if vif;
        uvm_analysis_port #(instrument_uart_item) rsp_ap;
        function new(string name, uvm_component parent);
            super.new(name,parent); rsp_ap=new("rsp_ap",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual instrument_uvm_if)::get(this,"","vif",vif))
                `uvm_fatal("NO_VIF","monitor virtual interface unavailable")
        endfunction
        task run_phase(uvm_phase phase);
            instrument_uart_item item;
            forever begin
                @(negedge vif.RsTx);
                repeat (UART_BIT_TICKS + UART_BIT_TICKS/2) @(posedge vif.clk);
                item=instrument_uart_item::type_id::create("uart_reply");
                for (int i=0;i<8;i++) begin
                    item.data[i]=vif.RsTx;
                    repeat (UART_BIT_TICKS) @(posedge vif.clk);
                end
                if (vif.RsTx !== 1'b1)
                    `uvm_error("TX_STOP","DUT UART stop bit was not high")
                rsp_ap.write(item);
            end
        endtask
    endclass

    class instrument_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(instrument_scoreboard)
        uvm_analysis_imp_cmd #(instrument_uart_item,instrument_scoreboard) cmd_imp;
        uvm_analysis_imp_rsp #(instrument_uart_item,instrument_scoreboard) rsp_imp;
        typedef struct packed {
            logic [7:0] reply;
            logic [1:0] freq;
            logic [1:0] duty;
            bit sample_config;
        } prediction_t;
        prediction_t expected[$];
        logic [1:0] freq_model=0, duty_model=0;
        int replies_checked=0, invalid_count=0, status_count=0;
        int bad_frame_count=0, reset_count=0, random_count=0, burst_count=0;
        int pwm_bins_hit=0;
        bit seen_pwm[4][4];
        int sample_freq, sample_duty;
        int command_kind; // 0=duty,1=freq,2=status,3=invalid,4=frame,5=reset

        covergroup pwm_settings_cg;
            cp_freq: coverpoint sample_freq { bins f0={0}; bins f1={1}; bins f2={2}; bins f3={3}; }
            cp_duty: coverpoint sample_duty { bins d0={0}; bins d1={1}; bins d2={2}; bins d3={3}; }
            freq_x_duty: cross cp_freq, cp_duty;
        endgroup
        covergroup command_types_cg;
            cp_command: coverpoint command_kind {
                bins duty={0}; bins freq={1}; bins status={2};
                bins invalid={3}; bins bad_frame={4}; bins reset={5};
            }
        endgroup
        function new(string name, uvm_component parent);
            super.new(name,parent);
            cmd_imp=new("cmd_imp",this); rsp_imp=new("rsp_imp",this);
            pwm_settings_cg=new(); command_types_cg=new();
        endfunction
        function void write_cmd(instrument_uart_item t);
            prediction_t p;
            if (t.is_random) random_count++;
            if (t.is_burst) burst_count++;
            if (t.do_reset) begin
                if (expected.size()!=0)
                    `uvm_error("RESET_PENDING",$sformatf("%0d outstanding replies at reset",expected.size()))
                freq_model=0; duty_model=0;
                reset_count++;
                command_kind=5;
                command_types_cg.sample();
                return;
            end
            if (t.bad_stop) begin
                bad_frame_count++;
                command_kind=4; command_types_cg.sample();
                return; // Invalid frame does not enter the DUT command FIFO.
            end
            p.sample_config=0;
            case(t.data)
                8'h30,8'h31,8'h32,8'h33: begin
                    duty_model=t.data[1:0]; p.reply=t.data;
                    p.sample_config=1; command_kind=0;
                end
                8'h34,8'h35,8'h36,8'h37: begin
                    freq_model=t.data[1:0]; p.reply=t.data;
                    p.sample_config=1; command_kind=1;
                end
                8'h3F: begin
                    int unsigned nib;
                    nib=(int'(freq_model)<<2)|int'(duty_model);
                    p.reply=(nib<10)?(8'h30+nib):(8'h41+nib-10);
                    status_count++; command_kind=2;
                end
                default: begin
                    p.reply=8'h21; invalid_count++; command_kind=3;
                end
            endcase
            p.freq=freq_model; p.duty=duty_model;
            command_types_cg.sample();
            expected.push_back(p);
        endfunction
        function void write_rsp(instrument_uart_item t);
            prediction_t p;
            if (expected.size()==0) begin
                `uvm_error("EXTRA_REPLY",$sformatf("Unexpected UART reply 0x%02h",t.data))
                return;
            end
            p=expected.pop_front();
            if (t.data !== p.reply) begin
                `uvm_error("WRONG_REPLY",$sformatf("Expected 0x%02h, got 0x%02h",p.reply,t.data))
                return;
            end
            replies_checked++;
            if (p.sample_config) begin
                sample_freq=int'(p.freq); sample_duty=int'(p.duty);
                pwm_settings_cg.sample();
                if (!seen_pwm[sample_freq][sample_duty]) begin
                    seen_pwm[sample_freq][sample_duty]=1;
                    pwm_bins_hit++;
                end
            end
        endfunction
        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            if (expected.size()!=0)
                `uvm_error("PENDING",$sformatf("%0d UART replies did not arrive",expected.size()))
            if (pwm_bins_hit!=16)
                `uvm_error("COVERAGE",$sformatf("Only %0d/16 PWM configuration bins hit",pwm_bins_hit))
            if (replies_checked < 75 || invalid_count<1 || status_count<16 || bad_frame_count<1
                || reset_count<1 || random_count<40 || burst_count<12)
                `uvm_error("INCOMPLETE","Directed, random, burst, error, or reset scenario missing")
            `uvm_info("FINAL_SCOREBOARD",$sformatf("matched_replies=%0d pwm_bins=%0d/16 status=%0d invalid=%0d malformed=%0d random=%0d burst=%0d reset=%0d outstanding=%0d",replies_checked,pwm_bins_hit,status_count,invalid_count,bad_frame_count,random_count,burst_count,reset_count,expected.size()),UVM_NONE)
        endfunction
    endclass

    // Cycle-by-cycle checker of actual PWM output and period-boundary updates.
    class instrument_pwm_checker extends uvm_monitor;
        `uvm_component_utils(instrument_pwm_checker)
        virtual instrument_uvm_if vif;
        int cycles_checked=0, updates_seen=0;
        bit prev_valid=0;
        logic [1:0] prev_freq,prev_duty;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual instrument_uvm_if)::get(this,"","vif",vif))
                `uvm_fatal("NO_VIF","PWM checker has no interface")
        endfunction
        task run_phase(uvm_phase phase);
            int period_ticks, high_ticks;
            bit expected_pwm;
            forever begin
                @(negedge vif.clk);
                if (vif.rst) prev_valid=0;
                else begin
                    period_ticks=32 >> int'(vif.active_freq);
                    high_ticks=(period_ticks*int'(vif.active_duty))/4;
                    expected_pwm=(int'(vif.pwm_counter)<high_ticks);
                    if (int'(vif.pwm_counter)>=period_ticks)
                        `uvm_error("PWM_RANGE","PWM counter outside period")
                    if (vif.pwm_out !== expected_pwm)
                        `uvm_error("PWM_OUTPUT",$sformatf("freq=%0d duty=%0d tick=%0d got=%0b expected=%0b",vif.active_freq,vif.active_duty,vif.pwm_counter,vif.pwm_out,expected_pwm))
                    cycles_checked++;
                    if (prev_valid && ((prev_freq!=vif.active_freq)||(prev_duty!=vif.active_duty))) begin
                        updates_seen++;
                        if (vif.pwm_counter!==0)
                            `uvm_error("NOT_AT_BOUNDARY","PWM settings changed mid-period")
                    end
                    prev_freq=vif.active_freq; prev_duty=vif.active_duty; prev_valid=1;
                end
            end
        endtask
        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            if (cycles_checked<200 || updates_seen<10)
                `uvm_error("PWM_INCOMPLETE","Not enough PWM output/boundary checks")
            `uvm_info("FINAL_PWM",$sformatf("output_cycles_checked=%0d period_boundary_updates=%0d",cycles_checked,updates_seen),UVM_NONE)
        endfunction
    endclass

    // Observation/checking of FIFO stress; not a promise of full/overflow coverage.
    class instrument_fifo_checker extends uvm_monitor;
        `uvm_component_utils(instrument_fifo_checker)
        virtual instrument_uvm_if vif;
        int max_occupancy=0, nonempty_cycles=0, frame_errors_seen=0;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual instrument_uvm_if)::get(this,"","vif",vif))
                `uvm_fatal("NO_VIF","FIFO checker has no interface")
        endfunction
        task run_phase(uvm_phase phase);
            forever begin
                @(negedge vif.clk);
                if (!vif.rst) begin
                    if (int'(vif.fifo_count)>max_occupancy) max_occupancy=int'(vif.fifo_count);
                    if (!vif.fifo_empty) nonempty_cycles++;
                    if (vif.rx_frame_error) frame_errors_seen++;
                    if (vif.fifo_overflow)
                        `uvm_error("QUEUE_OVERFLOW","FIFO overflow: injected traffic exceeded supported rate")
                    if (vif.fifo_underflow)
                        `uvm_error("QUEUE_UNDERFLOW","FIFO underflow in UART command controller")
                end
            end
        endtask
        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            if (nonempty_cycles==0 || frame_errors_seen==0)
                `uvm_error("FIFO_INCOMPLETE","FIFO was never occupied or bad frame never observed")
            `uvm_info("FINAL_FIFO",$sformatf("peak_occupancy=%0d/8 nonempty_cycles=%0d framing_pulses=%0d overflow=0 underflow=0",max_occupancy,nonempty_cycles,frame_errors_seen),UVM_NONE)
        endfunction
    endclass

    class instrument_uart_agent extends uvm_agent;
        `uvm_component_utils(instrument_uart_agent)
        instrument_uart_sequencer sqr;
        instrument_uart_driver drv;
        instrument_uart_monitor mon;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr=instrument_uart_sequencer::type_id::create("sqr",this);
            drv=instrument_uart_driver::type_id::create("drv",this);
            mon=instrument_uart_monitor::type_id::create("mon",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class instrument_env extends uvm_env;
        `uvm_component_utils(instrument_env)
        instrument_uart_agent agent;
        instrument_scoreboard scoreboard;
        instrument_pwm_checker pwm_checker;
        instrument_fifo_checker fifo_checker;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent=instrument_uart_agent::type_id::create("agent",this);
            scoreboard=instrument_scoreboard::type_id::create("scoreboard",this);
            pwm_checker=instrument_pwm_checker::type_id::create("pwm_checker",this);
            fifo_checker=instrument_fifo_checker::type_id::create("fifo_checker",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.drv.cmd_ap.connect(scoreboard.cmd_imp);
            agent.mon.rsp_ap.connect(scoreboard.rsp_imp);
        endfunction
    endclass

    class instrument_full_sequence extends uvm_sequence #(instrument_uart_item);
        `uvm_object_utils(instrument_full_sequence)
        int unsigned seed=7;
        function new(string name="instrument_full_sequence"); super.new(name); endfunction
        task send_cmd(bit [7:0] command,int idle=12,bit bad=0,bit burst=0);
            instrument_uart_item req;
            req=instrument_uart_item::type_id::create("directed_req");
            start_item(req);
            req.data=command; req.bad_stop=bad;
            req.idle_bits=4'(idle); req.is_burst=burst;
            finish_item(req);
        endtask
        task reset_dut();
            instrument_uart_item req;
            req=instrument_uart_item::type_id::create("reset_req");
            start_item(req); req.do_reset=1; finish_item(req);
        endtask
        task body();
            instrument_uart_item req;
            if ($value$plusargs("SEED=%d",seed)) begin end
            `uvm_info("SEED",$sformatf("Deterministic transaction seed=%0d",seed),UVM_NONE)
            send_cmd(8'h3F);
            // Directed functional coverage closure: all 16 requested configurations.
            for (int f=0;f<4;f++) begin
                send_cmd(8'(8'h34+f));
                for (int d=0;d<4;d++) begin
                    send_cmd(8'(8'h30+d));
                    send_cmd(8'h3F); // independent serial status readback
                end
            end
            send_cmd(8'h5A);        // unsupported ASCII, expect '!'
            send_cmd(8'h55,12,1);   // malformed UART stop, NO response
            // Twelve back-to-back serial frames, intentionally no additional idle bits.
            for (int b=0;b<12;b++) begin
                if ((b%5)==0) send_cmd(8'h3F,0,0,1);
                else if ((b%2)==0) send_cmd(8'(8'h30+(b%4)),0,0,1);
                else send_cmd(8'(8'h34+(b%4)),0,0,1);
            end
            send_cmd(8'h3F,12);
            // Seed-controlled UVM constrained-random commands and variable idle gaps.
            for (int i=0;i<40;i++) begin
                req=instrument_uart_item::type_id::create("random_req");
                req.srandom(seed+(i*31));
                start_item(req);
                if (!req.randomize() with {
                    data inside {[8'h30:8'h37],8'h3F,8'h5A};
                    idle_bits inside {[0:3]};
                }) `uvm_fatal("RANDOMIZE","Constrained-random transaction generation failed")
                req.is_random=1;
                finish_item(req);
            end
            send_cmd(8'h3F,12);
            // Reset after all traffic has drained, then test status/reconfiguration.
            reset_dut();
            send_cmd(8'h3F,12); // must return '0'
            send_cmd(8'h36,12); // freq=4kHz
            send_cmd(8'h32,12); // duty=50%
            send_cmd(8'h3F,12); // must return 'A'
        endtask
    endclass

    class instrument_uvm_test extends uvm_test;
        `uvm_component_utils(instrument_uvm_test)
        instrument_env env;
        virtual instrument_uvm_if vif;
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env=instrument_env::type_id::create("env",this);
            if (!uvm_config_db #(virtual instrument_uvm_if)::get(this,"","vif",vif))
                `uvm_fatal("NO_VIF","test virtual interface unavailable")
        endfunction
        task run_phase(uvm_phase phase);
            instrument_full_sequence seq;
            phase.raise_objection(this);
            wait(vif.rst===1'b0);
            repeat(12) @(posedge vif.clk);
            seq=instrument_full_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            // All remaining UART replies must arrive before report_phase.
            repeat (25 * UART_BIT_TICKS) @(posedge vif.clk);
            if (env.scoreboard.expected.size()!=0)
                `uvm_error("WAIT_REPLIES",$sformatf("%0d outstanding replies",env.scoreboard.expected.size()))
            phase.drop_objection(this);
        endtask
        function void final_phase(uvm_phase phase);
            uvm_report_server server;
            int unsigned err_count;
            int unsigned fatal_count;
            int unsigned run_seed;
            super.final_phase(phase);
            server=uvm_report_server::get_server();
            err_count=server.get_severity_count(UVM_ERROR);
            fatal_count=server.get_severity_count(UVM_FATAL);
            run_seed=7;
            if ($value$plusargs("SEED=%d",run_seed)) begin end
            if ((err_count==0)&&(fatal_count==0))
                $display("FINAL_RESULT: PASS UVM seed=%0d errors=0 fatals=0",run_seed);
            else
                $display("FINAL_RESULT: FAIL UVM seed=%0d errors=%0d fatals=%0d",run_seed,err_count,fatal_count);
        endfunction
    endclass
endpackage
