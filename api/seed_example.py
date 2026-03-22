"""
seed_example.py - Populate the NerdVault database with Pokemon data from PokeAPI.

This script demonstrates how to:
  1. Connect to MariaDB using environment variables
  2. Create a category ("Pokemon") if it doesn't already exist
  3. Fetch data from an external API (PokeAPI)
  4. Insert rows across multiple related tables (items, item_meta, item_categories)
  5. Use parameterized queries to avoid SQL injection

It seeds 5 starter Pokemon. YOUR JOB is to study this script, then write
similar seed logic for games, movies, or whatever categories you invent.

Usage:
    export DB_HOST=localhost DB_PORT=3306 DB_USER=nerdvault DB_PASSWORD=secret DB_NAME=nerdvault
    python3 seed_example.py

PokeAPI docs: https://pokeapi.co/docs/v2
"""

import json
import os
import sys
import urllib.request

import pymysql

# ---------------------------------------------------------------------------
# Database connection
# ---------------------------------------------------------------------------

def get_connection():
    """Create a MariaDB connection using environment variables.

    We read credentials from env vars so they never appear in source code.
    See the 'What are environment variables?' mini-lesson in INSTRUCTIONS.md.
    """
    return pymysql.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ.get("DB_USER", "nerdvault"),
        password=os.environ.get("DB_PASSWORD", "secret"),
        database=os.environ.get("DB_NAME", "nerdvault"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )

# ---------------------------------------------------------------------------
# PokeAPI helpers
# ---------------------------------------------------------------------------

def fetch_pokemon(pokemon_id: int) -> dict:
    """Fetch a single Pokemon from PokeAPI by its national dex number.

    PokeAPI is free and requires no API key, making it perfect for learning.
    Endpoint docs: https://pokeapi.co/docs/v2#pokemon
    """
    url = f"https://pokeapi.co/api/v2/pokemon/{pokemon_id}"
    with urllib.request.urlopen(url) as resp:
        return json.loads(resp.read().decode())


def fetch_species(pokemon_id: int) -> dict:
    """Fetch species data (contains the flavor text / description)."""
    url = f"https://pokeapi.co/api/v2/pokemon-species/{pokemon_id}"
    with urllib.request.urlopen(url) as resp:
        return json.loads(resp.read().decode())


def get_english_flavor_text(species_data: dict) -> str:
    """Pull the first English flavor-text entry from species data."""
    for entry in species_data.get("flavor_text_entries", []):
        if entry.get("language", {}).get("name") == "en":
            # Flavor texts contain weird line breaks; clean them up
            return entry["flavor_text"].replace("\n", " ").replace("\f", " ")
    return ""

# ---------------------------------------------------------------------------
# Seeding logic
# ---------------------------------------------------------------------------

def ensure_category(cursor, name: str, slug: str, description: str) -> int:
    """Insert a category if it doesn't exist yet, and return its id.

    This uses INSERT IGNORE so re-running the script won't create duplicates.
    The slug is a URL-friendly version of the name (e.g. "pokemon").
    """
    cursor.execute(
        """
        INSERT IGNORE INTO categories (name, slug, description)
        VALUES (%s, %s, %s)
        """,
        (name, slug, description),
    )
    cursor.execute("SELECT id FROM categories WHERE slug = %s", (slug,))
    row = cursor.fetchone()
    return row["id"]


def seed_pokemon(cursor, pokemon_id: int, category_id: int) -> None:
    """Fetch one Pokemon and insert it across items, item_meta, and item_categories.

    This is where you can see the multi-table schema in action:
      - One row in `items` for the Pokemon itself
      - Multiple rows in `item_meta` for its attributes (type, height, weight, etc.)
      - One row in `item_categories` to link it to the "Pokemon" category
    """
    print(f"  Fetching Pokemon #{pokemon_id}...")
    data = fetch_pokemon(pokemon_id)
    species = fetch_species(pokemon_id)

    name = data["name"].capitalize()
    sprite_url = data["sprites"]["other"]["official-artwork"]["front_default"] or ""
    description = get_english_flavor_text(species)

    # -- 1. Insert into `items` -----------------------------------------------
    # %s placeholders are filled in by PyMySQL -- NEVER use f-strings for SQL values.
    # See the 'SQL Injection' mini-lesson in INSTRUCTIONS.md.
    cursor.execute(
        """
        INSERT INTO items (title, description, image_url, status)
        VALUES (%s, %s, %s, %s)
        """,
        (name, description, sprite_url, "published"),
    )
    item_id = cursor.lastrowid  # the auto-incremented id of the row we just inserted

    # -- 2. Insert metadata rows into `item_meta` ----------------------------
    # Each attribute is a separate row with a meta_key and meta_value.
    # This is the EAV (Entity-Attribute-Value) pattern.
    types_str = ", ".join(t["type"]["name"] for t in data["types"])
    meta_rows = [
        ("pokedex_number", str(pokemon_id)),
        ("types", types_str),
        ("height", str(data["height"])),       # in decimeters
        ("weight", str(data["weight"])),       # in hectograms
        ("base_experience", str(data.get("base_experience", ""))),
    ]

    for meta_key, meta_value in meta_rows:
        cursor.execute(
            """
            INSERT INTO item_meta (item_id, meta_key, meta_value)
            VALUES (%s, %s, %s)
            """,
            (item_id, meta_key, meta_value),
        )

    # -- 3. Link to category via junction table `item_categories` -------------
    # This creates the many-to-many relationship. One Pokemon can belong to
    # multiple categories, and one category can contain many items.
    cursor.execute(
        """
        INSERT IGNORE INTO item_categories (item_id, category_id)
        VALUES (%s, %s)
        """,
        (item_id, category_id),
    )

    print(f"  -> {name} (#{pokemon_id}) seeded with {len(meta_rows)} meta rows.")


def main():
    # The 5 original starter Pokemon (Gen 1) -- recognizable for any Pokemon fan
    POKEMON_IDS = [1, 4, 7, 25, 150]  # Bulbasaur, Charmander, Squirtle, Pikachu, Mewtwo

    print("Connecting to MariaDB...")
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # Create the "Pokemon" category (or get its id if it already exists)
        pokemon_cat_id = ensure_category(
            cursor,
            name="Pokemon",
            slug="pokemon",
            description="Pocket Monsters from the Pokemon franchise",
        )
        print(f"Category 'Pokemon' ready (id={pokemon_cat_id}).")

        # Seed each Pokemon
        for pid in POKEMON_IDS:
            seed_pokemon(cursor, pid, pokemon_cat_id)

        # Commit all inserts as one transaction. If anything above failed,
        # nothing gets written -- this keeps the database consistent.
        conn.commit()
        print(f"\nDone! Seeded {len(POKEMON_IDS)} Pokemon.")

    except Exception as e:
        conn.rollback()
        print(f"\nError during seeding: {e}", file=sys.stderr)
        print("All changes rolled back -- database is unchanged.", file=sys.stderr)
        sys.exit(1)

    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
