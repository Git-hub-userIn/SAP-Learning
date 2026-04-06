// Load environment variables (will be auto-loaded by dotenv or manually set)
const host = process.env.DB_HOST || '127.0.0.1';
const port = process.env.DB_PORT || '5432';
const user = process.env.DB_USER || 'postgres';
const password = process.env.DB_PASSWORD || 'postgres';
const database = process.env.DB_NAME || 'capdb';

module.exports = {
  requires: {
    db: {
      '[pg]': {
        host,
        port: parseInt(port, 10),
        user,
        password,
        database,
        pool: {
          min: 1,
          max: 20,
          acquireTimeoutMillis: 60000,
          idleTimeoutMillis: 60000
        }
      }
    }
  }
};
