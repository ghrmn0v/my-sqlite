require 'csv'

class MySqliteRequest
  def initialize
    @query_type = :select
    @table_name = nil
    @data = []
    @columns = []
    @where_conditions = []
    @join = nil
    @order = nil
    @insert_data = nil
    @update_data = nil
  end

  # ========== Person 1: SELECT mühərriki ==========

  def from(table_name)
    @table_name = table_name
    @data = load_csv(table_name)
    self
  end

  def select(column_name)
    cols = column_name.is_a?(Array) ? column_name : [column_name]
    @columns = cols.map(&:to_s)
    self
  end

  def where(column_name, criteria)
    @where_conditions << { column: column_name.to_s, value: criteria }
    self
  end

  def join(column_on_db_a, filename_db_b, column_on_db_b)
    raise "Only 1 join per request allowed" if @join
    @join = {
      column_a: column_on_db_a.to_s,
      filename_b: filename_db_b,
      column_b: column_on_db_b.to_s
    }
    self
  end

  def order(order, column_name)
    @order = { direction: order, column: column_name.to_s }
    self
  end

  # ========== Person 2: Mutation metodları ==========

  def insert(table_name)
    @query_type = :insert
    @table_name = table_name
    self
  end

  def values(data)
    @insert_data = data.transform_keys(&:to_s)
    self
  end

  def update(table_name)
    @query_type = :update
    @table_name = table_name
    self
  end

  def set(data)
    @update_data = data.transform_keys(&:to_s)
    self
  end

  def delete
    @query_type = :delete
    self
  end

  # ========== Run ==========

  def run
    case @query_type
    when :select
      result = @data.dup
      result = apply_join(result) if @join
      result = apply_where(result) if @where_conditions.any?
      result = apply_order(result) if @order
      result = apply_select(result) unless @columns.empty?
      result
    when :insert
      run_insert
    when :update
      run_update
    when :delete
      run_delete
    end
  end

  private

  def load_csv(filename)
    rows = []
    CSV.foreach(filename, headers: true) do |row|
      rows << row.to_h
    end
    rows
  rescue Errno::ENOENT
    raise "Fayl tapilmadi: #{filename}"
  end

  def apply_where(rows)
    rows.select do |row|
      @where_conditions.all? do |condition|
        row[condition[:column]].to_s == condition[:value].to_s
      end
    end
  end

  def apply_join(rows)
    other_rows = load_csv(@join[:filename_b])
    column_a = @join[:column_a]
    column_b = @join[:column_b]
    joined = []

    rows.each do |row_a|
      other_rows.each do |row_b|
        if row_a[column_a].to_s == row_b[column_b].to_s
          merged = row_a.dup
          row_b.each do |key, value|
            merged_key = row_a.key?(key) ? "#{@join[:filename_b]}_#{key}" : key
            merged[merged_key] = value
          end
          joined << merged
        end
      end
    end
    joined
  end

  def apply_order(rows)
    column = @order[:column]
    direction = @order[:direction]
    sorted = rows.sort_by { |row| row[column].to_s }
    direction.to_sym == :desc ? sorted.reverse : sorted
  end

  def apply_select(rows)
    return rows if @columns.include?('*')
    rows.map do |row|
      row.select { |key, _| @columns.include?(key) }
    end
  end

  # ========== Mutation icra metodları ==========

  def run_insert
    rows = []
    headers = []

    if File.exist?(@table_name)
      csv = CSV.read(@table_name, headers: true)
      if csv.headers && !csv.headers.empty?
        headers = csv.headers
        rows = csv.map(&:to_h)
      end
    end

    if headers.empty?
      headers = @insert_data.keys.map(&:to_s)
    end

    new_row = {}
    headers.each do |h|
      h_str = h.to_s
      if h_str == 'id' && !@insert_data.key?('id')
        max_id = rows.map { |r| r['id'].to_i }.max || 0
        new_row[h_str] = (max_id + 1).to_s
      elsif @insert_data.key?(h_str)
        new_row[h_str] = @insert_data[h_str]
      else
        new_row[h_str] = nil
      end
    end

    rows << new_row

    CSV.open(@table_name, 'w') do |csv|
      csv << headers
      rows.each { |r| csv << headers.map { |h| r[h.to_s] } }
    end

    nil
  end

  def run_update
    raise "No data provided for update. Call set() before run()." if @update_data.nil?

    return nil unless File.exist?(@table_name)

    csv = CSV.read(@table_name, headers: true)
    headers = csv.headers
    rows = csv.map(&:to_h)

    rows.each do |row|
      match = if @where_conditions.any?
                @where_conditions.all? do |condition|
                  row[condition[:column]].to_s == condition[:value].to_s
                end
              else
                true
              end

      if match
        @update_data.each do |key, value|
          row[key.to_s] = value.to_s
        end
      end
    end

    CSV.open(@table_name, 'w') do |csv|
      csv << headers
      rows.each { |r| csv << headers.map { |h| r[h.to_s] } }
    end

    nil
  end

  def run_delete
    return nil unless File.exist?(@table_name)

    csv = CSV.read(@table_name, headers: true)
    headers = csv.headers
    rows = csv.map(&:to_h)

    if @where_conditions.any?
      rows = rows.reject do |row|
        @where_conditions.all? do |condition|
          row[condition[:column]].to_s == condition[:value].to_s
        end
      end
    else
      rows = []
    end

    CSV.open(@table_name, 'w') do |csv|
      csv << headers
      rows.each { |r| csv << headers.map { |h| r[h.to_s] } }
    end

    nil
  end
end