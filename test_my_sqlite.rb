require 'minitest/autorun'
require 'csv'
require_relative 'my_sqlite_request'

class TestMySqliteRequest < Minitest::Test
  def setup
    @test_file = 'test_players.csv'
    CSV.open(@test_file, 'w') do |csv|
      csv << ['id', 'name', 'email', 'birth_state', 'blog']
      csv << ['1', 'Jane', 'jane@doe.com', 'California', 'http://blog.janedoe.com']
      csv << ['2', 'John', 'john@doe.com', 'New York', 'https://blog.johndoe.com']
      csv << ['3', 'Andre Brown', 'andre@brown.com', 'Indiana', 'https://blog.andre.com']
      csv << ['4', 'Michael', 'mike@test.com', 'Indiana', 'https://mike.blog.com']
      csv << ['5', 'Sarah', 'sarah@test.com', 'California', 'https://sarah.blog.com']
    end
  end

  def teardown
    File.delete(@test_file) if File.exist?(@test_file)
    File.delete('test_join.csv') if File.exist?('test_join.csv')
  end

  def test_select_where
    result = MySqliteRequest.new.from(@test_file).select('name').where('birth_state', 'Indiana').run
    assert_equal [{"name"=>"Andre Brown"}, {"name"=>"Michael"}], result
  end

  def test_select_multiple_where
    result = MySqliteRequest.new.from(@test_file).select('name')
      .where('birth_state', 'Indiana')
      .where('name', 'Michael')
      .run
    assert_equal [{"name"=>"Michael"}], result
  end

  def test_select_order_desc
    result = MySqliteRequest.new.from(@test_file).select('name').order(:desc, 'name').run
    assert_equal 'Sarah', result.first['name']
    assert_equal 'Andre Brown', result.last['name']
  end

  def test_select_star
    result = MySqliteRequest.new.from(@test_file).select('*').where('id', '1').run
    assert_equal '1', result.first['id']
    assert_equal 'Jane', result.first['name']
  end

  def test_insert
    MySqliteRequest.new.insert(@test_file).values({'name' => 'Test', 'email' => 'test@test.com', 'birth_state' => 'Texas'}).run
    csv = CSV.read(@test_file, headers: true)
    last = csv.entries.last
    assert_equal 'Test', last['name']
    assert_equal '6', last['id']
  end

  def test_update_with_where
    MySqliteRequest.new.update(@test_file).set({'email' => 'updated@doe.com'}).where('name', 'Jane').run
    csv = CSV.read(@test_file, headers: true)
    jane = csv.entries.find { |r| r['name'] == 'Jane' }
    assert_equal 'updated@doe.com', jane['email']
  end

  def test_update_multiple_where
    MySqliteRequest.new.update(@test_file).set({'email' => 'multi@update.com'})
      .where('birth_state', 'Indiana')
      .where('name', 'Michael')
      .run
    csv = CSV.read(@test_file, headers: true)
    michael = csv.entries.find { |r| r['name'] == 'Michael' }
    assert_equal 'multi@update.com', michael['email']
    andre = csv.entries.find { |r| r['name'] == 'Andre Brown' }
    refute_equal 'multi@update.com', andre['email']
  end

  def test_update_without_set_raises
    assert_raises(RuntimeError) do
      MySqliteRequest.new.update(@test_file).where('name', 'Jane').run
    end
  end

  def test_delete
    MySqliteRequest.new.from(@test_file).where('name', 'John').delete.run
    csv = CSV.read(@test_file, headers: true)
    names = csv.entries.map { |r| r['name'] }
    refute_includes names, 'John'
  end

  def test_join
    CSV.open('test_join.csv', 'w') do |csv|
      csv << ['player_id', 'team']
      csv << ['1', 'Lakers']
      csv << ['2', 'Warriors']
    end

    result = MySqliteRequest.new.from(@test_file).select(['name', 'team'])
      .join('id', 'test_join.csv', 'player_id')
      .run

    assert result.any? { |r| r['name'] == 'Jane' && r['team'] == 'Lakers' }
    assert result.any? { |r| r['name'] == 'John' && r['team'] == 'Warriors' }
  end
end