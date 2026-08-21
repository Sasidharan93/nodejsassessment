const express = require('express');
const helmet = require('helmet');
const pool = require('./db');
const app = express();
app.use(helmet());
app.use(express.json());

// Ensure table exists on startup (simple bootstrap - not for production scale, migrations preferred there)
pool.query(`
  CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
  )
`).catch(err => console.error('Failed to ensure items table exists:', err.message));

// Health check - required for Cloud Run readiness
app.get('/healthz', (req, res) => res.status(200).json({ status: 'ok' }));
// Create table if not exists (simple bootstrap, ideally use migrations in real projects)
app.get('/items', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM items ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Database query failed' });
  }
});
app.post('/items', async (req, res) => {
  const { name } = req.body;
  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'Invalid name' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO items (name) VALUES ($1) RETURNING *',
      [name]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Database insert failed' });
  }
});
module.exports = app;
