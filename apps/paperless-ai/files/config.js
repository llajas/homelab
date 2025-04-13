require('dotenv').config();

module.exports = {
  paperless: {
    apiUrl: process.env.PAPERLESS_API_URL,
    apiToken: process.env.PAPERLESS_API_TOKEN
  },
  openai: {
    apiKey: process.env.OPENAI_API_KEY
  },
  ollama: {
    apiUrl: process.env.OLLAMA_API_URL || 'http://localhost:11434',
    model: process.env.OLLAMA_MODEL || 'llama2'
  },
  aiProvider: process.env.AI_PROVIDER || 'openai',
  scanInterval: process.env.SCAN_INTERVAL || '*/30 * * * *'
};
