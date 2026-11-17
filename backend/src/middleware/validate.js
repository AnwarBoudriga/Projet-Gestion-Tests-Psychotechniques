const { badRequest } = require('../utils/errors');

/** validate(schema, 'body'|'query'|'params') : remplace la source par la version nettoyée par zod. */
module.exports = (schema, source = 'body') => (req, _res, next) => {
  const r = schema.safeParse(req[source]);
  if (!r.success) {
    const errors = r.error.issues.map((i) => ({ field: i.path.join('.'), message: i.message }));
    return next(badRequest('Données invalides.', errors));
  }
  req[source] = r.data;
  next();
};
