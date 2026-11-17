/** Erreur applicative. Format {message, errors[]} = celui lu par Api.errorMessage côté Flutter. */
class HttpError extends Error {
  constructor(status, message, errors) {
    super(message);
    this.status = status;
    this.errors = errors;
  }
}
module.exports = {
  HttpError,
  badRequest: (m, e) => new HttpError(400, m, e),
  unauthorized: (m = 'Authentification requise.') => new HttpError(401, m),
  forbidden: (m = 'Accès refusé.') => new HttpError(403, m),
  notFound: (m = 'Ressource introuvable.') => new HttpError(404, m),
  conflict: (m) => new HttpError(409, m),
};
