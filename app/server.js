require('dotenv').config();

const express = require('express');
const mysql = require('mysql2/promise');

const app = express();

app.use(express.urlencoded({ extended: true }));

const port = process.env.PORT || 3000;

const regionName = process.env.REGION_NAME || 'Unknown Region';

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  connectTimeout: 5000
};

let pool;

async function initDB() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
  }

  try {
    const connection = await pool.getConnection();

    try {
      await connection.query(`
        CREATE TABLE IF NOT EXISTS messages (
          id INT AUTO_INCREMENT PRIMARY KEY,
          message VARCHAR(255) NOT NULL,
          region VARCHAR(100) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      console.log("Table ensured");
    } catch (err) {
      console.log("Table create skipped:", err.message);
    }

    connection.release();

  } catch (err) {
    console.error("Database connection failed:", err.message);
  }
}

// # IMPORTANT FOR TARGET GROUP HEALTH CHECK
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/', async (req, res) => {

  let dbStatus = "Connected";
  let messages = [];

  try {
    const [rows] = await pool.query(
      'SELECT * FROM messages ORDER BY created_at DESC LIMIT 10'
    );

    messages = rows;

  } catch (err) {
    dbStatus = err.message;
  }

  const html = `
  <html>
    <body style="font-family: Arial; padding:40px;">
      <h1>AWS Warm Standby POC</h1>

      <h2>Region: ${regionName}</h2>

      <h3>Database Status: ${dbStatus}</h3>

      <form method="POST" action="/add">
        <button type="submit">
          Add Record
        </button>
      </form>

      <table border="1" cellpadding="10" cellspacing="0">
        <tr>
          <th>ID</th>
          <th>Message</th>
          <th>Region</th>
          <th>Created</th>
        </tr>

        ${
          messages.length > 0
            ? messages.map(m => `
              <tr>
                <td>${m.id}</td>
                <td>${m.message}</td>
                <td>${m.region}</td>
                <td>${m.created_at}</td>
              </tr>
            `).join('')
            : '<tr><td colspan="4">No data</td></tr>'
        }
      </table>
    </body>
  </html>
  `;

  res.send(html);
});

app.post('/add', async (req, res) => {

  try {

    await pool.query(
      'INSERT INTO messages (message, region) VALUES (?, ?)',
      ['Test Message', regionName]
    );

    res.redirect('/');

  } catch (err) {

    res.status(500).send(err.message);

  }
});

initDB().then(() => {

  app.listen(port, '0.0.0.0', () => {
    console.log(`Listening on port ${port}`);
  });

});
