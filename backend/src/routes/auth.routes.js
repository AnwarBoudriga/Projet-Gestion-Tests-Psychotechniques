const router = require('express').Router();
const { z } = require('zod');
const rateLimit = require('express-rate-limit');
const validate = require('../middleware/validate');
const auth = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');
const ctrl = require('../controllers/auth.controller');

// Anti force brute : 10 tentatives / 15 min / IP.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Trop de tentatives. Réessayez dans quelques minutes.' },
});

const loginSchema = z.object({
  cle: z.string({ required_error: 'La clé entreprise est obligatoire.' })
    .trim()
    .min(1, 'La clé entreprise est obligatoire.')
    .max(100, 'Clé entreprise invalide.'),
}).strict();

router.post('/login', loginLimiter, validate(loginSchema), asyncHandler(ctrl.login));
router.get('/me', auth, ctrl.me);

module.exports = router;
