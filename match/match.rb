#!/usr/bin/ruby
# encoding: utf-8

$KCODE = 'UTF8'

require 'sqlite3'

class Matcher
	def initialize(db_file)
		@db = SQLite3::Database.new(db_file)

	end

	LONG_ABR = {
		'Стар.' => %w(Старый Старая Старое Старые),
		'Нов.' => %w(Новый Новая Новое Новые),
		'Бол.' => %w(Большой Большая Большое Большие),
		'Мал.' => %w(Малый Малая Малое Малые),
		'Вел.' => %w(Великий Великая Великое Великие),
	}
	EQUAL_NAMES = {
		'Большой' => 'Великий',
		'Большая' => 'Великая',
		'Большое' => 'Великое',
		'Большие' => 'Великие',
	}
	def fix_osm_abbrevs!
		rows = @db.execute("SELECT id, name FROM osm_places WHERE name LIKE '%.%' ORDER BY name")
		rows.each {|row|
			id, name = row

			abr = nil
			LONG_ABR.each_key {|k|
				abr = k if name.include?(k)
			}
			next if abr.nil?

			full_names = LONG_ABR[abr]
			begin
				puts "\nNode #{id}, name '#{name}', replace '#{abr}' with:"
				puts full_names.map {|n| "#{full_names.index(n) + 1}. #{n}"}.join("\n")
				choice = STDIN.gets.to_i
			end until (1..full_names.size).include?(choice)

			new_name = name.sub(/#{abr.gsub('.', '\.')}\s*/, full_names[choice - 1] + " ")
			puts "Name will be '#{new_name}'"
			@db.execute("UPDATE osm_places SET name='#{new_name}' WHERE id=#{id}")
		}
	end

	def do_manual_matching!
		rows = @db.execute("SELECT id, name, rayon, lon, lat FROM osm_places WHERE (SELECT count(*) FROM places WHERE osm_places.id=id)=0 ORDER BY rayon")
		rows.each {|row|
			osm_id, osm_name, osm_rayon, lon, lat = row

			add_expressions = ''
			EQUAL_NAMES.each_pair {|k, v|
				t = osm_name.gsub(k, v)
				if t != osm_name
					add_expressions += " OR rus_name LIKE '%#{t}%' "
				end
			}

			add_expressions += " OR substr(rus_name,1,1)='#{osm_name.chars.first}' "
			candidate_rows = @db.execute("SELECT ROWID, rus_name, bel_name, sels, type FROM places WHERE id ISNULL AND rayon='#{osm_rayon}' AND (rus_name LIKE '%#{osm_name}%' OR rus_name LIKE '%#{osm_name.gsub('е', 'ё')}%' #{add_expressions}) ORDER BY rus_name")
#			candidate_rows = @db.execute("SELECT ROWID, rus_name, bel_name, sels, type FROM places WHERE id ISNULL AND rayon='#{osm_rayon}' ORDER BY rus_name")
			next if candidate_rows.empty?

			candidates = candidate_rows.map {|row| {:rowid => row[0], :rus_name => row[1], :bel_name => row[2], :selsovet => row[3], :type => row[4]}}

			begin
			puts "\nNode #{osm_id}, name '#{osm_name}', URL:\nhttp://latlon.org/?zoom=13&lat=#{lat}&lon=#{lon}"
      puts "Yandex:\nhttp://maps.yandex.ru/?ll=#{lon}%2C#{lat}&z=12&l=map"
			puts "Candidates:"
			candidates.each {|c|
				printf("%3d. %4d %3s %20s %30s %30s %30s\n", candidates.index(c) + 1, c[:rowid], c[:type], c[:rus_name], c[:bel_name], osm_rayon, c[:selsovet])
			}
			puts "Select right place or just press <Enter> to skip"
			choice = STDIN.gets
			choice.chomp! unless choice.nil?
			end until choice.nil? or (0..candidates.size).include?(choice.to_i) or choice.empty?

			next if choice.empty?
			break if choice.nil?

			choice = choice.to_i
			selection = candidates[choice - 1]

			puts("UPDATE places SET id=#{osm_id} WHERE ROWID=#{selection[:rowid]}")
			@db.execute("UPDATE places SET id=#{osm_id} WHERE ROWID=#{selection[:rowid]}")
		}
	end

end

m = Matcher.new(ARGV[0])
#m.fix_osm_abbrevs!
m.do_manual_matching!
