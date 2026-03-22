# Alan's NerdVault CMS — Build Instructions

Welcome to **NerdVault**, your personal collection manager for games, Pokémon, movies, and anything else you're into. You're going to build a full-stack web application from scratch using Docker, Python, React, and a real database.

By the end of this project you will have built:

- A **Python REST API** (Flask) that stores data in a relational database
- A **MariaDB database** with multiple related tables (you'll write real SQL and learn JOINs)
- A **React + TypeScript frontend** with plain CSS
- **Docker containers** that package everything up so it runs anywhere
- **Code quality tools** (linters, formatters, type checkers, git hooks) that professional teams use every day

The project is broken into **6 phases**. Each phase builds on the last, and every phase ends with a checkpoint so you know when you're done before moving on.

---

## Table of Contents

- [Phase 1: Environment and Docker Fundamentals](#phase-1-environment-and-docker-fundamentals)
- [Phase 2: Database Schema and REST API with Raw SQL](#phase-2-database-schema-and-rest-api-with-raw-sql)
- [Phase 3: React Frontend](#phase-3-react-frontend)
- [Phase 4: Code Quality and Git](#phase-4-code-quality-and-git)
- [Phase 5: ORM Refactor, Auth, and Seed Data](#phase-5-orm-refactor-auth-and-seed-data)
- [Phase 6: Stretch Goals](#phase-6-stretch-goals)
- [Glossary](#glossary)

---

## Phase 1: Environment and Docker Fundamentals

**Goal**: Get your development environment running and understand what Docker is.

**What you'll learn**: WSL, containers, Docker Compose, environment variables.

---

### Mini-Lesson: What is WSL?

WSL stands for **Windows Subsystem for Linux**. It lets you run a full Linux operating system (Ubuntu) right inside Windows — no dual-boot, no virtual machine UI, just a real Linux terminal.

Why does this matter? Almost all web servers run Linux. Tutorials, Stack Overflow answers, and deployment guides assume Linux commands. By developing inside WSL, everything you learn transfers directly to the real world.

WSL2 (the version you're using) runs an actual Linux kernel, not an emulation layer. It's fast, and Docker integrates with it natively.

**Resources**:
- [Microsoft: What is WSL?](https://learn.microsoft.com/en-us/windows/wsl/about)
- [Microsoft: WSL Setup Guide](https://learn.microsoft.com/en-us/windows/wsl/install)

---

### Mini-Lesson: What is a Container?

Imagine you're shipping a game to a friend. You could send them a list of instructions: "install this version of Java, download these libraries, set these settings..." — and hope it works on their machine. Or you could put the entire game, with all its dependencies, into a single box that runs exactly the same everywhere.

That box is a **container**.

A container packages your application code, its dependencies, and its configuration into a single unit that runs identically on your laptop, your friend's laptop, or a cloud server. Unlike a virtual machine (VM), a container doesn't need its own operating system — it shares the host's kernel, making it lightweight and fast.

Key terms:
- **Image**: A blueprint/recipe for a container. Think of it like a game ISO — it defines what's inside but isn't running yet.
- **Container**: A running instance of an image. Like mounting the ISO and playing the game.
- **Dockerfile**: A text file with instructions for building an image (install Python, copy your code, set the start command).

**Resources**:
- [Docker: What is a Container?](https://www.docker.com/resources/what-container/)
- [Docker Get Started Tutorial](https://docs.docker.com/get-started/)
- [Video: Docker in 100 Seconds (Fireship)](https://www.youtube.com/watch?v=Gjnup-PuquQ)
- [Video: Docker Networking Crash Course (NetworkChuck)](https://www.youtube.com/watch?v=3c-iBn73dDE)

---

### Mini-Lesson: What is Docker Compose?

Your app has multiple pieces: a Python API server and a MariaDB database (and later, an Nginx web server). Each runs in its own container. **Docker Compose** is a tool that lets you define all these containers in a single YAML file (`docker-compose.yml`) and start them all with one command.

Instead of running three separate `docker run` commands with long argument lists, you write:

```bash
docker compose up
```

And everything starts, connected to each other on a private network. Compose also handles volumes (persistent data), environment variables, and restart policies.

**Resources**:
- [Docker Compose Overview](https://docs.docker.com/compose/)
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/)

---

### Mini-Lesson: What are Environment Variables?

An environment variable is a key-value pair that lives outside your code. For example, your database password. You never want passwords in your source code (anyone who sees your code sees your password). Instead, you store them as environment variables and read them at runtime.

In Linux/WSL:
```bash
export DB_PASSWORD=supersecret
echo $DB_PASSWORD          # prints: supersecret
```

In a `.env` file (Docker Compose reads these automatically):
```
DB_HOST=db
DB_USER=nerdvault
DB_PASSWORD=supersecret
DB_NAME=nerdvault
```

In Python code:
```python
import os
password = os.environ.get("DB_PASSWORD", "default_value")
```

The `.env` file is listed in `.gitignore` so it never gets committed. You provide a `.env.example` file (with placeholder values) so other developers know what variables are needed.

**Resources**:
- [The Twelve-Factor App: Config](https://12factor.net/config)
- [Docker Compose: Environment Variables](https://docs.docker.com/compose/environment-variables/)

---

### Step 1.1: Run the Bootstrap Script

Open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\bootstrap.ps1
```

This installs WSL2 + Ubuntu, Docker Desktop, and dev tools. Follow the prompts. If it asks you to reboot, do so, then run the script again — it will pick up where it left off.

After the script finishes, verify everything inside a WSL terminal:

```bash
python3.12 --version    # should print Python 3.12.x
node --version           # should print v20.x.x
git --version            # should print git version 2.x.x
docker --version         # should print Docker version 2x.x.x (requires Docker Desktop running)
```

---

### Step 1.2: Set Up Your Project Directory

Inside WSL, create your project:

```bash
mkdir -p ~/nerdvault
cd ~/nerdvault
```

Open it in VS Code (make sure you have the WSL extension installed):

```bash
code .
```

VS Code will open connected to your WSL filesystem. The terminal inside VS Code is now a Linux terminal.

---

### Step 1.3: Create docker-compose.yml (MariaDB Only)

Create a file called `docker-compose.yml` in your project root. Start with just the database:

```yaml
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
```

Create a `.env` file (this stays on your machine, never committed):

```
DB_ROOT_PASSWORD=rootpassword
DB_HOST=db
DB_PORT=3306
DB_USER=nerdvault
DB_PASSWORD=secret
DB_NAME=nerdvault
```

Create a `.env.example` file (this gets committed — shows what variables are needed):

```
DB_ROOT_PASSWORD=changeme
DB_HOST=db
DB_PORT=3306
DB_USER=nerdvault
DB_PASSWORD=changeme
DB_NAME=nerdvault
```

Now start it:

```bash
docker compose up -d
```

The `-d` flag runs it in the background ("detached"). Check it's running:

```bash
docker compose ps
```

You should see the `db` service running on port 3306.

---

### Step 1.4: Connect to MariaDB

Install the MariaDB client inside WSL:

```bash
sudo apt-get install -y mariadb-client
```

Connect to your running database:

```bash
mysql -h 127.0.0.1 -P 3306 -u nerdvault -psecret nerdvault
```

You're now in a SQL shell. Try:

```sql
SHOW TABLES;
```

It's empty — that's expected! You'll create tables in Phase 2. Type `exit` to leave.

---

### Step 1.5: Write a Dockerfile for Flask

Create the `api/` directory and a minimal Flask app:

```bash
mkdir -p api
```

Create `api/requirements.txt`:

```
flask==3.1.*
pymysql==1.1.*
cryptography==44.*
```

Create `api/Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "app.py"]
```

Create `api/app.py` — the simplest possible Flask app:

```python
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
```

**Understanding the Dockerfile line by line:**
- `FROM python:3.12-slim` — start from an official Python image (like choosing a base game engine)
- `WORKDIR /app` — set the working directory inside the container
- `COPY requirements.txt .` — copy your dependency list in
- `RUN pip install ...` — install dependencies (happens once when building the image)
- `COPY . .` — copy your source code in
- `CMD [...]` — the command that runs when the container starts

---

### Step 1.6: Add Flask to Docker Compose

Update your `docker-compose.yml` to add the API service:

```yaml
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - db_data:/var/lib/mysql

  api:
    build: ./api
    restart: unless-stopped
    ports:
      - "5000:5000"
    environment:
      DB_HOST: db
      DB_PORT: 3306
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
    depends_on:
      - db
    volumes:
      - ./api:/app

volumes:
  db_data:
```

Key things to notice:
- `build: ./api` tells Compose to build an image from the Dockerfile in `api/`
- `depends_on: [db]` makes Compose start the database before the API
- `volumes: [./api:/app]` mounts your local code into the container, so changes take effect without rebuilding
- The API connects to the database using hostname `db` — Docker's internal DNS resolves this to the database container

Rebuild and start everything:

```bash
docker compose up --build -d
```

Test the health endpoint:

```bash
curl http://localhost:5000/api/health
```

You should see:

```json
{"status": "ok"}
```

---

### Phase 1 Checkpoint

Before moving on, verify:

- [ ] `docker compose up` starts both `db` and `api` containers
- [ ] `curl http://localhost:5000/api/health` returns `{"status": "ok"}`
- [ ] You can connect to MariaDB with the `mysql` client and run `SHOW TABLES;`
- [ ] You understand what a Dockerfile, an image, and a container are
- [ ] You understand what `docker-compose.yml` does and why we use environment variables

---

## Phase 2: Database Schema and REST API with Raw SQL

**Goal**: Design your database tables, write SQL, and build a full CRUD API.

**What you'll learn**: relational database design, SQL JOINs, REST APIs, HTTP, SQL injection prevention.

---

### Mini-Lesson: How HTTP Works

Every time your browser loads a page, it sends an **HTTP request** to a server and gets back an **HTTP response**. This is the fundamental protocol of the web.

A request has:
- A **method** (verb): `GET` (read), `POST` (create), `PUT` (update), `DELETE` (remove)
- A **URL** (path): `/api/items`, `/api/items/42`
- **Headers**: metadata (content type, auth tokens, etc.)
- An optional **body**: data you're sending (for POST/PUT)

A response has:
- A **status code**: `200 OK`, `201 Created`, `404 Not Found`, `400 Bad Request`, `500 Server Error`
- **Headers**: metadata
- A **body**: usually JSON data

Example: creating a new item might look like:

```
POST /api/items
Content-Type: application/json

{"title": "Breath of the Wild", "description": "Open world Zelda game"}
```

Response:

```
201 Created
Content-Type: application/json

{"id": 1, "title": "Breath of the Wild", ...}
```

**Resources**:
- [MDN: An Overview of HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview)
- [HTTP Status Codes as Cats](https://http.cat/) (seriously, bookmark this)

---

### Mini-Lesson: What is REST?

REST (Representational State Transfer) is a set of conventions for designing web APIs. The core ideas:

1. **URLs represent resources** (nouns, not verbs): `/api/items`, `/api/categories`
2. **HTTP methods are the verbs**: GET = read, POST = create, PUT = update, DELETE = remove
3. **Stateless**: each request contains everything the server needs — no "sessions" to remember

For NerdVault, your REST endpoints will look like:

| Action               | Method   | URL                    | Status Code |
|----------------------|----------|------------------------|-------------|
| List all items       | `GET`    | `/api/items`           | 200         |
| Get one item         | `GET`    | `/api/items/42`        | 200 or 404  |
| Create an item       | `POST`   | `/api/items`           | 201         |
| Update an item       | `PUT`    | `/api/items/42`        | 200 or 404  |
| Delete an item       | `DELETE` | `/api/items/42`        | 200 or 404  |
| List categories      | `GET`    | `/api/categories`      | 200         |
| Create a category    | `POST`   | `/api/categories`      | 201         |
| Delete a category    | `DELETE` | `/api/categories/5`    | 200 or 404  |

**Resources**:
- [RESTful API Design Guide (Microsoft)](https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design)
- [REST API Tutorial](https://restfulapi.net/)

---

### Mini-Lesson: SQL JOINs Explained

Your database has 4 tables. To get useful data, you need to combine rows from multiple tables. That's what a **JOIN** does.

**INNER JOIN** — returns only rows that have a match in both tables.

Example: Get all items with their metadata:

```sql
SELECT i.id, i.title, m.meta_key, m.meta_value
FROM items i
INNER JOIN item_meta m ON i.id = m.item_id
WHERE i.id = 1;
```

Result:

| id | title      | meta_key       | meta_value |
|----|------------|----------------|------------|
| 1  | Bulbasaur  | types          | grass, poison |
| 1  | Bulbasaur  | pokedex_number | 1          |
| 1  | Bulbasaur  | height         | 7          |
| 1  | Bulbasaur  | weight         | 69         |

**LEFT JOIN** — returns all rows from the left table, even if there's no match in the right table (unmatched columns become `NULL`).

```sql
SELECT i.id, i.title, m.meta_key
FROM items i
LEFT JOIN item_meta m ON i.id = m.item_id;
```

This ensures items with no metadata still appear (with `NULL` for meta columns).

**Many-to-many JOIN** — items and categories are linked through the `item_categories` junction table. To get an item's categories, you need two JOINs:

```sql
SELECT i.title, c.name AS category
FROM items i
JOIN item_categories ic ON i.id = ic.item_id
JOIN categories c ON ic.category_id = c.id
WHERE i.id = 1;
```

Result:

| title     | category |
|-----------|----------|
| Bulbasaur | Pokemon  |

**Resources**:
- [SQLBolt — Interactive JOIN Tutorial](https://sqlbolt.com/lesson/select_queries_with_joins) (do this one!)
- [W3Schools: SQL JOINs](https://www.w3schools.com/sql/sql_join.asp)
- [Visual Representation of SQL Joins](https://blog.codinghorror.com/a-visual-explanation-of-sql-joins/)

---

### Mini-Lesson: What is SQL Injection?

SQL injection is one of the oldest and most dangerous web vulnerabilities. It happens when user input is inserted directly into a SQL query string.

**Vulnerable code (NEVER do this):**

```python
# BAD! If title contains: '; DROP TABLE items; --
# the query becomes: SELECT * FROM items WHERE title = ''; DROP TABLE items; --'
query = f"SELECT * FROM items WHERE title = '{title}'"
cursor.execute(query)
```

**Safe code (ALWAYS do this):**

```python
# GOOD! PyMySQL handles escaping. The %s is a placeholder, not string formatting.
cursor.execute("SELECT * FROM items WHERE title = %s", (title,))
```

With parameterized queries, the database treats the user input as data, never as SQL commands. Always use `%s` placeholders and pass values as a tuple.

**Resources**:
- [OWASP: SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [Bobby Tables: A guide to preventing SQL injection](https://bobby-tables.com/)

---

### Mini-Lesson: Foreign Keys and Referential Integrity

A **foreign key** is a column in one table that references the primary key of another table. It's how you tell the database "this row belongs to that row."

In NerdVault, `item_meta.item_id` is a foreign key pointing to `items.id`. This means:
- You can't insert an `item_meta` row with an `item_id` that doesn't exist in `items`
- When you delete an item, you have a choice:
  - `ON DELETE CASCADE` — automatically delete all related metadata rows (what we'll use)
  - `ON DELETE RESTRICT` — refuse to delete the item if it still has metadata

CASCADE is appropriate here because metadata without its parent item is meaningless.

**Resources**:
- [MariaDB: Foreign Keys](https://mariadb.com/kb/en/foreign-keys/)
- [SQLBolt: Creating Tables with Constraints](https://sqlbolt.com/lesson/creating_tables)

---

### Task 2.1: Create the Database Tables

Write `CREATE TABLE` statements for all 4 tables. Here's the schema to implement — you write the actual SQL:

**`items`** — the core entity

| Column      | Type         | Constraints                          |
|-------------|--------------|--------------------------------------|
| id          | INT          | PRIMARY KEY, AUTO_INCREMENT          |
| title       | VARCHAR(255) | NOT NULL                             |
| description | TEXT         |                                      |
| image_url   | VARCHAR(500) |                                      |
| status      | VARCHAR(50)  | NOT NULL, DEFAULT 'draft'            |
| created_at  | DATETIME     | NOT NULL, DEFAULT CURRENT_TIMESTAMP  |
| updated_at  | DATETIME     | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP |

**`item_meta`** — key-value metadata per item

| Column     | Type         | Constraints                                    |
|------------|--------------|------------------------------------------------|
| id         | INT          | PRIMARY KEY, AUTO_INCREMENT                    |
| item_id    | INT          | NOT NULL, FOREIGN KEY -> items(id) ON DELETE CASCADE |
| meta_key   | VARCHAR(255) | NOT NULL                                       |
| meta_value | TEXT         |                                                |
| created_at | DATETIME     | NOT NULL, DEFAULT CURRENT_TIMESTAMP            |

Add an index on `(item_id, meta_key)` for fast lookups.

**`categories`** — reusable category labels

| Column      | Type         | Constraints                 |
|-------------|--------------|----------------------------|
| id          | INT          | PRIMARY KEY, AUTO_INCREMENT |
| name        | VARCHAR(255) | NOT NULL                    |
| slug        | VARCHAR(255) | NOT NULL, UNIQUE            |
| description | TEXT         |                             |

**`item_categories`** — junction table (many-to-many)

| Column      | Type | Constraints                                         |
|-------------|------|-----------------------------------------------------|
| item_id     | INT  | NOT NULL, FOREIGN KEY -> items(id) ON DELETE CASCADE |
| category_id | INT  | NOT NULL, FOREIGN KEY -> categories(id) ON DELETE CASCADE |

The primary key should be a composite of `(item_id, category_id)`.

Connect to MariaDB and run your `CREATE TABLE` statements. Verify with `SHOW TABLES;` and `DESCRIBE items;`.

**Hint**: Put your SQL in a file (e.g. `api/schema.sql`) so you can re-run it. Use `IF NOT EXISTS` on your CREATE statements.

---

### Task 2.2: Create a Database Connection Helper

Create `api/db.py` — a Python module that provides a function to get a database connection. Use `pymysql` and read credentials from environment variables (see the env vars mini-lesson from Phase 1).

Look at `api/seed_example.py` for an example of how this works — its `get_connection()` function is a good starting point.

**Hint**: Look up Flask's `g` object for storing per-request resources. Or start simple and just call the function in each route.

---

### Task 2.3: Implement Items CRUD Routes

Create `api/routes/` as a Python package (don't forget `__init__.py`). Build these endpoints:

**`GET /api/items`**
- Returns a JSON array of all items
- Each item should include its categories (this requires a JOIN through `item_categories` and `categories`)
- Support query parameter filtering: `GET /api/items?category=pokemon` filters by category slug
- Status code: `200`

**`GET /api/items/<id>`**
- Returns a single item by ID
- Include all `item_meta` rows as a key-value object (e.g. `{"types": "grass, poison", "height": "7"}`)
- Include category names
- Status code: `200` if found, `404` if not

**`POST /api/items`**
- Accepts JSON body with `title`, `description`, `image_url`, `status`, and optionally `meta` (object of key-value pairs) and `category_ids` (array of ints)
- Inserts into `items`, then `item_meta` rows, then `item_categories` rows
- Status code: `201` with the created item in the response body
- Status code: `400` if `title` is missing

**`PUT /api/items/<id>`**
- Updates the item. Can update meta and categories too.
- Status code: `200` if updated, `404` if not found

**`DELETE /api/items/<id>`**
- Deletes the item. Cascading foreign keys handle meta and category associations.
- Status code: `200` if deleted, `404` if not found

**Hints**:
- Use Flask Blueprints to organize your routes: [Flask Blueprints](https://flask.palletsprojects.com/en/stable/blueprints/)
- Remember: always use parameterized queries (`%s`), never f-strings for SQL values
- For `POST` and `PUT`, use `request.get_json()` to read the request body
- Return `jsonify(...)` for all responses
- Think about what happens if the user sends a `category_id` that doesn't exist

---

### Task 2.4: Implement Categories CRUD Routes

**`GET /api/categories`**
- Returns all categories
- Status code: `200`

**`POST /api/categories`**
- Accepts `name`, `slug`, `description`
- Status code: `201`
- Status code: `400` if name or slug is missing

**`DELETE /api/categories/<id>`**
- Deletes a category. The CASCADE on `item_categories` will remove associations.
- Status code: `200` or `404`

---

### Task 2.5: Register Blueprints and Test

Update `api/app.py` to import and register your route Blueprints. Test every endpoint with `curl`:

```bash
# Create a category
curl -X POST http://localhost:5000/api/categories \
  -H "Content-Type: application/json" \
  -d '{"name": "Pokemon", "slug": "pokemon", "description": "Gotta catch em all"}'

# Create an item with metadata and category
curl -X POST http://localhost:5000/api/items \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Pikachu",
    "description": "Electric mouse Pokemon",
    "image_url": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png",
    "status": "published",
    "meta": {"types": "electric", "pokedex_number": "25", "generation": "1"},
    "category_ids": [1]
  }'

# List all items (should include categories)
curl http://localhost:5000/api/items

# Get one item (should include metadata AND categories)
curl http://localhost:5000/api/items/1

# Filter by category
curl "http://localhost:5000/api/items?category=pokemon"

# Update an item
curl -X PUT http://localhost:5000/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Pikachu (Updated)", "meta": {"types": "electric", "base_experience": "112"}}'

# Delete an item
curl -X DELETE http://localhost:5000/api/items/1
```

---

### Phase 2 Checkpoint

Before moving on, verify:

- [ ] All 4 tables exist with proper foreign keys (`DESCRIBE item_meta;` shows the FK)
- [ ] `GET /api/items` returns items with their category names (not just IDs)
- [ ] `GET /api/items/1` returns the item with its metadata as key-value pairs AND category names
- [ ] `POST /api/items` creates an item with metadata and category associations in one request
- [ ] `DELETE /api/items/1` also removes the item's metadata and category links (CASCADE)
- [ ] `GET /api/items?category=pokemon` filters correctly
- [ ] You used parameterized queries everywhere (no f-strings in SQL)
- [ ] Data persists after `docker compose down && docker compose up` (the volume keeps it)

---

## Phase 3: React Frontend

**Goal**: Build a browser UI that talks to your API.

**What you'll learn**: React, TypeScript, JSX, CSS, multi-stage Docker builds, reverse proxies.

---

### Design Reference

Before you start coding, study the mockups in the `designs/` folder. These are the screens you're building. Your implementation doesn't have to be pixel-perfect — use them as a guide for layout, structure, and feel.

**Screens provided:**

| Mockup | File | What it shows |
|--------|------|---------------|
| Item List (Desktop) | `designs/design-desktop-item-list.png` | 3-column card grid, left sidebar with category filters and counts, top search bar, floating "+" button |
| Item List (Tablet) | `designs/design-tablet-item-list.png` | Hamburger menu replaces sidebar, horizontal category filter chips, 2-4 column card grid |
| Item List (Mobile) | `designs/design-mobile-item-list.png` | Single-column cards, horizontal scrollable category chips, bottom tab bar, hamburger menu |
| Item Detail (Desktop) | `designs/design-desktop-item-detail.png` | Centered layout, large cover image, metadata table with alternating row colors, category badges, Edit/Delete buttons |
| Item Detail (Mobile) | `designs/design-mobile-item-detail.png` | Full-width image, stacked metadata rows, same info but reflowed for narrow screen |
| Create/Edit Form (Desktop) | `designs/design-desktop-form.png` | Centered card form, text inputs for title/description/image URL, status dropdown, dynamic metadata key-value rows with add/remove, category checkboxes, Save/Cancel buttons |

**Responsive breakpoints** to implement:

```css
/* Mobile first: default styles target phones (<= 640px) */

/* Tablet */
@media (min-width: 641px) {
  /* 2-column card grid, larger spacing */
}

/* Desktop */
@media (min-width: 1025px) {
  /* 3-column card grid, persistent sidebar, wider content area */
}
```

**Layout patterns to notice in the mockups:**

- **Desktop**: persistent left sidebar (category filters) + main content area (card grid). Sidebar is always visible.
- **Tablet**: sidebar collapses into a hamburger menu. Category filters become horizontal scrollable chips above the grid. Grid drops to 2 columns.
- **Mobile**: single-column card stack. Category chips remain as horizontal scroll. Navigation moves to a bottom tab bar. Forms go full-width.
- **Item cards**: cover image on top, title below, category badge pill, one line of metadata preview. Dark card background with subtle border and rounded corners.
- **Item detail**: single centered column. Large image, then title + status badge, action buttons, metadata table, categories, description — in that order.
- **Form**: centered card container, stacked fields, metadata section has dynamic add/remove rows.

**Color palette** (from the mockups):

```css
:root {
  --bg-primary: #0f0f1a;       /* page background */
  --bg-secondary: #1a1a2e;     /* alternate/section backgrounds */
  --bg-card: #16213e;          /* card and form backgrounds */
  --text-primary: #e0e0e0;     /* main text */
  --text-secondary: #a0a0b0;   /* muted/metadata text */
  --accent: #00d4ff;           /* cyan — links, active states, primary buttons */
  --accent-hover: #00b8d4;     /* cyan hover */
  --danger: #ff4757;           /* delete buttons, errors */
  --success: #2ed573;          /* published badge, success states */
  --border: #2a2a4a;           /* card borders, dividers */
}
```

Study the mockups, then come back here and work through the mini-lessons and tasks below.

---

### Mini-Lesson: What is JSX/TSX?

In React, you write your UI using **JSX** — a syntax that looks like HTML but lives inside JavaScript. Since you're using TypeScript, it's called **TSX**.

```tsx
function ItemCard({ title, imageUrl }: { title: string; imageUrl: string }) {
  return (
    <div className="item-card">
      <img src={imageUrl} alt={title} />
      <h2>{title}</h2>
    </div>
  );
}
```

This isn't actually HTML — React transforms it into JavaScript function calls that create DOM elements. The curly braces `{}` let you embed JavaScript expressions inside the markup.

Key differences from HTML:
- `class` becomes `className` (because `class` is a reserved word in JS)
- Self-closing tags must have a slash: `<img />` not `<img>`
- You can use JS expressions: `{items.length}`, `{isLoading ? "Loading..." : "Done"}`

**Resources**:
- [React: Writing Markup with JSX](https://react.dev/learn/writing-markup-with-jsx)
- [React: Your First Component](https://react.dev/learn/your-first-component)

---

### Mini-Lesson: What is TypeScript?

TypeScript is JavaScript with **types**. Types tell the compiler (and you) what shape your data has, catching bugs before you even run the code.

```typescript
// Without TypeScript: runtime error if item.title is undefined
function showItem(item) {
  console.log(item.title.toUpperCase());
}

// With TypeScript: compiler error if you forget a required field
interface Item {
  id: number;
  title: string;
  description: string;
  image_url: string | null;
  categories: string[];
  meta: Record<string, string>;
}

function showItem(item: Item) {
  console.log(item.title.toUpperCase()); // safe -- we know title exists and is a string
}
```

You define **interfaces** to describe the shape of your API responses, and TypeScript ensures you handle them correctly throughout your code.

**Resources**:
- [TypeScript: The Basics](https://www.typescriptlang.org/docs/handbook/2/basic-types.html)
- [React TypeScript Cheatsheet](https://react-typescript-cheatsheet.netlify.app/)

---

### Mini-Lesson: What is a Multi-Stage Docker Build?

Your React app needs Node.js to **build** (compile TypeScript, bundle modules), but once built, it's just static HTML/CSS/JS files. You don't need Node.js to **serve** them — a lightweight web server like Nginx is better.

A **multi-stage build** uses two stages in one Dockerfile:

```dockerfile
# Stage 1: Build (uses Node)
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve (uses Nginx, no Node)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

The final image only contains Nginx + your built files. Node.js is thrown away. This makes the image much smaller and more secure.

**Resources**:
- [Docker: Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)

---

### Mini-Lesson: How Does a Reverse Proxy Work?

Right now, your API runs on port 5000 and (soon) your frontend on port 80. When the frontend JavaScript calls `fetch("/api/items")`, the browser sends that request to port 80 (where Nginx is). But the API is on port 5000.

**Nginx as a reverse proxy** solves this. It intercepts requests and routes them:
- `/api/*` requests → forwarded to the Flask container on port 5000
- Everything else → served as static files (your React app)

```
Browser → Nginx (:80)
              ├── /api/*    → Flask (:5000)
              └── /*        → static files (React build)
```

This way, the browser only talks to one host on one port. No CORS issues, no port juggling.

**Resources**:
- [Nginx: Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [Nginx Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)

---

### Task 3.1: Scaffold the React App

Inside your project root (in WSL):

```bash
npm create vite@latest frontend -- --template react-ts
cd frontend
npm install
```

Test it works locally:

```bash
npm run dev
```

Open `http://localhost:5173` in your browser. You should see the Vite + React starter page. Stop the dev server (`Ctrl+C`) when done.

---

### Task 3.2: Define TypeScript Interfaces

Create a file for your API types (e.g. `frontend/src/types.ts`). Define interfaces that match your API response shapes:

- `Item` — with id, title, description, image_url, status, categories (as names), meta (as key-value pairs), created_at
- `Category` — with id, name, slug, description
- `ItemFormData` — the shape of data your create/edit form sends to the API

These interfaces should match the JSON your Flask API returns. You designed that structure in Phase 2.

---

### Task 3.3: Build the Components

Build these React components. The structure is a suggestion — organize however makes sense to you:

**`ItemList`** — Displays all items in a grid or list
- Fetches from `GET /api/items` on mount
- Shows title, image (if present), and category badges
- Has a category filter sidebar (fetches from `GET /api/categories`, clicking a category filters the list)

**`ItemDetail`** — Shows one item in full
- Fetches from `GET /api/items/<id>`
- Displays all metadata key-value pairs
- Shows category badges
- Has Edit and Delete buttons

**`ItemForm`** — Create or edit an item
- Fields for title, description, image_url, status (dropdown: draft/published)
- Dynamic metadata section: a list of key-value input pairs with an "Add Field" button and remove buttons
- Category checkboxes (fetches available categories)
- Submits via `POST /api/items` (create) or `PUT /api/items/<id>` (edit)

**`CategoryManager`** — CRUD for categories
- Lists existing categories with delete buttons
- Has a form to create new categories (name, slug, description)

**`DeleteConfirmModal`** — A reusable modal that asks "Are you sure?" before deleting

**Hints**:
- Use `fetch()` to call your API. Start simple: `fetch("/api/items").then(res => res.json()).then(data => ...)`
- Use `useState` for component state, `useEffect` for fetching data on mount
- React Router (optional) can give you URL-based navigation (`/items`, `/items/42`, `/categories`)

---

### Task 3.4: Style with Plain CSS

No CSS frameworks. Write your own styles. Use the **color palette and breakpoints** from the [Design Reference](#design-reference) section at the top of this phase, and study the mockup images in `designs/`.

Your CSS should implement three layouts:

**Mobile (default, up to 640px)**:
- Single-column card stack (see `design-mobile-item-list.png`)
- Hamburger menu icon in the top nav, category filter as horizontal scrollable chips
- Bottom tab bar with icons for navigation (Home, Categories, Add, Settings)
- Cards are full-width with cover image, title, category badge, one metadata line
- Forms go full-width with comfortable touch-target sizing (min 44px tap targets)

**Tablet (641px - 1024px)**:
- 2-column card grid (see `design-tablet-item-list.png`)
- Hamburger menu stays, category chips stay horizontal above the grid
- No bottom tab bar — use the hamburger for navigation
- More generous padding/margins than mobile

**Desktop (1025px+)**:
- Persistent left sidebar (about 240px) with category filters and item counts (see `design-desktop-item-list.png`)
- 3-column card grid in the main content area
- No hamburger menu — sidebar is always visible
- Item detail and forms are centered with a max-width (see `design-desktop-item-detail.png`, `design-desktop-form.png`)

**General styling requirements**:
- Use CSS custom properties (the `--bg-primary`, `--accent`, etc. variables from the design reference)
- Card layouts using CSS Grid or Flexbox
- Hover states on all interactive elements (buttons, cards, links)
- Consistent spacing system (multiples of 8px: 8, 16, 24, 32, 48)
- Category badges as colored pills with rounded corners
- Metadata table with alternating row backgrounds on the detail view
- Smooth transitions on hover/focus (e.g. `transition: background-color 0.2s ease`)

**Resources**:
- [CSS Tricks: A Complete Guide to Flexbox](https://css-tricks.com/snippets/css/a-guide-to-flexbox/)
- [CSS Tricks: A Complete Guide to Grid](https://css-tricks.com/snippets/css/complete-guide-grid/)
- [MDN: CSS Basics](https://developer.mozilla.org/en-US/docs/Learn/Getting_started_with_the_web/CSS_basics)
- [MDN: Responsive Design](https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design)
- [MDN: Using Media Queries](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_media_queries/Using_media_queries)

---

### Task 3.5: Dockerize the Frontend

Create `frontend/nginx.conf`:

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Serve static files (React app)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Reverse proxy API requests to Flask
    location /api/ {
        proxy_pass http://api:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Create `frontend/Dockerfile`:

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

Add the frontend service to `docker-compose.yml`:

```yaml
  frontend:
    build: ./frontend
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - api
```

And remove (or keep, up to you) the `ports: ["5000:5000"]` from the `api` service — the API is now only accessible through Nginx, not directly.

Rebuild and test:

```bash
docker compose up --build -d
```

Open `http://localhost` in your browser. Your React app should load and be able to create/read/update/delete items.

---

### Phase 3 Checkpoint

Before moving on, verify:

- [ ] `docker compose up --build` starts all 3 containers (db, api, frontend)
- [ ] Browsing `http://localhost` shows your React app
- [ ] You can create a new item with metadata and categories through the UI
- [ ] You can view an item and see its metadata and categories
- [ ] You can edit and delete items through the UI
- [ ] You can create and delete categories
- [ ] Filtering by category works
- [ ] Your CSS uses the dark color palette from the design reference
- [ ] **Desktop** (resize browser to 1200px+): 3-column grid, persistent sidebar, matches `design-desktop-item-list.png`
- [ ] **Tablet** (resize to ~768px): 2-column grid, horizontal category chips, matches `design-tablet-item-list.png`
- [ ] **Mobile** (resize to ~375px or use DevTools device mode): single-column stack, bottom tab bar, matches `design-mobile-item-list.png`
- [ ] Item detail page matches the layout in `design-desktop-item-detail.png` / `design-mobile-item-detail.png`
- [ ] Create/edit form matches `design-desktop-form.png` (centered card, dynamic metadata rows)

---

## Phase 4: Code Quality and Git

**Goal**: Set up professional-grade code quality tools and version control.

**What you'll learn**: linters, formatters, type checkers, git hooks.

---

### Mini-Lesson: Why Linters and Formatters?

A **linter** analyzes your code for potential errors and bad practices without running it. It catches things like:
- Using a variable before defining it
- Forgetting to handle an error
- Using `==` instead of `===` in JavaScript

A **formatter** automatically reformats your code to follow a consistent style. No more arguing about tabs vs spaces, trailing commas, or line length — the formatter decides, and everyone's code looks the same.

Why bother? Two reasons:
1. **Catch bugs early** — a linter finds problems before you even run the code
2. **Consistency** — when every file follows the same style, code is easier to read and review

For this project:
- **Ruff** handles both linting and formatting for Python (it replaces older tools like Black, flake8, and isort)
- **ESLint** lints JavaScript/TypeScript
- **Prettier** formats JavaScript/TypeScript/CSS/HTML
- **Stylelint** lints CSS specifically
- **mypy** checks Python type hints
- **TypeScript compiler** (`tsc`) checks your TypeScript types

**Resources**:
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [ESLint Getting Started](https://eslint.org/docs/latest/use/getting-started)
- [Prettier: Why?](https://prettier.io/docs/en/why-prettier.html)

---

### Mini-Lesson: What are Git Hooks?

A **git hook** is a script that runs automatically at certain points in your git workflow. The most useful one is **pre-commit** — it runs before every commit.

The [pre-commit](https://pre-commit.com/) framework makes this easy. You define hooks in a `.pre-commit-config.yaml` file, and pre-commit runs them every time you try to commit. If any hook fails (e.g. a linter finds errors), the commit is blocked until you fix the issue.

This means bad code can't get into your repo. It's like a bouncer for your codebase.

**Resources**:
- [pre-commit: Introduction](https://pre-commit.com/#intro)
- [Git Hooks (Atlassian)](https://www.atlassian.com/git/tutorials/git-hooks)

---

### Task 4.1: Initialize Git

```bash
cd ~/nerdvault
git init
```

Create `.gitignore`:

```
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/

# Node
node_modules/
dist/

# Environment
.env

# Database volume (managed by Docker)
db_data/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
```

Make your first commit:

```bash
git add .
git commit -m "Initial commit: Flask API + MariaDB + React frontend with Docker"
```

Create a GitHub repository (via [github.com](https://github.com) or `gh repo create`) and push:

```bash
git remote add origin git@github.com:YOUR_USERNAME/nerdvault.git
git push -u origin main
```

**Hint**: If you haven't set up SSH keys for GitHub, follow this guide: [GitHub: Generating SSH Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

---

### Task 4.2: Set Up Python Linting and Formatting

Install Ruff and mypy:

```bash
pip install ruff mypy
```

Create `api/pyproject.toml` (Ruff configuration):

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "UP", "B", "A", "SIM"]

[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
ignore_missing_imports = true
```

Run them on your code and fix what they find:

```bash
cd api
ruff check .          # show lint issues
ruff format .         # auto-format
mypy .                # type-check
```

Fix any errors they report. Ruff format will auto-fix most style issues. Lint and mypy errors need manual attention — read the error messages, they tell you what's wrong.

---

### Task 4.3: Set Up Frontend Linting and Formatting

Inside `frontend/`:

```bash
cd ~/nerdvault/frontend
npm install -D eslint prettier stylelint stylelint-config-standard @eslint/js typescript-eslint
```

Create ESLint config (`frontend/eslint.config.js`) — look at the [ESLint docs for flat config](https://eslint.org/docs/latest/use/configure/configuration-files) for the format.

Create Prettier config (`frontend/.prettierrc`):

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all"
}
```

Create Stylelint config (`frontend/.stylelintrc.json`):

```json
{
  "extends": "stylelint-config-standard"
}
```

Run them all:

```bash
npx eslint src/              # lint TypeScript/React
npx prettier --check src/    # check formatting
npx prettier --write src/    # auto-fix formatting
npx stylelint "src/**/*.css" # lint CSS
npx tsc --noEmit             # type-check TypeScript
```

Fix all errors.

---

### Task 4.4: Configure Pre-Commit Hooks

Back in the project root:

```bash
cd ~/nerdvault
```

Create `.pre-commit-config.yaml`:

```yaml
repos:
  # Ruff (Python lint + format)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.6
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # mypy (Python type checking)
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.14.1
    hooks:
      - id: mypy
        additional_dependencies: [pymysql-stubs, flask]
        args: [--ignore-missing-imports]

  # Frontend (ESLint, Prettier, Stylelint)
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx --prefix frontend eslint
        language: system
        files: 'frontend/src/.*\.(ts|tsx)$'
        pass_filenames: true
      - id: prettier
        name: prettier
        entry: npx --prefix frontend prettier --write
        language: system
        files: 'frontend/src/.*\.(ts|tsx|css|html)$'
        pass_filenames: true
      - id: stylelint
        name: stylelint
        entry: npx --prefix frontend stylelint
        language: system
        files: 'frontend/src/.*\.css$'
        pass_filenames: true

  # General file hygiene
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
```

Install the hooks:

```bash
pre-commit install
```

Run on all files to verify:

```bash
pre-commit run --all-files
```

Fix anything that fails, then commit:

```bash
git add .
git commit -m "Add code quality tools: Ruff, mypy, ESLint, Prettier, Stylelint, pre-commit"
```

The pre-commit hooks will run automatically. If they fail, fix the issues and try the commit again.

---

### Phase 4 Checkpoint

Before moving on, verify:

- [ ] `ruff check api/` reports no errors
- [ ] `mypy api/` reports no errors (or only expected ones)
- [ ] `npx eslint src/` in `frontend/` reports no errors
- [ ] `npx prettier --check src/` in `frontend/` reports no errors
- [ ] `npx stylelint "src/**/*.css"` in `frontend/` reports no errors
- [ ] `pre-commit run --all-files` passes
- [ ] Your repo is on GitHub with at least 2 commits

---

## Phase 5: ORM Refactor, Auth, and Seed Data

**Goal**: Replace raw SQL with an ORM, add authentication, and seed real data.

**What you'll learn**: SQLAlchemy, HTTP authentication, working with external APIs.

---

### Mini-Lesson: What is an ORM?

An **ORM** (Object-Relational Mapper) lets you interact with your database using Python classes instead of raw SQL strings.

Without an ORM (what you've been doing):
```python
cursor.execute("SELECT id, title FROM items WHERE status = %s", ("published",))
rows = cursor.fetchall()  # rows is a list of dicts
```

With SQLAlchemy (an ORM):
```python
items = Item.query.filter_by(status="published").all()
# items is a list of Item objects with .id, .title, .description, etc.
```

The ORM maps your tables to Python classes:
```python
class Item(db.Model):
    __tablename__ = "items"
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)
    meta = db.relationship("ItemMeta", backref="item", cascade="all, delete-orphan")
```

**When is raw SQL better?** Complex queries with multiple JOINs, aggregations, or database-specific features can be cleaner in raw SQL. Many professionals use both — ORM for simple CRUD, raw SQL for complex reports.

**Resources**:
- [SQLAlchemy: Quickstart](https://docs.sqlalchemy.org/en/20/orm/quickstart.html)
- [Flask-SQLAlchemy](https://flask-sqlalchemy.readthedocs.io/en/stable/quickstart/)
- [SQLAlchemy: Relationship Patterns](https://docs.sqlalchemy.org/en/20/orm/relationships.html)

---

### Mini-Lesson: What is HTTP Basic Auth?

HTTP Basic Authentication is the simplest form of web authentication. The client sends a username and password with every request, encoded in a header.

The `Authorization` header looks like: `Basic dXNlcjpwYXNzd29yZA==`

That gibberish is just `user:password` encoded in **base64**. Base64 is encoding, NOT encryption — anyone who intercepts the header can decode it instantly. That's why Basic Auth should only be used over HTTPS in production.

For NerdVault, you'll use a single admin password stored in your `.env` file. Flask's `request.authorization` property parses the header for you.

```python
from flask import request

@app.before_request
def check_auth():
    if request.method in ("POST", "PUT", "DELETE"):
        auth = request.authorization
        if not auth or auth.password != os.environ["ADMIN_PASSWORD"]:
            return jsonify({"error": "Unauthorized"}), 401
```

Testing with curl:

```bash
curl -u admin:yourpassword -X POST http://localhost/api/items ...
```

**Resources**:
- [MDN: HTTP Authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication)
- [Flask: Request Object](https://flask.palletsprojects.com/en/stable/api/#flask.Request.authorization)

---

### Task 5.1: Refactor to SQLAlchemy

Install Flask-SQLAlchemy:

```bash
# Add to api/requirements.txt:
flask-sqlalchemy==3.1.*
```

Create SQLAlchemy models in `api/models/` for all 4 tables: `Item`, `ItemMeta`, `Category`, and the `item_categories` association table.

Define relationships:
- `Item` has a one-to-many relationship with `ItemMeta`
- `Item` has a many-to-many relationship with `Category` through `item_categories`

Then refactor your route handlers to use SQLAlchemy queries instead of raw SQL. **The API should behave identically** — same URLs, same request/response format, same status codes. Test with the same curl commands from Phase 2.

**Hints**:
- Use `db.relationship()` with `backref` and `cascade` options
- For many-to-many, define an association table with `db.Table()`
- `db.session.add()`, `db.session.commit()`, `db.session.rollback()`
- `Item.query.get_or_404(id)` is a convenient shortcut

---

### Task 5.2: Add Admin Auth

Add `ADMIN_PASSWORD` to your `.env` (and `.env.example`).

Protect write endpoints (`POST`, `PUT`, `DELETE`) with HTTP Basic auth. `GET` endpoints should remain public (anyone can browse the collection, but only the admin can modify it).

Update your React frontend to prompt for a password when creating/editing/deleting, and send it with the `Authorization` header.

**Hint**: `fetch("/api/items", { headers: { "Authorization": "Basic " + btoa("admin:" + password) } })`

---

### Task 5.3: Seed Data

Copy `api/seed_example.py` to `api/seed.py` and extend it:

1. Study the example script — it seeds 5 Pokémon from PokéAPI across all 4 tables
2. Add at least one more category (e.g. "Games") with manually entered items, or use an API like [RAWG](https://rawg.io/apidocs) (free API key)
3. Add at least one category you invent yourself — anything you're into

Run the seed script:

```bash
docker compose exec api python seed.py
```

Verify the seeded data appears in your React app.

---

### Phase 5 Checkpoint

Before moving on, verify:

- [ ] All raw SQL is replaced with SQLAlchemy queries
- [ ] API behavior is unchanged (same curl commands work)
- [ ] `POST /api/items` without auth returns `401 Unauthorized`
- [ ] `POST /api/items` with correct credentials returns `201 Created`
- [ ] `GET /api/items` works without auth (public read)
- [ ] `python seed.py` populates the DB with Pokémon and at least one other category
- [ ] The React app shows the seeded data

---

## Phase 6: Stretch Goals

Pick any of these. Each one teaches something new. No hand-holding — use the linked resources and figure it out.

### GraphQL Endpoint

Add a GraphQL API alongside your REST API using [Strawberry](https://strawberry.rocks/docs/integrations/flask) or [Ariadne](https://ariadnegraphql.org/). Expose the same data (items, categories, metadata) through GraphQL queries.

This teaches you an alternative API paradigm where the client decides exactly what data it wants, instead of the server deciding the response shape.

### Database Migrations with Alembic

Install [Flask-Migrate](https://flask-migrate.readthedocs.io/en/latest/) (which wraps Alembic). Add a new column to one of your tables (e.g. `rating` on `items`), generate a migration, and run it — without losing existing data.

This is how real applications evolve their database schema over time without wiping and recreating tables.

### Automated Tests

Write tests for your API using [pytest](https://docs.pytest.org/) and a test database. Cover at least:
- Creating an item with metadata and categories
- Getting an item returns the right JOINed data
- Deleting an item cascades properly
- Auth rejects unauthorized requests

For the frontend, add component tests with [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/).

### Full-Text Search

Add a search endpoint `GET /api/items?search=pikachu` that uses MariaDB's [FULLTEXT index](https://mariadb.com/kb/en/full-text-indexes/) to search across `items.title`, `items.description`, and `item_meta.meta_value`.

### Image Upload

Instead of just storing image URLs, let users upload images. Store them in a Docker volume and serve them through Nginx. Learn about multipart form uploads and file handling in Flask.

### Pagination

Add pagination to `GET /api/items`: support `?page=1&per_page=20` query parameters. Return pagination metadata in the response (total count, page count, next/previous page URLs). Use SQL `LIMIT` and `OFFSET`.

---

## Glossary

| Term | Definition |
|------|------------|
| **API** | Application Programming Interface — a set of URLs your frontend calls to read and write data |
| **CRUD** | Create, Read, Update, Delete — the four basic operations on data |
| **Container** | A lightweight, isolated environment that packages your app with its dependencies |
| **Docker Compose** | A tool for defining and running multi-container Docker applications |
| **Dockerfile** | A text file with instructions for building a Docker image |
| **EAV** | Entity-Attribute-Value — a database pattern where attributes are stored as rows, not columns (like `item_meta`) |
| **Environment Variable** | A key-value pair set outside your code, used for configuration and secrets |
| **Flask** | A lightweight Python web framework for building APIs and web apps |
| **Foreign Key** | A column that references the primary key of another table, enforcing referential integrity |
| **Image (Docker)** | A read-only template used to create containers — like a snapshot of an application |
| **JOIN** | A SQL operation that combines rows from two or more tables based on a related column |
| **JSX/TSX** | A syntax extension that lets you write HTML-like code in JavaScript/TypeScript (used by React) |
| **Junction Table** | A table that exists solely to connect two other tables in a many-to-many relationship |
| **Linter** | A tool that analyzes code for potential errors and style issues without running it |
| **MariaDB** | An open-source relational database, compatible with MySQL |
| **ORM** | Object-Relational Mapper — a library that lets you use Python objects instead of raw SQL |
| **Parameterized Query** | A SQL query that uses placeholders (%s) instead of directly inserting values, preventing SQL injection |
| **Pre-commit** | A framework for running checks (linting, formatting) automatically before each git commit |
| **REST** | Representational State Transfer — conventions for designing web APIs using HTTP methods and URLs |
| **Reverse Proxy** | A server (like Nginx) that sits in front of other servers and forwards requests to them |
| **SQLAlchemy** | A Python ORM and SQL toolkit for working with databases |
| **TypeScript** | A superset of JavaScript that adds static types, catching errors at compile time |
| **Volume (Docker)** | Persistent storage that survives container restarts — used for database data |
| **WSL** | Windows Subsystem for Linux — runs a real Linux environment inside Windows |
