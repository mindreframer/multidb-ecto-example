defmodule Multidb.SqlitePragmas do
  @moduledoc """
  SQLite PRAGMA settings for better concurrency and performance.
  
  These pragmas are applied to every SQLite connection to enable:
  - WAL mode for better concurrent read/write access
  - Longer busy timeout to handle contention
  - Optimized synchronous mode
  - Foreign key constraints
  """

  def set_pragmas(conn) do
    # WAL mode for better concurrency (allows readers while writing)
    Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
    
    # Longer busy timeout (10 seconds) - wait longer when database is locked
    Exqlite.Sqlite3.execute(conn, "PRAGMA busy_timeout=10000")
    
    # Synchronous=NORMAL for better performance (safe with WAL mode)
    Exqlite.Sqlite3.execute(conn, "PRAGMA synchronous=NORMAL")
    
    # Enable foreign keys
    Exqlite.Sqlite3.execute(conn, "PRAGMA foreign_keys=ON")
    
    # Cache size (negative means KB, -2000 = 2MB cache)
    Exqlite.Sqlite3.execute(conn, "PRAGMA cache_size=-2000")
    
    :ok
  end
end
