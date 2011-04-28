#!/usr/bin/ruby1.9.1
# encoding: utf-8

require "unicode_utils/titlecase"

FIELDS = [:obl, :rayon, :sovet, :type, :name_bel, :rod, :skl, :name_lat, :name_rus]
CELLS = [:type, :name_bel, :rod, :skl, :name_lat, :name_rus]

class Parser
	def initialize(obl, output)
		@output = output
		@state = :idle
		@fields = Hash.new
		FIELDS.each {|f| @fields[f] = ''}
		@fields[:obl] = obl
		@stats = Hash.new
		@our_stats = Hash.new
		reset_stats
	end

	def parse(io)
		io.each_line { |line|
			line.chomp!
			line.gsub(/[^=]\s+$/, '\1')
			parse_line(line)
		}
		check_stats
	end

	STATS_MAP = {
		'гарадоў раённага падпарадкавання' 	=> :rayon_towns,
		'гарадскіх пасёлкаў'								=> :towns,
		'сельсаветаў'												=> :sovets,
		'сельскіх населеных пунктаў'				=> :hamlets,
		'усяго населеных пунктаў'						=> :total
	}

	STATS_FIELDS = [:rayon_towns, :towns, :sovets, :hamlets, :total]

	def reset_stats
		STATS_FIELDS.each {|f| @stats[f] = 0; @our_stats[f] = 0}
    @prev = 0
	end

	def check_stats

		return if @stats[:total] == 0

		STDERR.puts "Статыстыка раёну:"
		STDERR.puts "Павінна быць: #{@stats.inspect}"
		STDERR.puts "Знойдзена:    #{@our_stats.inspect}"
		if @stats[:sovets] != @our_stats[:sovets]
			STDERR.puts "УВАГА: Знойдзена толькі #{@our_stats[:sovets]} сельсаветаў з #{@stats[:sovets]}"
		end
		if @stats[:total] != @our_stats[:total]
			STDERR.puts "УВАГА: Знойдзена толькі #{@our_stats[:total]} населеных пунктаў з #{@stats[:total]}"
		end
	end
	
	def parse_line(string)
		if @state == :idle
			if string =~ /@(Copy ([0-9] )?of )?Загал1-?1? = (.*)\s(РАЁН)\s*$/i
				@fields[:rayon] = UnicodeUtils.titlecase($3)
				STDERR.puts "Знойдзены раён '#{@fields[:rayon]}'"
				check_stats
				reset_stats
				return
			end

			if string =~ /@(Copy ([0-9] )?of )?Загал[135]-?1? = (.+[^\s]) +СЕЛЬСАВЕТ\s*$/i
				@fields[:sovet] = UnicodeUtils.titlecase($3)
#        STDERR.puts "Нас. пунктаў: #{@our_stats[:total] - @prev}"
        @prev = @our_stats[:total]
				STDERR.puts "Знойдзены сельсавет '#{@fields[:sovet]}'"
				@our_stats[:sovets] += 1
				@state = :wait_for_table
				return
			end

			if string =~ /@(Copy (.+ )?of )?Загал3 = .*Назвы пасёлкаў гарадскога тыпу і парадыгмы іх скланення.*/ or string =~ /@(Copy (.+ )?of )?Загал3 = .*Назвы гарадоў( абласнога і)? раённага падпарадкавання.*$/
				if $3.nil?
					@fields[:sovet] = '<раён>'
				else
					@fields[:sovet] = '<раён/вобласць>'
				end
				@state = :wait_for_table
				STDERR.puts "Гарады раённага/абласнога падпарадкавання і пасёлкі г.т."
				return
			end

			if string =~ /@Загал[23] = (Населеныя пункты, адміністрацыйна падпарадкаваныя) (.+)$/
				@fields[:sovet] = $2
				STDERR.puts "#{$1} #{$2}"
				return
			end

			if string =~ /@Загал3 = Назвы населеных пунктаў і парадыгмы іх склане.+я$/
				@state = :wait_for_table
				return
			end

			if string =~ /@Body Text1 =\s+(.+[^\s])\s+([0-9]+)/
				@stats[STATS_MAP[$1]] = $2.to_i
				return
			end
		end

		if @state == :wait_for_table and string =~ /@Z_TBL_BEG = (.*)$/
			@state = :wait_for_row
			return
		end

		if @state == :wait_for_row
			if string =~ /@Z_TBL_ROW_BEG = (.*)$/
				@state = :wait_for_cell
				@cell_num = 0
				return
			end

			if string =~ /@Z_TBL_END = (.*)$/
				@state = :idle
				(FIELDS - [:obl, :rayon]).each {|f| @fields[f] = ''}
				return
			end
		end

		if @state == :wait_for_cell
			if string =~ /@Z_TBL_CELL_BEG = (.*)/
				@state = :wait_for_cell_data
				return
			end

			if string =~ /@Z_TBL_ROW_END = (.*)$/
				write_fields
				@our_stats[:total] += 1
				CELLS.each {|f| @fields[f] = ''}
				@state = :wait_for_row
				return
			end
		end

		if @state == :wait_for_cell_data
			if string =~ /@Table Text = (.*)$/
				@state = :wait_for_row
				return
			end

			if string =~ /@(Copy (.+ )?of )?Table Body Text1? = (.*)$/
        STDERR.puts "WARNING: duplicate value: #{$3}" unless @fields[CELLS[@cell_num]].empty?
				@fields[CELLS[@cell_num]] = $3.gsub(/ +$/, '')
				return
			end

			if string =~ /@Z_TBL_CELL_END = (.*)$/
				@state = :wait_for_cell
				@cell_num += 1
			end
		end
	end

	def write_fields
		@output.puts( FIELDS.map {|f| "\"#{@fields[f]}\""}.join(','))
	end
end

p = Parser.new("Віцебская", STDOUT)
p.parse(STDIN)
