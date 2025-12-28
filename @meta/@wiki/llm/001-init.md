I want to implement a feature where I support different databases in an Elixir application. 

I still don't know how to properly do it. 
I want to support SQLite and Postgres. 
And I want to be able to switch my implementation at runtime. 
And this seems to be really hard. 
There is no official solution for this. 

And I want to switch those databases at runtime. 
That means I do not want to recompile my application to switch to a different database. 
It should be supported by a runtime environment variable. 
This runtime environment variable will decide if my application uses SQLite or Postgres. 
Now how should I structure my application to support this use case? 


Really think this issue through, because it's not trivial. 
Feel free to add Ecto, Postgres and SQLite to the current Empty Elixir project to prove your point. 