library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity audio_controller is
 port (
   clk : in std_logic;                    -- 50 MHz system clock
   enable : in std_logic;                 -- Enable audio output
   rotary_value : in unsigned(3 downto 0); -- Rotary encoder value (0-15)
   audio_out : out std_logic              -- PWM audio output
 );
end audio_controller;

architecture RTL of audio_controller is
 
 -- Clock divider signals (50MHz -> 100kHz)
 signal clk_div_counter : unsigned(8 downto 0) := (others => '0');
 signal sample_enable : std_logic := '0';
 
 -- Sine wave generator signals
 signal phase_acc : unsigned(15 downto 0) := (others => '0');
 signal table_addr : unsigned(2 downto 0);
 signal sine_data : signed(7 downto 0);
 
 -- Phase step lookup: maps rotary_value (0-15) to a musical note
 -- (natural notes G3 to A5). Output frequency = step * 100 kHz / 65536.
 signal step_size : unsigned(15 downto 0);
 
 -- PWM modulator signals
 signal pwm_counter : unsigned(7 downto 0) := (others => '0');
 signal data_unsigned : unsigned(7 downto 0);
 signal pwm_internal : std_logic;
 
 -- Sine wave lookup table: quarter wave, 8 samples
 -- Entry i = round(127 * sin((i + 0.5) * pi / 16))
 type sine_table_type is array (0 to 7) of signed(7 downto 0);
 constant sine_table : sine_table_type := (
   "00001100",  -- 12
   "00100101",  -- 37
   "00111100",  -- 60
   "01010001",  -- 81
   "01100010",  -- 98
   "01110000",  -- 112
   "01111001",  -- 121
   "01111110"   -- 126
 );

begin

-- Combinational lookup: map rotary_value to precalculated step_size
-- step = round(f_note * 65536 / 100000)
with rotary_value select
    step_size <=
        to_unsigned(129, 16) when "0000",  -- G3 (~197 Hz)
        to_unsigned(144, 16) when "0001",  -- A3
        to_unsigned(162, 16) when "0010",  -- B3
        to_unsigned(172, 16) when "0011",  -- C4
        to_unsigned(193, 16) when "0100",  -- D4
        to_unsigned(216, 16) when "0101",  -- E4
        to_unsigned(229, 16) when "0110",  -- F4
        to_unsigned(257, 16) when "0111",  -- G4
        to_unsigned(289, 16) when "1000",  -- A4 (~441 Hz)
        to_unsigned(324, 16) when "1001",  -- B4
        to_unsigned(343, 16) when "1010",  -- C5
        to_unsigned(386, 16) when "1011",  -- D5
        to_unsigned(431, 16) when "1100",  -- E5
        to_unsigned(458, 16) when "1101",  -- F5
        to_unsigned(512, 16) when "1110",  -- G5
        to_unsigned(575, 16) when "1111",  -- A5
        to_unsigned(649, 16) when others;  -- B5

-- Clock divider process (50MHz -> 100kHz)
process(clk)
begin
 if rising_edge(clk) then
   if clk_div_counter = 499 then  -- 50MHz / 500 = 100kHz
     clk_div_counter <= (others => '0');
     sample_enable <= '1';
   else
     clk_div_counter <= clk_div_counter + 1;
     sample_enable <= '0';
   end if;
 end if;
end process;

-- Generate table address from phase accumulator
table_addr <= phase_acc(13 downto 11) when phase_acc(14) = '0' else 
              7 - phase_acc(13 downto 11);

-- Output sine wave sample with proper quadrant handling
sine_data <= sine_table(to_integer(table_addr)) when phase_acc(15) = '0' else 
             -sine_table(to_integer(table_addr));

-- Phase accumulator process (sine wave generation)
process(clk)
begin
 if rising_edge(clk) then
   if sample_enable = '1' then
     phase_acc <= phase_acc + step_size;
   end if;
 end if;
end process;

-- Convert signed audio data to unsigned (add 128 offset)
data_unsigned <= unsigned(sine_data xor "10000000");

-- PWM counter process
process(clk)
begin
 if rising_edge(clk) then
   if pwm_counter = 254 then
     pwm_counter <= (others => '0');
   else
     pwm_counter <= pwm_counter + 1;
   end if;
 end if;
end process;

-- Generate PWM signal
pwm_internal <= '1' when pwm_counter < data_unsigned else '0';

-- Output control
audio_out <= pwm_internal when enable = '1' else '0';

end RTL;

