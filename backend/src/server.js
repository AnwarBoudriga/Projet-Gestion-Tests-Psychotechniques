const { port } = require('./config/env');
const { pool } = require('./config/db');
const app = require('./app');

const server = app.listen(port, () => console.log(`[psytech] API sur http://localhost:${port}`));

const stop = () => server.close(() => pool.end().then(() => process.exit(0)));
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
