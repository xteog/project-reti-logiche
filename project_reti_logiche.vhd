----------------------------------------------------------------------------------
--                         Politecnico di Milano                                --
--              Prova Finale - Progetto di Reti Logiche 2023/2024               --
--                                                                              --
--  Matteo Gallo (10710694)                                                     --
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);
        i_k   : in std_logic_vector(9 downto 0);
        
        o_done : out std_logic;
        
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;

architecture arch of project_reti_logiche is

    component fsm is
        port (
            i_start : in std_logic;
            i_done : std_logic;
            
            clk, rst : in std_logic;
            
            o_en_reg : out std_logic;
            o_sel_mux_en_cred : out std_logic;
            o_mem_en : out std_logic;
            o_mem_we : out std_logic;
            o_done : out std_logic
        );
    end component;
    component reg_last_value is
        port (
            input : in std_logic_vector(7 downto 0);
            enable : in std_logic;
            clk, rst : in std_logic;
            changed : out std_logic;
            output : out std_logic_vector(7 downto 0)
        );
    end component;
    component reg_credibility is
        port (
            enable : in std_logic;
            restart : in std_logic;
            clk, rst : in std_logic;
            output : out std_logic_vector(7 downto 0)
        );
    end component;
    component multiplexer is
        port (
            in_0 : in std_logic_vector(7 downto 0);
            in_1 : in std_logic_vector(7 downto 0);
            sel : in std_logic;
            output : out std_logic_vector(7 downto 0)
        );
    end component;
    component counter is
        port (
            i_offset : in std_logic_vector(15 downto 0);
            i_len : in std_logic_vector(9 downto 0);
            i_enable : in std_logic;
            clk, rst : in std_logic;
            o_curr : out std_logic_vector(15 downto 0);
            o_done : out std_logic
        );
    end component;
    
    signal last_value, credibility : std_logic_vector(7 downto 0);
    signal en_counter, en_reg, sel_mux_en_cred, done, rst_cred : std_logic;
    signal reset : std_logic;
begin

    reset <= i_rst or (not i_start);

    o_mem_we <= en_counter;
    FSM_1 : fsm
        port map (
            i_start => i_start,
            i_done => done,
            clk => i_clk,
            rst => i_rst,
            o_en_reg => en_reg,
            o_sel_mux_en_cred => sel_mux_en_cred,
            o_mem_en => o_mem_en,
            o_mem_we => en_counter,
            o_done => o_done
        );
        
    addrIndex : counter
        port map (
            i_offset => i_add,
            i_len => i_k,
            i_enable => en_counter,
            clk => i_clk,
            rst => reset,
            o_curr => o_mem_addr,
            o_done => done
        );

    value : reg_last_value
        port map(
            input => i_mem_data,
            enable => en_reg,
            clk => i_clk,
            rst => reset,
            changed => rst_cred,
            output => last_value
        );
    
    cred : reg_credibility
        port map (
            enable => sel_mux_en_cred,
            restart => rst_cred,
            clk => i_clk,
            rst => reset,
            output => credibility
        );
        
    mux : multiplexer
        port map (
            in_0 => last_value,
            in_1 => credibility,
            sel => sel_mux_en_cred,
            output => o_mem_data
        );
end arch;


------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity fsm is
    port (
        i_start : in std_logic;
        i_done : std_logic;
        
        clk, rst : in std_logic;
        
        o_en_reg : out std_logic;
        o_sel_mux_en_cred : out std_logic;
        o_mem_en : out std_logic;
        o_mem_we : out std_logic; 
        o_done : out std_logic
    );
end fsm;

architecture arch of fsm is
    type state_type is (INIT, READ_EVEN, WAIT_READ, WRITE_EVEN, WRITE_ODD);
    signal current_state: state_type;
begin

    stateReg: process(clk, rst)
    begin
        if rst = '1' then
            current_state <= INIT;
        elsif clk = '1' and clk'event then
            case current_state is
                when INIT =>
                    if i_start = '1' then
                        current_state <= READ_EVEN;
                    end if;
                when READ_EVEN =>
                    current_state <= WAIT_READ;
                when WAIT_READ =>
                    if i_start = '0' then
                        current_state <= INIT;
                    elsif i_done = '0' then
                        current_state <= WRITE_EVEN;
                    end if;
                when WRITE_EVEN =>
                    current_state <= WRITE_ODD;
                when WRITE_ODD =>
                    current_state <= READ_EVEN;
         end case;
        end if;
    end process;
        
    outputValue: process(current_state, i_start, i_done)
    begin
        
        o_en_reg <= '0';
        o_sel_mux_en_cred <= '0';
        o_mem_we <= '0';
        o_mem_en <= '0';
        o_done <= '0';
        
        case current_state is                
            when INIT =>
                o_mem_en <= '0';
                o_done <= '0';
            when READ_EVEN =>
                o_en_reg <= '0';
                o_sel_mux_en_cred <= '0';
                o_mem_we <= '0';
                o_mem_en <= '1';
                o_done <= '0';
            when WAIT_READ => 
                o_done <= i_done;
                if i_start = '1' and i_done = '0' then
                    o_en_reg <= '1';
                    o_sel_mux_en_cred <= '0';
	                o_mem_we <= '0';
                    o_mem_en <= '1';
                else
                    o_mem_en <= '0';
                end if;
            when WRITE_EVEN =>
                o_en_reg <= '0';
                o_sel_mux_en_cred <= '0';
                o_mem_we <= '1';
                o_mem_en <= '1';
                o_done <= '0';
            when WRITE_ODD =>
                o_en_reg <= '0';
                o_sel_mux_en_cred <= '1';
                o_mem_we <= '1';
                o_mem_en <= '1';
                o_done <= '0';
        end case;
    end process;

end arch;


------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    port (
        i_offset : in std_logic_vector(15 downto 0);
        i_len : in std_logic_vector(9 downto 0);
        i_enable : in std_logic;
        clk, rst : in std_logic;
        o_curr : out std_logic_vector(15 downto 0);
        o_done : out std_logic
    );
end counter;

architecture arch of counter is
    signal current_index : std_logic_vector(10 downto 0);
begin
    
    o_curr <= std_logic_vector(unsigned(i_offset) + unsigned(current_index));

    process (clk, rst)
        constant ZERO : std_logic_vector(10 downto 0)
            := (others => '0');
    begin
        if rst = '1' then
            current_index <= ZERO;
            o_done <= '0';
        elsif clk = '1' and clk'event then
            if current_index < (i_len & '0') then
                if i_enable = '1' then
                    current_index <= std_logic_vector(unsigned(current_index) + 1);
                end if;
                o_done <= '0';
            else
                o_done <= '1';
            end if;
        end if;
    end process;
    
end arch;


------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity reg_last_value is
    port(
        input : in std_logic_vector(7 downto 0);
        enable : in std_logic;
        clk, rst : in std_logic;
        changed : out std_logic;
        output : out std_logic_vector(7 downto 0)
    );
end reg_last_value;
    
architecture arch of reg_last_value is
    signal stored_value : std_logic_vector(7 downto 0);
begin
    
    output <= stored_value;
    
    process(clk, rst)
        constant ZERO : std_logic_vector(7 downto 0)
            := (others => '0');
    begin
        
        if rst = '1' then
            stored_value <= ZERO;
        elsif clk = '1' and clk'event then
            if not (input = ZERO) and enable = '1' then
                stored_value <= input;
                changed <= '1';
            else
                changed <= '0';
            end if;
        end if;
     end process;
     
end arch;


------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_credibility is
    port(
        enable : in std_logic;
        restart : in std_logic;
        clk, rst : in std_logic;
        output : out std_logic_vector(7 downto 0)
    );
end reg_credibility;
    
architecture arch of reg_credibility is
    constant MAX_VALUE : std_logic_vector(7 downto 0) 
        := (7 downto 5 => '0', others => '1');
    signal credibility : std_logic_vector(7 downto 0);
begin

    output <= credibility;

    process(clk, rst)
        constant ZERO : std_logic_vector(7 downto 0) 
            := (others => '0');
    begin
        if rst = '1' then
            credibility <= ZERO;
        elsif clk = '1' and clk'event then
            if restart = '1' then
                credibility <= MAX_VALUE;
            elsif credibility > ZERO and enable = '1' then
                credibility <= std_logic_vector(unsigned(credibility) - 1);
            end if;
        end if;
     end process;

end arch;


------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity multiplexer is
    port (
        in_0 : in std_logic_vector(7 downto 0);
        in_1 : in std_logic_vector(7 downto 0);
        sel : in std_logic;
        output : out std_logic_vector(7 downto 0)
    );
end multiplexer;

architecture arch of multiplexer is
begin
    output <= in_0 when sel = '0' else
              in_1 when sel = '1';
end arch;
