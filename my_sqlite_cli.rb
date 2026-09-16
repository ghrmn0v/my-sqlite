require 'readline'
require 'csv'
require_relative 'my_sqlite_request'

def print_result(rows)
  return if rows.nil? || rows.empty?
  rows.each do |row|
    puts row.values.join('|')
  end
end

def parse_columns(cols_str)
  return ['*'] if cols_str.strip == '*'
  cols_str.split(',').map(&:strip)
end

def parse_where_conditions(request, where_str)
  return unless where_str
  conditions = where_str.split(/\s+AND\s+/i)
  conditions.each do |cond|
    if cond =~ /(\w+)\s*=\s*['"]?(.+?)['"]?$/
      request.where($1, $2.gsub(/^['"]|['"]$/, ''))
    end
  end
end

def handle_select(cmd)
  request = MySqliteRequest.new

  if cmd =~ /SELECT\s+(.+?)\s+FROM/i
    request.select(parse_columns($1))
  end

  if cmd =~ /FROM\s+(\S+)/i
    request.from($1)
  end

  if cmd =~ /JOIN\s+(\S+)\s+ON\s+(\w+)\s*=\s*(\w+)/i
    request.join($2, $1, $3)
  end

  where_part = cmd[/WHERE\s+(.+?)(?:\s+ORDER\s+BY|\s*$)/i, 1]
  parse_where_conditions(request, where_part)

  if cmd =~ /ORDER\s+BY\s+(\w+)\s+(ASC|DESC)/i
    order = $2.downcase == 'asc' ? :asc : :desc
    request.order(order, $1)
  end

  result = request.run
  print_result(result)
end

def handle_insert(cmd)
  if cmd =~ /INSERT\s+INTO\s+(\S+)\s+VALUES\s*\((.+)\)/i
    table = $1.strip
    values_str = $2.strip
    values = values_str.split(',').map { |v| v.strip.gsub(/^['"]|['"]$/, '') }

    headers = []
    if File.exist?(table)
      csv = CSV.read(table, headers: true)
      headers = csv.headers if csv.headers
    end

    data = {}

    if headers.any? && headers[0] == 'id' && values.length == headers.length - 1
      headers[1..-1].each_with_index do |h, i|
        data[h] = values[i] if i < values.length
      end
    elsif headers.any? && values.length == headers.length
      headers.each_with_index do |h, i|
        data[h] = values[i] if i < values.length
      end
    else
      headers.each_with_index do |h, i|
        data[h] = values[i] if i < values.length
      end
    end

    MySqliteRequest.new.insert(table).values(data).run
    puts "Inserted."
  else
    puts "Invalid INSERT syntax."
  end
end

def handle_update(cmd)
  if cmd =~ /UPDATE\s+(\S+)\s+SET\s+(.+)/i
    rest = $2
    table = $1.strip

    set_str = rest
    where_str = nil
    if rest =~ /(.+?)\s+WHERE\s+(.+)/i
      set_str = $1
      where_str = $2
    end

    set_data = {}
    set_str.scan(/(\w+)\s*=\s*('[^']*'|"[^"]*"|[^,]+)/) do |key, val|
      set_data[key] = val.strip.gsub(/^['"]|['"]$/, '')
    end

    request = MySqliteRequest.new.update(table).set(set_data)
    parse_where_conditions(request, where_str)

    request.run
    puts "Updated."
  else
    puts "Invalid UPDATE syntax."
  end
end

def handle_delete(cmd)
  if cmd =~ /DELETE\s+FROM\s+(\S+)/i
    table = $1.strip
    request = MySqliteRequest.new.from(table).delete

    where_part = cmd[/WHERE\s+(.+?)$/i, 1]
    parse_where_conditions(request, where_part)

    request.run
    puts "Deleted."
  else
    puts "Invalid DELETE syntax."
  end
end

def process_command(cmd)
  cmd = cmd.strip.chomp(';')

  case cmd
  when /^SELECT/i
    handle_select(cmd)
  when /^INSERT/i
    handle_insert(cmd)
  when /^UPDATE/i
    handle_update(cmd)
  when /^DELETE/i
    handle_delete(cmd)
  else
    puts "Unknown command."
  end
end

def run_cli
  puts "MySQLite version 0.1 2026-08-12"

  while line = Readline.readline('my_sqlite_cli> ', true)
    line = line.strip
    break if ['quit', 'exit', '.quit', '.exit'].include?(line.downcase)
    next if line.empty?

    begin
      process_command(line)
    rescue => e
      puts "Error: #{e.message}"
      if e.message.include?("Fayl tapilmadi") || e.message.include?("No such file")
        puts "Current directory: #{Dir.pwd}"
        puts "Make sure the CSV file exists here, or use the full path."
      end
    end
  end
end

run_cli if __FILE__ == $0