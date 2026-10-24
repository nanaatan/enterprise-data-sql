# enterprise-data-sql

Export Data
```psql
pg_dump -U {username} -d {database_name} > {external_file_name}.sql
```

Import Data
```psql
psql -U {username} -d {database_name} < {external_file_name}.sql
```
Add query execution time
```
\timing
```
