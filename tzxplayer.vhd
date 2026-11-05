---------------------------------------------------------------------------------
-- TZX player
-- by György Szombathelyi
-- basic idea for the structure based on c1530 tap player by darfpga
--
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
USE IEEE.NUMERIC_STD.ALL;

entity tzxplayer is
generic (
	TZX_MS : integer := 64000;       -- CE periods for one milliseconds
	-- Default: ZX Spectrum
	NORMAL_PILOT_LEN    : integer := 2168;
	NORMAL_SYNC1_LEN    : integer := 667;
	NORMAL_SYNC2_LEN    : integer := 735;
	NORMAL_ZERO_LEN     : integer := 855;
	NORMAL_ONE_LEN      : integer := 1710;
	HEADER_PILOT_PULSES : integer := 8063; -- this is the header length
	NORMAL_PILOT_PULSES : integer := 3223  -- this is the non-header length

	-- Amstrad CPC
	--NORMAL_PILOT_LEN    : integer := 2000;
	--NORMAL_SYNC1_LEN    : integer := 855;
	--NORMAL_SYNC2_LEN    : integer := 855;
	--NORMAL_ZERO_LEN     : integer := 855;
	--NORMAL_ONE_LEN      : integer := 1710;
	--HEADER_PILOT_PULSES : integer := 4095; -- no difference between header and data pilot lengths
	--NORMAL_PILOT_PULSES : integer := 4095
);
port(
	clk             : in std_logic;
	ce              : in std_logic;
	restart_tape    : in std_logic;

	host_tap_in     : in unsigned(7 downto 0);          -- 8bits fifo input
	tzx_req         : buffer std_logic;                 -- request for new byte (edge trigger)
	tzx_ack         : in std_logic;                     -- new data available
	loop_start      : out std_logic;                    -- active for one clock if a loop starts
	loop_next       : out std_logic;                    -- active for one clock at the next iteration
	stop            : out std_logic;                    -- tape should be stopped
	stop48k         : out std_logic;                    -- tape should be stopped in 48k mode
	cass_read       : out std_logic;                    -- tape read signal
	cass_motor      : in  std_logic;                    -- 1 = tape motor is powered
	cass_running    : out std_logic                     -- tape is running
);
end tzxplayer;

architecture struct of tzxplayer is

signal tap_fifo_do    : unsigned( 7 downto 0);
signal tick_cnt       : unsigned(16 downto 0);
signal wave_cnt       : unsigned(23 downto 0);
signal wave_period    : std_logic;
signal wave_inverted  : std_logic;
signal skip_bytes     : std_logic;
signal playing        : std_logic;  -- 1 = tap or wav file is playing
signal bit_cnt        : unsigned(2 downto 0);

type tzx_state_t is (
	TZX_HEADER,
	TZX_NEWBLOCK,
	TZX_LOOP_START,
	TZX_LOOP_END,
	TZX_PAUSE,
	TZX_PAUSE2,
	TZX_STOP48K,
	TZX_HWTYPE,
	TZX_TEXT,
	TZX_MESSAGE,
	TZX_ARCHIVE_INFO,
	TZX_CUSTOM_INFO,
	TZX_GLUE,
	TZX_TONE,
	TZX_PULSES,
	TZX_DATA,
	TZX_NORMAL,
	TZX_TURBO,
	TZX_PLAY_TONE,
	TZX_PLAY_SYNC1,
	TZX_PLAY_SYNC2,
	TZX_PLAY_TAPBLOCK,
	TZX_PLAY_TAPBLOCK2,
	TZX_PLAY_TAPBLOCK3,
	TZX_PLAY_TAPBLOCK4,
	TZX_DIRECT,
	TZX_DIRECT2,
	TZX_DIRECT3,
	-- añadidos (Shaeon): saltar cuerpos de bloques no soportados, 0x2B y 0x19 (GDB)
	TZX_SKIP_LEN32,
	TZX_SKIP_LEN16,
	TZX_SKIP_LEN16X2,
	TZX_SKIP,
	TZX_LEVEL,
	TZX_GDB_HDR,
	TZX_GDB_CFG,
	TZX_GDB_PTAB,
	TZX_GDB_PRLE0,
	TZX_GDB_PRLE1,
	TZX_GDB_PRLE2,
	TZX_GDB_DTAB,
	TZX_GDB_DGET,
	TZX_GDB_SYM0,
	TZX_GDB_SYM1,
	TZX_GDB_SYM2,
	TZX_GDB_P0,
	TZX_GDB_P1,
	TZX_GDB_P2,
	TZX_GDB_P3,
	TZX_GDB_SYMDONE);

signal tzx_state: tzx_state_t;

signal tzx_offset     : unsigned( 7 downto 0);
signal pause_len      : unsigned(15 downto 0);
signal ms_counter     : unsigned(15 downto 0);
signal pilot_l        : unsigned(15 downto 0);
signal sync1_l        : unsigned(15 downto 0);
signal sync2_l        : unsigned(15 downto 0);
signal zero_l         : unsigned(15 downto 0);
signal one_l          : unsigned(15 downto 0);
signal pilot_pulses   : unsigned(15 downto 0);
signal last_byte_bits : unsigned( 3 downto 0);
signal data_len       : unsigned(23 downto 0);
signal pulse_len      : unsigned(15 downto 0);
signal end_period     : std_logic;
signal cass_motor_D   : std_logic;
signal motor_counter  : unsigned(21 downto 0);
signal loop_iter      : unsigned(15 downto 0);
signal data_len_dword : unsigned(31 downto 0);

-- GDB (bloque 0x19): las tablas de símbolos se guardan en una RAM local
type gdb_ram_t is array(0 to 1023) of unsigned(7 downto 0);
signal gdb_ram        : gdb_ram_t;
signal gdb_ra         : unsigned(9 downto 0);
signal gdb_wa         : unsigned(9 downto 0);
signal gdb_q          : unsigned(7 downto 0);
signal gdb_we         : std_logic;
signal gdb_wd         : unsigned(7 downto 0);
signal gdb_len        : unsigned(31 downto 0);
signal gdb_totp       : unsigned(31 downto 0);
signal gdb_totd       : unsigned(31 downto 0);
signal gdb_npp        : unsigned(7 downto 0);
signal gdb_npd        : unsigned(7 downto 0);
signal gdb_asp        : unsigned(8 downto 0);
signal gdb_asd        : unsigned(8 downto 0);
signal gdb_nb         : unsigned(3 downto 0);
signal gdb_np         : unsigned(7 downto 0);    -- pulsos por símbolo de la fase actual
signal gdb_stride     : unsigned(8 downto 0);    -- 2*np+1
signal gdb_base       : unsigned(9 downto 0);    -- 0: piloto, 512: datos
signal gdb_data       : std_logic;               -- 0: piloto/sincronismo, 1: datos
signal gdb_cnt        : unsigned(31 downto 0);
signal gdb_rep        : unsigned(15 downto 0);
signal gdb_sym        : unsigned(7 downto 0);
signal gdb_pp         : unsigned(9 downto 0);    -- dirección del pulso actual
signal gdb_pidx       : unsigned(7 downto 0);
signal gdb_flag       : unsigned(1 downto 0);
signal gdb_lo         : unsigned(7 downto 0);
signal gdb_byte       : unsigned(7 downto 0);
signal gdb_bits       : unsigned(3 downto 0);    -- bits que quedan en gdb_byte
signal gdb_got        : unsigned(3 downto 0);    -- bits ya leídos del símbolo

begin

cass_read <= wave_period;
cass_running <= playing;
tap_fifo_do <= host_tap_in;

-- RAM de tablas GDB: escritura y lectura registradas
process(clk)
begin
  if rising_edge(clk) then
	if gdb_we = '1' then
		gdb_ram(to_integer(gdb_wa)) <= gdb_wd;
	end if;
	gdb_q <= gdb_ram(to_integer(gdb_ra));
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
	gdb_we <= '0';
	if restart_tape = '1' then

		tzx_offset <= (others => '0');
		tzx_state <= TZX_HEADER;
		pulse_len <= (others => '0');
		motor_counter <= (others => '0');
		wave_period <= '0';
		playing <= '0';
		tzx_req <= tzx_ack;
		loop_start <= '0';
		loop_next <= '0';
		loop_iter <= (others => '0');
		wave_inverted <= '0';
	else

		-- simulate tape motor momentum
		-- don't change the playing state if the motor is switched in 50 ms
		-- Opera Soft K17 protection needs this!
		cass_motor_D <= cass_motor;
		if cass_motor_D /= cass_motor then
			motor_counter <= to_unsigned(50*TZX_MS, motor_counter'length);
		elsif motor_counter /= 0 then
			if ce = '1' then motor_counter <= motor_counter - 1; end if;
		else
			playing <= cass_motor;
		end if;

		if playing = '0' then
			--cass_read <= '1';
		end if;	

		if pulse_len /= 0 then
			if ce = '1' then
				tick_cnt <= tick_cnt + 3500;
				if tick_cnt >= (TZX_MS - 3500) then
					tick_cnt <= tick_cnt + 3500 - TZX_MS;
					wave_cnt <= wave_cnt + 1;
					if wave_cnt = pulse_len - 1 then
						wave_cnt <= (others => '0');
						if wave_period = end_period then
							pulse_len <= (others => '0');
						else
							wave_period <= not wave_period;
						end if;
					end if;
				end if;
			end if;
		else
			wave_cnt <= (others => '0');
			tick_cnt <= (others => '0');
		end if;

		loop_start <= '0';
		loop_next  <= '0';
		stop       <= '0';
		stop48k    <= '0';

		if playing = '1' and pulse_len = 0 and tzx_req = tzx_ack then

			tzx_req <= not tzx_ack; -- default request for new data

			case tzx_state is
			when TZX_HEADER =>
				wave_period <= '1';
				wave_inverted <= '0';
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"0A" then -- skip 9 bytes, offset lags 1
					tzx_state <= TZX_NEWBLOCK;
				end if;

			when TZX_NEWBLOCK =>
				tzx_offset <= (others=>'0');
				ms_counter <= (others=>'0');
				case tap_fifo_do is
					when x"10" => tzx_state <= TZX_NORMAL;
					when x"11" => tzx_state <= TZX_TURBO;
					when x"12" => tzx_state <= TZX_TONE;
					when x"13" => tzx_state <= TZX_PULSES;
					when x"14" => tzx_state <= TZX_DATA;
					when x"15" => tzx_state <= TZX_DIRECT;
					when x"18" => tzx_state <= TZX_SKIP_LEN32; -- CSW: no se reproduce, pero se salta entero
					when x"19" => tzx_state <= TZX_GDB_HDR;     -- Generalized data block
					when x"20" => tzx_state <= TZX_PAUSE;
					when x"21" => tzx_state <= TZX_TEXT; -- Group start
					when x"22" => null; -- Group end
					when x"23" => data_len_dword <= to_unsigned(2, 32); tzx_state <= TZX_SKIP; -- Jump: se ignora, pero se salta el cuerpo
					when x"24" => tzx_state <= TZX_LOOP_START;
					when x"25" => tzx_state <= TZX_LOOP_END;
					when x"26" => tzx_state <= TZX_SKIP_LEN16X2; -- Call sequence: se ignora, pero se salta el cuerpo
					when x"27" => null; -- Return from sequence (not implemented)
					when x"28" => tzx_state <= TZX_SKIP_LEN16;   -- Select block: se ignora, pero se salta el cuerpo
					when x"2A" => tzx_state <= TZX_STOP48K;
					when x"2B" => tzx_state <= TZX_LEVEL;        -- Set signal level
					when x"30" => tzx_state <= TZX_TEXT;
					when x"31" => tzx_state <= TZX_MESSAGE;
					when x"32" => tzx_state <= TZX_ARCHIVE_INFO;
					when x"33" => tzx_state <= TZX_HWTYPE;
					when x"35" => tzx_state <= TZX_CUSTOM_INFO;
					when x"5A" => tzx_state <= TZX_GLUE;
					when others => null;
				end case;

			when TZX_LOOP_START =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then loop_iter( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then
					loop_iter(15 downto  8) <= tap_fifo_do;
					tzx_state <= TZX_NEWBLOCK;
					loop_start <= '1';
				end if;

			when TZX_LOOP_END =>
				if loop_iter > 1 then
					loop_iter <= loop_iter - 1;
					loop_next <= '1';
				else
					tzx_req <= tzx_ack; -- don't request new byte
				end if;
				tzx_state <= TZX_NEWBLOCK;

			when TZX_PAUSE =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"00" then 
					pause_len(7 downto 0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then
					pause_len(15 downto 8) <= tap_fifo_do;
					tzx_state <= TZX_PAUSE2;
					if pause_len(7 downto 0) = 0 and tap_fifo_do = 0 then
						stop <= '1';
					end if;
				end if;

			when TZX_PAUSE2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				if ms_counter /= 0 then
					if ce = '1' then
						ms_counter <= ms_counter - 1;
						-- Set pulse level to low after 1 ms
						if ms_counter = 1 then
							wave_inverted <= '0';
							wave_period <= '0';
							end_period <= '0';
						end if;
					end if;
				elsif pause_len /= 0 then
					pause_len <= pause_len - 1;
					ms_counter <= to_unsigned(TZX_MS, ms_counter'length);
				else
					tzx_state <= TZX_NEWBLOCK;
				end if;

			when TZX_STOP48K =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"03" then
					stop48k <= '1';
					tzx_state <= TZX_NEWBLOCK;
				end if;

			when TZX_HWTYPE =>
				tzx_offset <= tzx_offset + 1;
				-- 0, 1-3, 1-3, ...
				if    tzx_offset = x"00" then data_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then
					if data_len(7 downto 0) = x"01" then
						tzx_state <= TZX_NEWBLOCK;
					else
						data_len(7 downto 0) <= data_len(7 downto 0) - 1;
						tzx_offset <= x"01";
					end if;
				end if;

			when TZX_MESSAGE =>
				-- skip display time, then then same as TEXT DESRCRIPTION
				tzx_state <= TZX_TEXT;

			when TZX_TEXT =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then data_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = data_len(7 downto 0) then
						tzx_state <= TZX_NEWBLOCK;
				end if;

			when TZX_ARCHIVE_INFO =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then data_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then data_len(15 downto  8) <= tap_fifo_do;
				else
					tzx_offset <= x"02";
					data_len <= data_len - 1;
					if data_len = 1 then
						tzx_state <= TZX_NEWBLOCK;
					end if;
				end if;

			when TZX_CUSTOM_INFO =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"10" then data_len_dword( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"11" then data_len_dword(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"12" then data_len_dword(23 downto 16) <= tap_fifo_do;
				elsif tzx_offset = x"13" then data_len_dword(31 downto 24) <= tap_fifo_do;
				elsif tzx_offset = x"14" then
					tzx_offset <= x"14";
					if data_len_dword = 1 then
						tzx_state <= TZX_NEWBLOCK;
					else
						data_len_dword <= data_len_dword - 1;
					end if;
				end if;

			when TZX_GLUE =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"08" then
					tzx_state <= TZX_NEWBLOCK;
				end if;

			when TZX_TONE =>
				tzx_offset <= tzx_offset + 1;
				-- 0, 1, 2, 3, 4, 4, 4, ...
				if    tzx_offset = x"00" then pilot_l( 7 downto 0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then pilot_l(15 downto 8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then pilot_pulses( 7 downto 0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then
					tzx_req <= tzx_ack; -- don't request new byte
					pilot_pulses(15 downto 8) <= tap_fifo_do;
				else
					tzx_offset <= x"04";
					tzx_req <= tzx_ack; -- don't request new byte
					if pilot_pulses = 0 then
						tzx_req <= not tzx_ack; -- default request for new data
						tzx_state <= TZX_NEWBLOCK;
					else
						pilot_pulses <= pilot_pulses - 1;
						if wave_inverted = '0' then
							wave_period <= not wave_period;
							end_period <= not wave_period; -- request pulse
						else
							wave_inverted <= '0';
							end_period <= wave_period;
						end if;
						pulse_len <= pilot_l;
					end if;
				end if;

			when TZX_PULSES =>
				tzx_offset <= tzx_offset + 1;
				-- 0, 1-2+3, 1-2+3, ...
				if    tzx_offset = x"00" then data_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then one_l( 7 downto 0) <= tap_fifo_do;
				elsif tzx_offset = x"02" then
					tzx_req <= tzx_ack; -- don't request new byte
						if wave_inverted = '0' then
							wave_period <= not wave_period;
							end_period <= not wave_period; -- request pulse
						else
							wave_inverted <= '0';
							end_period <= wave_period;
						end if;
					pulse_len <= tap_fifo_do & one_l( 7 downto 0);
				elsif tzx_offset = x"03" then
					if data_len(7 downto 0) = x"01" then
						tzx_state <= TZX_NEWBLOCK;
					else
						data_len(7 downto 0) <= data_len(7 downto 0) - 1;
						tzx_offset <= x"01";
					end if;
				end if;

			when TZX_DATA =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then zero_l ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then zero_l (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then one_l  ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then one_l  (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"04" then last_byte_bits <= tap_fifo_do(3 downto 0);
				elsif tzx_offset = x"05" then pause_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"06" then pause_len(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"07" then data_len ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"08" then data_len (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"09" then
					data_len (23 downto 16) <= tap_fifo_do;
					tzx_state <= TZX_PLAY_TAPBLOCK;
				end if;

			when TZX_NORMAL =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then pause_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then pause_len(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then data_len ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then
					data_len(15 downto  8) <= tap_fifo_do;
					data_len(23 downto 16) <= (others => '0');
				elsif tzx_offset = x"04" then
					-- this is the first data byte to determine if it's a header or data block (on Speccy)
					tzx_req <= tzx_ack; -- don't request new byte
					pilot_l <= to_unsigned(NORMAL_PILOT_LEN, pilot_l'length);
					sync1_l <= to_unsigned(NORMAL_SYNC1_LEN, sync1_l'length);
					sync2_l <= to_unsigned(NORMAL_SYNC2_LEN, sync2_l'length);
					zero_l  <= to_unsigned(NORMAL_ZERO_LEN,  zero_l'length);
					one_l   <= to_unsigned(NORMAL_ONE_LEN,   one_l'length);
					if tap_fifo_do = 0 then
						pilot_pulses <= to_unsigned(HEADER_PILOT_PULSES, pilot_pulses'length);
					else
						pilot_pulses <= to_unsigned(NORMAL_PILOT_PULSES, pilot_pulses'length);
					end if;
					last_byte_bits <= "1000";
					tzx_state <= TZX_PLAY_TONE;
				end if;

			when TZX_TURBO =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then pilot_l( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then pilot_l(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then sync1_l( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then sync1_l(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"04" then sync2_l( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"05" then sync2_l(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"06" then zero_l ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"07" then zero_l (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"08" then one_l  ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"09" then one_l  (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"0A" then pilot_pulses( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"0B" then pilot_pulses(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"0C" then last_byte_bits <= tap_fifo_do(3 downto 0);
				elsif tzx_offset = x"0D" then pause_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"0E" then pause_len(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"0F" then data_len ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"10" then data_len (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"11" then
					data_len (23 downto 16) <= tap_fifo_do;
					tzx_state <= TZX_PLAY_TONE;
				end if;

			when TZX_PLAY_TONE =>
				tzx_req <= tzx_ack; -- don't request new byte
				if wave_inverted = '0' then
					wave_period <= not wave_period;
					end_period <= not wave_period; -- request pulse
				else
					end_period <= wave_period;
					wave_inverted <= '0';
				end if;
				pulse_len <= pilot_l;
				if pilot_pulses = 1 then
					tzx_state <= TZX_PLAY_SYNC1;
				else
					pilot_pulses <= pilot_pulses - 1;
				end if;

			when TZX_PLAY_SYNC1 =>
				tzx_req <= tzx_ack; -- don't request new byte
				wave_period <= not wave_period;
				end_period <= not wave_period; -- request pulse
				pulse_len <= sync1_l;
				tzx_state <= TZX_PLAY_SYNC2;

			when TZX_PLAY_SYNC2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				wave_period <= not wave_period;
				end_period <= not wave_period; -- request pulse
				pulse_len <= sync2_l;
				tzx_state <= TZX_PLAY_TAPBLOCK;

			when TZX_PLAY_TAPBLOCK =>
				tzx_req <= tzx_ack; -- don't request new byte
				bit_cnt <= "111";
				tzx_state <= TZX_PLAY_TAPBLOCK2;

			when TZX_PLAY_TAPBLOCK2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				bit_cnt <= bit_cnt - 1;
				if bit_cnt = "000" or (data_len = 1 and ((bit_cnt = (8 - last_byte_bits)) or (last_byte_bits = 0))) then
					data_len <= data_len - 1;
					tzx_state <= TZX_PLAY_TAPBLOCK3;
				end if;
				if wave_inverted = '0' then
					wave_period <= not wave_period;
					end_period <= wave_period; -- request full period
				else
					end_period <= not wave_period;
					wave_inverted <= '0';
				end if;
				if tap_fifo_do(to_integer(bit_cnt)) = '0' then
					pulse_len <= zero_l;
				else
					pulse_len <= one_l;
				end if;

			when TZX_PLAY_TAPBLOCK3 =>
				if data_len = 0 then
					wave_period <= not wave_period;
					wave_inverted <= '1';
					tzx_state <= TZX_PAUSE2;
				else
					tzx_state <= TZX_PLAY_TAPBLOCK4;
				end if;

			when TZX_PLAY_TAPBLOCK4 =>
				tzx_req <= tzx_ack; -- don't request new byte
				tzx_state <= TZX_PLAY_TAPBLOCK2;

			when TZX_DIRECT =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then zero_l    ( 7 downto  0) <= tap_fifo_do; -- here this is used for one bit, too
				elsif tzx_offset = x"01" then zero_l    (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then pause_len ( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"03" then pause_len (15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"04" then last_byte_bits <= tap_fifo_do(3 downto 0);
				elsif tzx_offset = x"05" then data_len( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"06" then data_len(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"07" then 
					data_len(23 downto 16) <= tap_fifo_do;
					tzx_state <= TZX_DIRECT2;
					bit_cnt <= "111";
				end if;

			when TZX_DIRECT2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				bit_cnt <= bit_cnt - 1;
				if bit_cnt = "000" or (data_len = 1 and ((bit_cnt = (8 - last_byte_bits)) or (last_byte_bits = 0))) then
					data_len <= data_len - 1;
					tzx_state <= TZX_DIRECT3;
				end if;

				pulse_len <= zero_l;
				wave_period <= tap_fifo_do(to_integer(bit_cnt));
				end_period <= tap_fifo_do(to_integer(bit_cnt));

			when TZX_DIRECT3 =>
				if data_len = 0 then
					wave_inverted <= '0';
					tzx_state <= TZX_PAUSE2;
				else
					tzx_state <= TZX_DIRECT2;
				end if;


			-- bloques con longitud de 32 bits que no se reproducen: se saltan enteros
			when TZX_SKIP_LEN32 =>
				tzx_offset <= tzx_offset + 1;
				if    tzx_offset = x"00" then data_len_dword( 7 downto  0) <= tap_fifo_do;
				elsif tzx_offset = x"01" then data_len_dword(15 downto  8) <= tap_fifo_do;
				elsif tzx_offset = x"02" then data_len_dword(23 downto 16) <= tap_fifo_do;
				else
					data_len_dword(31 downto 24) <= tap_fifo_do;
					if data_len_dword(23 downto 0) = 0 and tap_fifo_do = 0 then
						tzx_state <= TZX_NEWBLOCK;
					else
						tzx_state <= TZX_SKIP;
					end if;
				end if;

			-- bloques con longitud de 16 bits (0x28)
			when TZX_SKIP_LEN16 =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"00" then data_len_dword <= x"000000" & tap_fifo_do;
				else
					data_len_dword(15 downto 8) <= tap_fifo_do;
					if data_len_dword(7 downto 0) = 0 and tap_fifo_do = 0 then
						tzx_state <= TZX_NEWBLOCK;
					else
						tzx_state <= TZX_SKIP;
					end if;
				end if;

			-- 0x26: número de llamadas (16 bits) y dos bytes por llamada
			when TZX_SKIP_LEN16X2 =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"00" then data_len_dword <= x"000000" & tap_fifo_do;
				else
					data_len_dword <= "000000000000000" & tap_fifo_do & data_len_dword(7 downto 0) & '0';
					if data_len_dword(7 downto 0) = 0 and tap_fifo_do = 0 then
						tzx_state <= TZX_NEWBLOCK;
					else
						tzx_state <= TZX_SKIP;
					end if;
				end if;

			when TZX_SKIP =>
				if data_len_dword = 1 then
					tzx_state <= TZX_NEWBLOCK;
				end if;
				data_len_dword <= data_len_dword - 1;

			-- 0x2B: longitud (32 bits, siempre 1) y nivel
			when TZX_LEVEL =>
				tzx_offset <= tzx_offset + 1;
				if tzx_offset = x"04" then
					wave_period <= tap_fifo_do(0);
					end_period <= tap_fifo_do(0);
					wave_inverted <= '0';
					tzx_state <= TZX_NEWBLOCK;
				end if;

			------------------------------------------------------------------------------
			-- 0x19: Generalized Data Block
			-- Las tablas de símbolos de piloto y de datos se copian a gdb_ram (512 bytes
			-- cada una); si no caben, el bloque se salta entero.
			------------------------------------------------------------------------------
			when TZX_GDB_HDR =>
				tzx_offset <= tzx_offset + 1;
				case to_integer(tzx_offset) is
					when  0 => gdb_len( 7 downto  0) <= tap_fifo_do;
					when  1 => gdb_len(15 downto  8) <= tap_fifo_do;
					when  2 => gdb_len(23 downto 16) <= tap_fifo_do;
					when  3 => gdb_len(31 downto 24) <= tap_fifo_do;
					when  4 => pause_len( 7 downto 0) <= tap_fifo_do;
					when  5 => pause_len(15 downto 8) <= tap_fifo_do;
					when  6 => gdb_totp( 7 downto  0) <= tap_fifo_do;
					when  7 => gdb_totp(15 downto  8) <= tap_fifo_do;
					when  8 => gdb_totp(23 downto 16) <= tap_fifo_do;
					when  9 => gdb_totp(31 downto 24) <= tap_fifo_do;
					when 10 => gdb_npp <= tap_fifo_do;
					when 11 => if tap_fifo_do = 0 then gdb_asp <= to_unsigned(256, 9); else gdb_asp <= '0' & tap_fifo_do; end if;
					when 12 => gdb_totd( 7 downto  0) <= tap_fifo_do;
					when 13 => gdb_totd(15 downto  8) <= tap_fifo_do;
					when 14 => gdb_totd(23 downto 16) <= tap_fifo_do;
					when 15 => gdb_totd(31 downto 24) <= tap_fifo_do;
					when 16 => gdb_npd <= tap_fifo_do;
					when others =>
						if tap_fifo_do = 0 then gdb_asd <= to_unsigned(256, 9); else gdb_asd <= '0' & tap_fifo_do; end if;
						tzx_state <= TZX_GDB_CFG;
				end case;

			when TZX_GDB_CFG =>
				tzx_req <= tzx_ack; -- don't request new byte
				-- bits por símbolo de datos: ceil(log2(asd))
				if    gdb_asd <= 2   then gdb_nb <= x"1";
				elsif gdb_asd <= 4   then gdb_nb <= x"2";
				elsif gdb_asd <= 8   then gdb_nb <= x"3";
				elsif gdb_asd <= 16  then gdb_nb <= x"4";
				elsif gdb_asd <= 32  then gdb_nb <= x"5";
				elsif gdb_asd <= 64  then gdb_nb <= x"6";
				elsif gdb_asd <= 128 then gdb_nb <= x"7";
				else                      gdb_nb <= x"8";
				end if;
				if (gdb_totp /= 0 and gdb_asp * (gdb_npp & '1') > 512) or
				   (gdb_totd /= 0 and gdb_asd * (gdb_npd & '1') > 512) then
					-- tablas demasiado grandes: se salta el resto del bloque
					data_len_dword <= gdb_len - 14;
					if gdb_len <= 14 then
						tzx_state <= TZX_NEWBLOCK;
					else
						tzx_state <= TZX_SKIP;
					end if;
				elsif gdb_totp /= 0 then
					gdb_wa <= (others => '1');           -- base - 1 (0 - 1)
					gdb_cnt <= resize(gdb_asp * (gdb_npp & '1'), 32);
					tzx_state <= TZX_GDB_PTAB;
				elsif gdb_totd /= 0 then
					gdb_wa <= to_unsigned(511, 10);       -- base - 1 (512 - 1)
					gdb_cnt <= resize(gdb_asd * (gdb_npd & '1'), 32);
					tzx_state <= TZX_GDB_DTAB;
				else
					tzx_state <= TZX_PAUSE2;
				end if;

			-- tabla de símbolos del piloto
			when TZX_GDB_PTAB =>
				gdb_we <= '1';
				gdb_wd <= tap_fifo_do;
				gdb_wa <= gdb_wa + 1;
				gdb_cnt <= gdb_cnt - 1;
				if gdb_cnt = 1 then
					gdb_cnt <= gdb_totp;
					tzx_state <= TZX_GDB_PRLE0;
				end if;

			-- piloto: tripletes símbolo + repeticiones
			when TZX_GDB_PRLE0 =>
				gdb_sym <= tap_fifo_do;
				tzx_state <= TZX_GDB_PRLE1;
			when TZX_GDB_PRLE1 =>
				gdb_rep(7 downto 0) <= tap_fifo_do;
				tzx_state <= TZX_GDB_PRLE2;
			when TZX_GDB_PRLE2 =>
				gdb_rep(15 downto 8) <= tap_fifo_do;
				gdb_data <= '0';
				gdb_base <= (others => '0');
				gdb_np <= gdb_npp;
				gdb_stride <= gdb_npp & '1';
				if gdb_rep(7 downto 0) = 0 and tap_fifo_do = 0 then
					tzx_state <= TZX_GDB_SYMDONE;  -- 0 repeticiones
				else
					tzx_state <= TZX_GDB_SYM0;
				end if;

			-- tabla de símbolos de datos
			when TZX_GDB_DTAB =>
				gdb_we <= '1';
				gdb_wd <= tap_fifo_do;
				gdb_wa <= gdb_wa + 1;
				gdb_cnt <= gdb_cnt - 1;
				if gdb_cnt = 1 then
					gdb_cnt <= gdb_totd;
					gdb_bits <= (others => '0');
					gdb_got <= (others => '0');
					gdb_data <= '1';
					gdb_base <= to_unsigned(512, 10);
					gdb_np <= gdb_npd;
					gdb_stride <= gdb_npd & '1';
					gdb_rep <= x"0001";
					tzx_state <= TZX_GDB_DGET;
				end if;

			-- datos: nb bits por símbolo, del bit más alto al más bajo
			when TZX_GDB_DGET =>
				if gdb_bits = 0 then
					gdb_byte <= tap_fifo_do;      -- consume un byte
					gdb_bits <= x"8";
				else
					tzx_req <= tzx_ack; -- don't request new byte
					gdb_sym <= gdb_sym(6 downto 0) & gdb_byte(7);
					gdb_byte <= gdb_byte(6 downto 0) & '0';
					gdb_bits <= gdb_bits - 1;
					if gdb_got + 1 = gdb_nb then
						gdb_got <= (others => '0');
						gdb_rep <= x"0001";
						tzx_state <= TZX_GDB_SYM0;
					else
						gdb_got <= gdb_got + 1;
					end if;
				end if;
				if gdb_got = 0 and gdb_bits /= 0 then
					gdb_sym <= "0000000" & gdb_byte(7);
				end if;

			-- reproducción de un símbolo: indicador + hasta np pulsos de 16 bits
			when TZX_GDB_SYM0 =>
				tzx_req <= tzx_ack; -- don't request new byte
				gdb_ra <= gdb_base + resize(gdb_sym * gdb_stride, 10);
				tzx_state <= TZX_GDB_SYM1;
			when TZX_GDB_SYM1 =>
				tzx_req <= tzx_ack; -- don't request new byte
				tzx_state <= TZX_GDB_SYM2;
			when TZX_GDB_SYM2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				gdb_flag <= gdb_q(1 downto 0);
				gdb_pp <= gdb_ra + 1;
				gdb_pidx <= (others => '0');
				tzx_state <= TZX_GDB_P0;
			when TZX_GDB_P0 =>
				tzx_req <= tzx_ack; -- don't request new byte
				if gdb_pidx = gdb_np then
					tzx_state <= TZX_GDB_SYMDONE;
				else
					gdb_ra <= gdb_pp;
					tzx_state <= TZX_GDB_P1;
				end if;
			when TZX_GDB_P1 =>
				tzx_req <= tzx_ack; -- don't request new byte
				gdb_ra <= gdb_pp + 1;
				tzx_state <= TZX_GDB_P2;
			when TZX_GDB_P2 =>
				tzx_req <= tzx_ack; -- don't request new byte
				gdb_lo <= gdb_q;
				tzx_state <= TZX_GDB_P3;
			when TZX_GDB_P3 =>
				tzx_req <= tzx_ack; -- don't request new byte
				if gdb_q = 0 and gdb_lo = 0 then
					tzx_state <= TZX_GDB_SYMDONE;      -- pulso de longitud 0: fin del símbolo
				else
					if gdb_pidx = 0 then
						case gdb_flag is
						when "00" =>                     -- flanco
							if wave_inverted = '0' then
								wave_period <= not wave_period;
								end_period <= not wave_period;
							else
								end_period <= wave_period;
							end if;
						when "01" =>                     -- mismo nivel
							end_period <= wave_period;
						when "10" =>                     -- nivel bajo
							wave_period <= '0';
							end_period <= '0';
						when others =>                   -- nivel alto
							wave_period <= '1';
							end_period <= '1';
						end case;
						wave_inverted <= '0';
					else
						wave_period <= not wave_period;
						end_period <= not wave_period;
					end if;
					pulse_len <= gdb_q & gdb_lo;
					gdb_pidx <= gdb_pidx + 1;
					gdb_pp <= gdb_pp + 2;
					tzx_state <= TZX_GDB_P0;
				end if;

			when TZX_GDB_SYMDONE =>
				tzx_req <= tzx_ack; -- don't request new byte
				if gdb_rep > 1 then
					gdb_rep <= gdb_rep - 1;
					tzx_state <= TZX_GDB_SYM0;
				elsif gdb_data = '0' then
					-- siguiente entrada del piloto, o tabla de datos
					if gdb_cnt > 1 then
						gdb_cnt <= gdb_cnt - 1;
						tzx_state <= TZX_GDB_PRLE0;
					elsif gdb_totd /= 0 then
						gdb_wa <= to_unsigned(511, 10);       -- base - 1 (512 - 1)
						gdb_cnt <= resize(gdb_asd * (gdb_npd & '1'), 32);
						tzx_state <= TZX_GDB_DTAB;
					else
						-- flanco final para cerrar el último pulso (como TZX_PLAY_TAPBLOCK3)
						wave_period <= not wave_period;
						wave_inverted <= '1';
						tzx_state <= TZX_PAUSE2;
					end if;
				else
					if gdb_cnt > 1 then
						gdb_cnt <= gdb_cnt - 1;
						tzx_state <= TZX_GDB_DGET;
					else
						-- flanco final para cerrar el último pulso (como TZX_PLAY_TAPBLOCK3)
						wave_period <= not wave_period;
						wave_inverted <= '1';
						tzx_state <= TZX_PAUSE2;
					end if;
				end if;

			when others => null;
			end case;

		end if; -- play tzx

	end if;
  end if; -- clk
end process;

end struct;
