library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Rotary encoder interface: quadrature decoder plus push button debounce.
--
-- The sampled state machine is based on a design by my thesis mentor
-- A. Trost (Faculty of Electrical Engineering, University of Ljubljana);
-- extended to decode both rotation directions by Tomaz Perme.
--
-- The encoder has half-cycle detents: it rests at A/B = "00" or "11" and
-- one click moves between the two. A state machine sampled at 20 kHz arms
-- a step when the pair leaves a rest state (the line that moves first
-- gives the direction) and counts it only when the opposite rest state is
-- reached. Bounce around a rest state therefore never counts.

entity rotary_encoder_controller is
    Port (
        CLOCK_50 : in  std_logic;

        A       : in  std_logic;  -- Quadrature A (RotaryEncoder(0))
        B       : in  std_logic;  -- Quadrature B (RotaryEncoder(1))
        SW_raw  : in  std_logic;  -- Push button, raw

        SW_deb      : out std_logic;           -- Push button, debounced
        value       : out unsigned(3 downto 0); -- Position, wraps 0..15
        step_pulse  : out std_logic            -- One clock per step
    );
end rotary_encoder_controller;

architecture Behavioral of rotary_encoder_controller is

    -- A/B sampling: 50 MHz / 2500 = 20 kHz (50 us per sample)
    constant TICK_DIV : integer := 2500;
    signal tick_counter : unsigned(11 downto 0) := (others => '0');
    signal tick         : std_logic := '0';

    -- Push button: sampled at 1 kHz, accepted after 15 ms stable
    constant SW_DIV    : integer := 50000;
    constant SW_STABLE : integer := 15;
    signal sw_sample_counter : unsigned(15 downto 0) := (others => '0');
    signal sw_stable_count   : unsigned(3 downto 0) := (others => '0');
    signal sw_prev_sample    : std_logic := '0';
    signal sw_debounced      : std_logic := '0';

    -- A/B pair sampled on the tick: t(1) = B, t(0) = A
    signal t : std_logic_vector(1 downto 0) := "00";

    -- Decoder states: two rest positions, each with an up/down step armed
    type state_type is (REST0, ARM_UP0, ARM_DN0, REST1, ARM_UP1, ARM_DN1);
    signal st : state_type := REST0;

    signal pos_value      : unsigned(3 downto 0) := (others => '0');
    signal step_pulse_int : std_logic := '0';

begin

    -- Sampling tick generator
    process (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if tick_counter = TICK_DIV - 1 then
                tick_counter <= (others => '0');
                tick <= '1';
            else
                tick_counter <= tick_counter + 1;
                tick <= '0';
            end if;
        end if;
    end process;

    -- Push button debounce
    process (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if sw_sample_counter = SW_DIV - 1 then
                sw_sample_counter <= (others => '0');

                if SW_raw = sw_prev_sample then
                    if sw_stable_count < SW_STABLE then
                        sw_stable_count <= sw_stable_count + 1;
                    end if;
                else
                    sw_stable_count <= (others => '0');
                    sw_prev_sample  <= SW_raw;
                end if;

                if sw_stable_count = SW_STABLE then
                    sw_debounced <= sw_prev_sample;
                end if;
            else
                sw_sample_counter <= sw_sample_counter + 1;
            end if;
        end if;
    end process;

    -- Quadrature decoder
    --   00 -> 01 -> 11 : step up      11 -> 10 -> 00 : step up
    --   00 -> 10 -> 11 : step down    11 -> 01 -> 00 : step down
    -- Falling back to the starting rest state disarms the step (bounce).
    -- A direct 00 <-> 11 jump has no direction and only resynchronizes.
    process (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            step_pulse_int <= '0';

            if tick = '1' then
                t <= B & A;  -- decisions below use the previous sample

                case st is
                    when REST0 =>
                        if t = "01" then
                            st <= ARM_UP0;
                        elsif t = "10" then
                            st <= ARM_DN0;
                        elsif t = "11" then
                            st <= REST1;
                        end if;

                    when ARM_UP0 =>
                        if t = "11" then
                            pos_value <= pos_value + 1;
                            step_pulse_int <= '1';
                            st <= REST1;
                        elsif t = "00" then
                            st <= REST0;
                        end if;

                    when ARM_DN0 =>
                        if t = "11" then
                            pos_value <= pos_value - 1;
                            step_pulse_int <= '1';
                            st <= REST1;
                        elsif t = "00" then
                            st <= REST0;
                        end if;

                    when REST1 =>
                        if t = "10" then
                            st <= ARM_UP1;
                        elsif t = "01" then
                            st <= ARM_DN1;
                        elsif t = "00" then
                            st <= REST0;
                        end if;

                    when ARM_UP1 =>
                        if t = "00" then
                            pos_value <= pos_value + 1;
                            step_pulse_int <= '1';
                            st <= REST0;
                        elsif t = "11" then
                            st <= REST1;
                        end if;

                    when ARM_DN1 =>
                        if t = "00" then
                            pos_value <= pos_value - 1;
                            step_pulse_int <= '1';
                            st <= REST0;
                        elsif t = "11" then
                            st <= REST1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    SW_deb     <= sw_debounced;
    value      <= pos_value;
    step_pulse <= step_pulse_int;

end Behavioral;
