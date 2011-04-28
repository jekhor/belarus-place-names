#!/usr/bin/ruby

$KCODE = 'UTF8'

SIMPLE_SUBST = [
	[/%-?[0-9]/,						''],
	[/<>/,									''],
#	[/-<R>([АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯІ])/,			'-\1'],
	[/-<R>([А-ЯІЁA-Z])/,		'-\1'],
	[/-<R>/,								''],
	[/<R>/,									' '],
	[/ +/,									' '],
	[/<->/,									''],
	[/<[BM]>/,									''],
	[/<I\*?>/,							''],
	[/<[PW][0-9]+[^>]*>/,				''],
	[/<C5(,[0-9]+)+>/,			''],
	[/<C255>/,							''],
	[/- /,									''],
	[/<\$T[^>]*>/,					''],
	[/<\$I[^>]*>/,					''],
	[/<\$[\[\]][^>]*>/,					''],
	[/@Z_STYLE70 = .*/,			''],
#	[/@СуперЗагал1 = (.*)$/,	'<h1>\1</h1>'],
#	[/@Загал1 = (.*)$/,				'<h2>\1</h2>'],
#	[/@Загал1-1 = (.*)$/,			'<h2>\1</h2>'],
#	[/@Загал2 = (.*)$/,				'<h3>\1</h3>'],
#	[/@Загал3 = (.*)$/,				'<h4>\1</h4>'],
#	[/@Загал4 = (.*)$/,				'<h5>\1</h5>'],
#	[/@Загал5 = (.*)$/,				'<h6>\1</h6>'],
#	[/@Body Text1 = (.*)$/,		'<p>\1</p>'],
#	[/@Body Text2 = (.*)$/,		'<p>\1</p>'],
#	[/@Z_TBL_BEG = (.*)$/,	'<table>'],
#	[/@Z_TBL_ROW_BEG = (.*)$/,		'<tr>'],
#	[/@Z_TBL_CELL_BEG = (.*)$/,		'<td>'],
#	[/@Z_TBL_CELL_END = (.*)$/,		'</td>'],
#	[/@Z_TBL_ROW_END = (.*)$/,		'</tr>'],
#	[/@Z_TBL_END = (.*)$/,				'</table>'],
#	[/@Table Text = (.*)$/,				'<b>\1</b>'],
#	[/@Table Body Text1 = (.*)$/, '\1'],
#	[/@Table Body Text = (.*)$/,	'\1'],
	[/<\^>[^<]*<\^\*>/,						''],
	[/<\^>[^<]*$/,								''],
	[/[0-9]+<\^\*>/,								''],
	[/<\|>/,											''],
]


class Parser
	def initialize
		create_regexps
	end

	def create_regexps
		@substs = Array.new

		SIMPLE_SUBST.each {|pair|
			pr = Proc.new {|string| string.gsub(pair[0], pair[1])}
			@substs << pr
		}
	end

	def parse_line(string, index)
		str = unicodize(string, index)
		@substs.each { |pr|
			str = pr.call(str)
		}
		str
	end

	def parse_io(input, output)
    line_index = 1
		input.each_line { |line|
			line.chomp!
			output.puts parse_line(line, line_index)
      line_index += 1
		}
	end

	def unicodize(string, index)
		res_string = ''
		font_name = '255'
		state = :text
		tag = :none
		tag_text = ''
		string.each_char {|char|
			if (state == :text or state == :footnote_text) and char == '<'
				state = :begin_tag
				tag_text = char
				next
			end

			if state == :begin_tag and char != '>'
				case char
				when 'F'
					tag = :font_tag
					font_name = ''
					state = :in_tag
				when '^'
					tag = :footnote
				when '*'
					tag = :footnote_end if tag == :footnote
					state = :in_tag
				else
					state = :in_tag
				end


				tag_text += char
				next
			end

			if (state == :in_tag or state == :begin_tag) and char == '>'
				tag_text += char
				if tag_text.include? "F255"
					font_name = '255'
				end

				if tag == :font_tag and font_name != '255'
#					STDERR.puts "Font name is '#{font_name}'"
					if font_name =~ /"(.+)".*/
						font_name = $1
					end
				end

				res_string += tag_text if tag == :none
				res_string += '<^>' if tag == :footnote
				res_string += '<^*>' if tag_text.include? '^*'

				if tag == :footnote
					state = :footnote_text
				else
					state = :text
				end
				tag = :none
				tag_text = ''

#				if font_name[0, 1] == font_name[-1, 1] and font_name[0, 1] == '"'
#					font_name = font_name[1..-2]
#				end

				next
			end

			if state == :in_tag
				tag_text += char
				if tag == :font_tag
					font_name += char
				end

				next
			end

			if state == :footnote_text
#				res_string += "Footnote text in string '#{string}'\n"
				res_string += char
				next
			end

			if state == :text
				begin
					res_string += font2unicode(char, font_name)
				rescue => e
					STDERR.puts "#{index}: String is '#{string}'"
					raise e
				end
			end
		}
		res_string
	end

	private
	FONT_MAP = {
		'Times New Roman +' => {
			'ј' => 'е́',
			'Ј' => 'Е́',
			'ђ' => 'а́',
			'Ђ' => 'А́',
			'ѕ' => 'і́',
			'Ѕ' => 'І́',
			'ќ' => 'ы́',
			'ѓ' => 'о́',
			'њ' => 'э́',
			'љ' => 'у́',
			'Љ' => 'У́',
			'ћ' => 'я́',
			'џ' => 'ю́',
			'Џ' => 'Ю́',
			'Ѓ' => 'О́',
			'Њ' => 'Э́',
			'Ћ' => 'Я́',
			'‡' => 'и́',
			'†' => 'И́',
			'»' => 'ŭ',
		},
		'Times Bel Latinica' => {
			'О' => 'І́',
      'с' => 'ĺ',
      '±' => 'ž',
			'°' => 'Ž',
      'Ї' => 'ź',
			'\\' => 'š',
			'/' => 'Š',
			'е' => 'č',
			'Е' => 'Č',
			'љ' => 'ŭ',
			'[' => 'ć',
			'я' => 'ś',
		},
		'Times New Roman CE' => {
			'њ' => 'ś',
			'љ' => 'š',
			'Љ' => 'Š',
			'и' => 'č',
			'И' => 'Č',
			'ж' => 'ć',
			'е' => 'ĺ',
			'Е' => 'Ĺ',
			'с' => 'ń',
			'ћ' => 'ž',
			'Ћ' => 'Ž',
			'џ' => 'ź',
			
		},
	}

	FONT_EQUAL_RANGES = {
		'Times New Roman' => [
			'A'..'Z',
			'a'..'z',
			'а'..'я',
			'А'..'Я',
			'0'..'9',
			'іІёЁўЎ -,.’/()',
		],

		'Times New Roman +' => [
      '2',
			'A'..'Z',
			'a'..'z',
			'а'..'я',
			'А'..'Я',
			'іІёЁўЎ -,.’()',
		],
		'Times Bel Latinica' => [
			'A'..'Z',
			'a'..'z',
			'- ',
		],
		'Times New Roman Cyr' => [
			'А'..'Я',
			'а'..'я',
			'0'..'9',
			' ,.;:-',
			'уУўЎёЁ—',
		],

		'Arial' => [
			'А'..'Я',
			'а'..'я',
			'0'..'9',
			' ,.;:-',
			'уУўЎёЁ—',
		],
		
		'Arial Cyr' => [
			'А'..'Я',
			'а'..'я',
			'0'..'9',
			' ,.;:-',
			'уУўЎёЁ—',
		],

			'Times New Roman CE' => [
			'a'..'z',
			'A'..'Z',
			'0'..'9',
			'-,.: ',
			'Гервяты',
			'Ожелеи',
		],
	}

	def font2unicode(char, font)

		return char if font == '255'
		return char if font == 'Times New Roman Cyr'

		if FONT_MAP[font].nil?
			if FONT_EQUAL_RANGES[font].nil?
				raise "Char '#{char}' in font '#{font}' is not mapped"
			else
				FONT_EQUAL_RANGES[font].each {|range|
					return char if range.include? char
				}
				raise "Char '#{char}' in font '#{font}' is not mapped"
			end
		end

		c = FONT_MAP[font][char]
		if c.nil?
			FONT_EQUAL_RANGES[font].each {|range|
					return char if range.include? char
			}
			raise "Char '#{char}' in font '#{font}' is not mapped"
		end
		c
	end
end

parser = Parser.new
parser.parse_io(STDIN, STDOUT)
