# Welcome to My Sqlite
***

## Task
The challenge is to build a lightweight SQLite-like database engine in Ruby that operates on CSV files instead of binary database files. The core requirements include implementing a query builder class (`MySqliteRequest`) that supports progressive method chaining for SELECT, INSERT, UPDATE, and DELETE operations. Additionally, a Command Line Interface (`my_sqlite_cli.rb`) must be created to accept SQL-like commands from the user, parse them, and execute them against CSV-based tables. The project must handle filtering (WHERE), sorting (ORDER), joining (JOIN), and persistent file mutations while maintaining a clean, chainable API.

## Description
We solved the problem by splitting the work between two team members. Person 1 built the core query engine with CSV parsing, SELECT filtering, JOIN logic, and ORDER sorting. Person 2 extended the engine with data mutation capabilities (INSERT, UPDATE, DELETE) and built the CLI using Ruby's `readline` library. The `MySqliteRequest` class uses an internal state machine (`@query_type`) to determine whether to execute a read or write operation during `run()`. The CLI parses user input with regular expressions, translates SQL-like syntax into method calls on the request object, and prints results in a pipe-delimited format. All data is persisted back to CSV files after every write operation.

## Installation
No external dependencies are required beyond Ruby itself (version 2.7 or higher). The project uses only the Ruby Standard Library (`csv` and `readline`).

1. Clone or download the project files.
2. Ensure you have Ruby installed:
   ```bash
   ruby -v
   ```
3. Place your CSV data files in the project directory or reference them by path.


## Usage
You can use the library programmatically or via the CLI.

### Programmatic Usage

ruby 
```
require_relative 'my_sqlite_request'

# SELECT example
request = MySqliteRequest.new
request = request.from('nba_player_data.csv')
request = request.select('name')
request = request.where('birth_state', 'Indiana')
puts request.run.inspect
# => [{"name"=>"Andre Brown"}, {"name"=>"Michael"}]

# INSERT example
MySqliteRequest.new.insert('nba_player_data.csv')
  .values({'name' => 'John', 'email' => 'john@doe.com', 'birth_state' => 'Texas'})
  .run

# UPDATE example
MySqliteRequest.new.update('nba_player_data.csv')
  .set({'email' => 'new@email.com'})
  .where('name', 'John')
  .run

# DELETE example
MySqliteRequest.new.from('nba_player_data.csv')
  .where('name', 'John')
  .delete
  .run
  ```

### CLI Usage

bash
```
ruby my_sqlite_cli.rb
```

bash
```
MySQLite version 0.1 2026-08-12
my_sqlite_cli> SELECT * FROM nba_player_data.csv;
my_sqlite_cli> SELECT name, email FROM nba_player_data.csv WHERE birth_state = 'Indiana';
my_sqlite_cli> INSERT INTO nba_player_data.csv VALUES (John, john@johndoe.com, A, https://blog.johndoe.com);
my_sqlite_cli> UPDATE nba_player_data.csv SET email = 'jane@janedoe.com', blog = 'https://blog.janedoe.com' WHERE name = 'Jane';
my_sqlite_cli> DELETE FROM nba_player_data.csv WHERE name = 'John';
my_sqlite_cli> quit
```

### The Core Team


<span><i>Made at <a href='https://qwasar.io'>Qwasar SV -- Software Engineering School</a></i></span>
<span><img alt='Qwasar SV -- Software Engineering School's Logo' src='https://storage.googleapis.com/qwasar-public/qwasar-logo_50x50.png' width='20px' /></span>
