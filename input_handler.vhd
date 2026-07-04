library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Debounce for the push buttons and slide switches. Inputs are
-- sampled every 1 ms; an output changes only after 15 consecutive
-- samples with the same value.

entity input_handler is
    Port ( 
        CLOCK_50 : in std_logic;
        BUTTON : in std_logic_vector (3 downto 0);
        SWITCH : in std_logic_vector (3 downto 0);
        BUTTON_deb : out std_logic_vector (3 downto 0);
        SWITCH_deb : out std_logic_vector (3 downto 0)
    );
end input_handler;

architecture Behavioral of input_handler is
    -- 1 ms sample tick
    signal debounce_counter : unsigned (15 downto 0) := (others => '0');
    signal sample_enable : std_logic := '0';

    -- Stable-sample counters, one per input
    type debounce_array is array (0 to 3) of unsigned(3 downto 0);
    signal button_deb_count : debounce_array := (others => (others => '0'));
    signal switch_deb_count : debounce_array := (others => (others => '0'));
    
    signal BUTTON_prev : std_logic_vector (3 downto 0) := (others => '0');
    signal SWITCH_prev : std_logic_vector (3 downto 0) := (others => '0');
    
    signal BUTTON_deb_internal : std_logic_vector (3 downto 0) := (others => '0');
    signal SWITCH_deb_internal : std_logic_vector (3 downto 0) := (others => '0');
    
begin
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            debounce_counter <= debounce_counter + 1;
            if debounce_counter = 49999 then  -- 50 MHz / 50000 = 1 kHz
                debounce_counter <= (others => '0');
                sample_enable <= '1';
            else
                sample_enable <= '0';
            end if;
            
            -- Count how long each input has kept its value; any change
            -- restarts the count, 15 stable samples accept the value
            if sample_enable = '1' then
                for i in 0 to 3 loop
                    if BUTTON(i) = BUTTON_prev(i) then
                        if button_deb_count(i) < 15 then
                            button_deb_count(i) <= button_deb_count(i) + 1;
                        end if;
                    else
                        button_deb_count(i) <= (others => '0');
                        BUTTON_prev(i) <= BUTTON(i);
                    end if;

                    if button_deb_count(i) = 15 then
                        BUTTON_deb_internal(i) <= BUTTON(i);
                    end if;
                end loop;

                for i in 0 to 3 loop
                    if SWITCH(i) = SWITCH_prev(i) then
                        if switch_deb_count(i) < 15 then
                            switch_deb_count(i) <= switch_deb_count(i) + 1;
                        end if;
                    else
                        switch_deb_count(i) <= (others => '0');
                        SWITCH_prev(i) <= SWITCH(i);
                    end if;

                    if switch_deb_count(i) = 15 then
                        SWITCH_deb_internal(i) <= SWITCH(i);
                    end if;
                end loop;
            end if;
        end if;
    end process;
    
    BUTTON_deb <= BUTTON_deb_internal;
    SWITCH_deb <= SWITCH_deb_internal;
    
end Behavioral;
