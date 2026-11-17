const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { bcryptRounds } = require('../config/env');

// Même normalisation que le Front : key.trim().toUpperCase()
const normalizeKey = (k) => String(k || '').trim().toUpperCase();
const prefixOf = (k) => normalizeKey(k).slice(0, 8);
const hashKey = (k) => bcrypt.hash(normalizeKey(k), bcryptRounds);
const verifyKey = (k, hash) => bcrypt.compare(normalizeKey(k), hash);

// Alphabet sans caractères ambigus (0/O, 1/I), comme _generateKey du MockStore.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function randomBlock(n) {
  let out = '';
  for (let i = 0; i < n; i++) out += ALPHABET[crypto.randomInt(ALPHABET.length)];
  return out;
}
/** Clé candidat : PT-XXXX-XXXX (CSPRNG, pas Math.random). */
const generateCandidateKey = () => `PT-${randomBlock(4)}-${randomBlock(4)}`;
/** Clé entreprise : CORP-XXXX-XXXX-XXXX. */
const generateCompanyKey = () => `CORP-${randomBlock(4)}-${randomBlock(4)}-${randomBlock(4)}`;

module.exports = { normalizeKey, prefixOf, hashKey, verifyKey, generateCandidateKey, generateCompanyKey };
