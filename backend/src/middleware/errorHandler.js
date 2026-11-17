const { isProd } = require('../config/env');

module.exports = {
  notFoundHandler: (_req, res) => res.status(404).json({ message: 'Route introuvable.' }),

  // eslint-disable-next-line no-unused-vars
  errorHandler: (err, _req, res, _next) => {
    if (err.type === 'entity.parse.failed') return res.status(400).json({ message: 'JSON invalide.' });
    if (err.type === 'entity.too.large') return res.status(413).json({ message: 'Requête trop volumineuse.' });
    if (err.status && err.status < 500) {
      return res.status(err.status).json({ message: err.message, ...(err.errors && { errors: err.errors }) });
    }
    console.error('[erreur]', err);
    res.status(500).json({ message: 'Erreur interne du serveur.', ...(isProd ? {} : { detail: err.message }) });
  },
};
