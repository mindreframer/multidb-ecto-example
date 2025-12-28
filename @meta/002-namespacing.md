I would like to add namespace support to the current proof of concept. 
This means it should be possible to create a namespace, switch between namespaces for a particular request and make sure that all operations that are executed are in the scope of a single namespace. 
For Postgres we will use the database native namespaces. 
And for SQLite we will use um separate databases for each namespace. 
