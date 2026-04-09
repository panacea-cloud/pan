-- ─────────────────────────────────────────────────────────
-- PAN — Schema Supabase
-- Esegui questo SQL nell'editor di Supabase:
-- Dashboard → SQL Editor → New Query → Incolla → Run
-- ─────────────────────────────────────────────────────────

-- Tabella annunci
CREATE TABLE IF NOT EXISTS listings (
  id          BIGSERIAL PRIMARY KEY,
  title       TEXT NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  category    TEXT NOT NULL DEFAULT 'altro',
  price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  condition   TEXT DEFAULT 'Buone',
  description TEXT CHECK (char_length(description) <= 500),
  location    TEXT,           -- solo quartiere/città, non indirizzo esatto
  lat         DOUBLE PRECISION,
  lng         DOUBLE PRECISION,
  contact     TEXT,           -- nascosto nel frontend finché non si clicca
  active      BOOLEAN DEFAULT true,
  sold        BOOLEAN DEFAULT false,
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Indice geografico per query veloci in zona
CREATE INDEX IF NOT EXISTS listings_location_idx ON listings (lat, lng);
CREATE INDEX IF NOT EXISTS listings_category_idx ON listings (category);
CREATE INDEX IF NOT EXISTS listings_active_idx   ON listings (active, created_at DESC);

-- Ricerca full-text in italiano
CREATE INDEX IF NOT EXISTS listings_fts_idx ON listings
  USING GIN (to_tsvector('italian', title || ' ' || COALESCE(description, '')));

-- ─────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- Chiunque può leggere gli annunci attivi
-- Solo l'autore può modificare/cancellare il proprio
-- ─────────────────────────────────────────────────────────
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Lettura pubblica degli annunci attivi
CREATE POLICY "Chiunque può leggere annunci attivi"
  ON listings FOR SELECT
  USING (active = true);

-- Inserimento: chiunque (anche anonimo per il pilot)
-- In produzione: restringere agli utenti autenticati
CREATE POLICY "Inserimento libero"
  ON listings FOR INSERT
  WITH CHECK (true);

-- Modifica: solo l'autore
CREATE POLICY "Solo autore può modificare"
  ON listings FOR UPDATE
  USING (auth.uid() = user_id);

-- Cancellazione: solo l'autore
CREATE POLICY "Solo autore può cancellare"
  ON listings FOR DELETE
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- STORAGE per le immagini
-- ─────────────────────────────────────────────────────────
-- Nel Dashboard Supabase:
-- Storage → New Bucket → nome: "pan-images" → Public: ON

-- Policy upload immagini (esegui nel SQL editor)
INSERT INTO storage.buckets (id, name, public)
VALUES ('pan-images', 'pan-images', true)
ON CONFLICT DO NOTHING;

CREATE POLICY "Upload immagini pubblico"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pan-images');

CREATE POLICY "Lettura immagini pubblica"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pan-images');

-- ─────────────────────────────────────────────────────────
-- DATI DI ESEMPIO (opzionale, per testare)
-- ─────────────────────────────────────────────────────────
INSERT INTO listings (title, category, price, condition, description, location, lat, lng, contact) VALUES
  ('Nike Air Max 90 tg 42',      'abbigliamento', 55,  'Ottime',  'Come nuove, usate 3 volte. Scatola originale.',      'Prati, Roma',     41.908, 12.462, '346xxxxxxx'),
  ('MacBook Pro 2019 13"',       'elettronica',   650, 'Buone',   'SSD 256GB, batteria nuova. Qualche graffietto.',     'Trastevere',      41.889, 12.469, 'DM Instagram'),
  ('Cassettiera ferro battuto',  'arredamento',   45,  'Buone',   '3 cassetti. Ritiro a mano zona Prati.',              'Prati, Roma',     41.912, 12.459, '334xxxxxxx'),
  ('Trek Domane 54cm',           'sport',         320, 'Buone',   'Shimano 105, revisione fatta. Ottima per city.',     'Flaminio, Roma',  41.921, 12.474, '320xxxxxxx'),
  ('Harry Potter serie completa','libri',          25,  'Ottime',  'Edizione illustrata, tutti e 7 i volumi.',           'Testaccio',       41.882, 12.473, '339xxxxxxx'),
  ('La Roche-Posay SPF50',       'bellezza',       9,  'Ottime',  'Quasi pieno, ricevuto in regalo.',                   'Parioli',         41.924, 12.493, '349xxxxxxx'),
  ('PS5 + 3 giochi',             'giochi',        380, 'Ottime',  'Perfetta. Cambio console.',                          'EUR, Roma',       41.853, 12.476, '348xxxxxxx'),
  ('Lampada Artemide vintage',   'arredamento',    80, 'Buone',   'Anni 80, originale e funzionante.',                  'Ostiense',        41.868, 12.477, '333xxxxxxx');
