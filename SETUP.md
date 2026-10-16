# Setup: PostgreSQL and SQLite on Windows

This guide gets the Olist e-commerce data into **both** databases. The same project then shows two sets of skills:

| | SQLite | PostgreSQL |
|---|---|---|
| What it is | A single file (`olist.db`), no server | A database server running on your PC |
| How data gets in | Python script (`scripts/load_data.py`) | psql's `\copy` command (or the same Python script) |
| Foreign keys | Declared up front, checked with `PRAGMA foreign_key_check` | Added after loading with `ALTER TABLE` |
| Types | Flexible (TEXT, INTEGER, REAL); dates stored as text | Strict (TIMESTAMP, NUMERIC(10,2), CHAR(2)...) |
| Monthly grouping | `strftime('%Y-%m', ts)` | `DATE_TRUNC('month', ts)` |
| Power BI | Needs a third-party ODBC driver | Built-in connector, so use this one for the dashboard |

Time needed: about 45 minutes, most of it installing.

---

## 0. Project folder and data

1. Unzip this kit somewhere simple, for example `C:\Users\<you>\Documents\olist-sales-ops`.
2. Go to the Kaggle dataset **"Brazilian E-Commerce Public Dataset by Olist"** (kaggle.com/datasets/olistbr/brazilian-ecommerce). You need a free Kaggle account. Click **Download** and unzip it.
3. Put all **9 CSV files** directly into `data\raw\`. Leave the file names unchanged.

Open a terminal **in the project folder**: in File Explorer, open the folder, then type `powershell` in the address bar and press Enter. Run every command below from there, because the scripts use paths relative to that folder.

Check Python is installed:

```powershell
py --version
```

If that fails, install Python from python.org and tick **"Add python.exe to PATH"** during setup.

---

## Part A: SQLite

### A1. Install the SQLite command-line tool

1. Go to **sqlite.org/download.html** → *Precompiled Binaries for Windows* → download **sqlite-tools-win-x64-….zip**.
2. Unzip it to `C:\sqlite` (you should see `C:\sqlite\sqlite3.exe`).
3. Add `C:\sqlite` to your PATH: press the Windows key, type **"environment variables"**, open *Edit environment variables for your account* → select **Path** → **Edit** → **New** → `C:\sqlite` → OK.
4. Open a **new** terminal and check:

```powershell
sqlite3 --version
```

Optional GUI: **DB Browser for SQLite** (sqlitebrowser.org) lets you browse tables and run queries with a mouse.

### A2. Load the data

Python has SQLite built in, so there is nothing to install:

```powershell
py scripts/load_data.py --db sqlite
```

The script checks that all 9 files are present with the right columns, builds the tables, loads every row (empty fields become NULL), reports any broken relationships, and creates `olist.db` in the project folder. Expect it to take under a minute.

### A3. Query it

```powershell
sqlite3 -box olist.db ".read sql/checks/data_quality_checks.sql"
sqlite3 olist.db ".read sql/sqlite/02_monthly_revenue.sql"
```

Or open an interactive session:

```powershell
sqlite3 olist.db
```
```
.tables
.mode box
SELECT order_status, COUNT(*) FROM orders GROUP BY order_status;
.quit
```

---

## Part B: PostgreSQL

### B1. Install

1. Go to **postgresql.org/download/windows** → **Download the installer** (the EDB installer). Pick the newest version for Windows x86-64.
2. In the installer, keep these components: **PostgreSQL Server**, **pgAdmin 4**, **Command Line Tools**. Untick **Stack Builder**, which you don't need.
3. Set a password for the `postgres` superuser and **write it down**. Keep port **5432** and the default locale.
4. Add the command-line tools to your PATH, the same way as in A1, using
   `C:\Program Files\PostgreSQL\<version>\bin` (check the version number in that folder).
5. Open a **new** terminal and check:

```powershell
psql --version
```

### B2. Create the database

```powershell
psql -U postgres -c "CREATE DATABASE olist;"
```

It asks for the password from B1. To stop being asked on every command in this terminal session:

```powershell
$env:PGPASSWORD = "your-password"
```

(Don't put this line in any file you commit to GitHub.)

### B3. Load the data with psql (the native way)

Run the scripts in order, from the project folder:

```powershell
psql -U postgres -d olist -f sql/postgres/01_create_tables.sql
psql -U postgres -d olist -f sql/postgres/02_load_csv.sql
psql -U postgres -d olist -f sql/postgres/03_add_constraints.sql
```

- `01` creates typed tables (it drops them first, so it is safe to re-run).
- `02` bulk-loads each CSV with `\copy`. The geolocation file is about 1 million rows and takes the longest.
- `03` adds foreign keys and indexes **after** loading. If a key fails, PostgreSQL names the bad value. That is a data-quality finding worth writing up.

To start over, run `01`, `02`, `03` again in that order.

### B3 (alternative). Load with Python

This route shows the Python skill instead of psql scripting:

```powershell
py -m pip install "psycopg[binary]"
py scripts/load_data.py --db postgres --user postgres --dbname olist
```

It streams each file with PostgreSQL's `COPY`, the same mechanism as `\copy`, then adds the constraints.

### B4. Query it

```powershell
psql -U postgres -d olist -f sql/checks/data_quality_checks.sql
psql -U postgres -d olist -f sql/postgres/04_monthly_revenue.sql
```

Interactive session: `psql -U postgres -d olist`, then `\dt` (list tables), `\d orders` (describe a table), `\q` (quit).

**pgAdmin:** open pgAdmin 4 → Servers → PostgreSQL → Databases → `olist` → right-click → **Query Tool**. You can paste any query from the `sql` folder there.

---

## Check both databases agree

`sql/checks/data_quality_checks.sql` uses only standard SQL, so it runs unchanged on both databases. Run it against each one: the numbers should match. Compare the row counts with the Kaggle page, which should show roughly 99k orders, 112k order items and 100k customers.

Things the checks will show in the real data, worth a line in your README:

- `customer_id` is one per order. Use `customer_unique_id` to count real repeat customers.
- Some `review_id`s appear more than once, so the reviews table has no primary key.
- A few product categories have no English translation, and some products have no category at all.
- Orders that were never delivered have no delivery date. Exclude them from delivery-time measures.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `'psql' / 'sqlite3' is not recognized` | The PATH step was missed, or the terminal was opened before it. Open a new terminal. |
| `password authentication failed for user "postgres"` | Use the password you set in the installer. |
| `\copy`: `No such file or directory` | Run psql from the project folder, and check that the CSVs are directly in `data\raw\`, not in a subfolder. |
| `03_add_constraints.sql`: `constraint ... already exists` | Re-run `01` → `02` → `03` in order. |
| Accented text (ã, é, ç) looks garbled in psql | Run `chcp 65001` and `$env:PGCLIENTENCODING = "UTF8"` before starting psql. The data itself is fine. |
| psql warns that the console code page differs from the Windows code page | This is harmless. The `chcp 65001` fix above also removes it. |
| SQLite: `database is locked` | Close DB Browser (or any other program that has `olist.db` open) and run again. |
| Loader says a file is missing or has unexpected columns | Re-download from Kaggle. Don't open and re-save the CSVs in Excel, because Excel changes dates and encoding. |

---

## Before you push to GitHub

`.gitignore` already leaves out the CSVs and `olist.db`. They are large, and the README should link to Kaggle instead of including the data. Commit the `sql` folder, the `scripts` folder and this guide.
