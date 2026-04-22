const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const API_URL = process.env.API_URL || 'http://localhost:8000';
const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || 5000);
const apiClient = axios.create({
  baseURL: API_URL,
  timeout: REQUEST_TIMEOUT_MS,
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'views')));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.post('/submit', async (req, res) => {
  try {
    const response = await apiClient.post('/jobs');
    res.status(response.status).json(response.data);
  } catch (err) {
    if (err.response) {
      return res.status(err.response.status).json(err.response.data);
    }
    res.status(500).json({ error: 'something went wrong' });
  }
});

app.get('/status/:id', async (req, res) => {
  try {
    const response = await apiClient.get(`/jobs/${req.params.id}`);
    res.status(response.status).json(response.data);
  } catch (err) {
    if (err.response) {
      return res.status(err.response.status).json(err.response.data);
    }
    res.status(500).json({ error: 'something went wrong' });
  }
});

app.listen(PORT, HOST, () => {
  console.log(`Frontend running on ${HOST}:${PORT}`);
});
