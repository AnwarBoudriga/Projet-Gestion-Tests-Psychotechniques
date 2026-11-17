require('dotenv').config();

for (const k of ['DATABASE_URL', 'JWT_SECRET']) {
  if (!process.env[k]) {
    console.error(`[config] Variable d'environnement manquante : ${k}`);
    process.exit(1);
  }
}
if (process.env.JWT_SECRET.length < 32) {
  console.error('[config] JWT_SECRET doit contenir au moins 32 caractères.');
  process.exit(1);
}

module.exports = {
  port: Number(process.env.PORT) || 3000,
  isProd: process.env.NODE_ENV === 'production',
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '8h',
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean),
  bcryptRounds: Number(process.env.BCRYPT_ROUNDS) || 12,
};
