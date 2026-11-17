const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { corsOrigins, isProd } = require('./config/env');
const { notFoundHandler, errorHandler } = require('./middleware/errorHandler');
const { query } = require('./config/db');

const app = express();

app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({
  origin: corsOrigins.length ? corsOrigins : !isProd,   // dev : tout autoriser ; prod : liste blanche
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', async (_req, res) => {
  try {
    await query('SELECT 1');
    res.json({ status: 'ok', db: 'ok' });
  } catch {
    res.status(503).json({ status: 'error', db: 'down' });
  }
});

app.use('/api/entreprise/auth', require('./routes/auth.routes'));

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
