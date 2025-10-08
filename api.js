const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Cache melhorado
const serverCache = new Map();
const CACHE_DURATION = 45 * 1000; // 45 segundos

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Roblox Hop API Online 🚀',
    version: '1.0.0',
    endpoints: {
      servers: '/servers/:placeId',
      health: '/health'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: Date.now(),
    cacheSize: serverCache.size
  });
});

async function fetchRobloxServers(placeId) {
  try {
    const servers = [];
    let cursor = '';
    const maxServers = 60;

    for (let page = 0; page < 3 && servers.length < maxServers; page++) {
      let url = `https://games.roblox.com/v1/games/${placeId}/servers/Public?sortOrder=Asc&limit=100`;
      
      if (cursor) {
        url += `&cursor=${cursor}`;
      }

      const response = await axios.get(url, {
        timeout: 10000,
        headers: {
          'User-Agent': 'Roblox-Hop-API/1.0.0'
        }
      });

      const data = response.data;

      if (!data.data || data.data.length === 0) break;

      for (const server of data.data) {
        if (servers.length >= maxServers) break;
        
        if (server.maxPlayers > server.playing && server.id) {
          servers.push({
            id: server.id,
            playing: server.playing,
            maxPlayers: server.maxPlayers,
            capacity: Math.floor((server.playing / server.maxPlayers) * 100)
          });
        }
      }

      cursor = data.nextPageCursor;
      if (!cursor) break;

      // Pequena pausa entre páginas
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    return servers;
  } catch (error) {
    console.error('Erro ao buscar servidores:', error.message);
    return [];
  }
}

// Rota principal de servidores
app.get('/servers/:placeId', async (req, res) => {
  const placeId = req.params.placeId;
  
  // Validação do placeId
  if (!placeId || !/^\d+$/.test(placeId)) {
    return res.status(400).json({
      success: false,
      error: 'Place ID inválido'
    });
  }

  const cacheKey = `place-${placeId}`;
  const cached = serverCache.get(cacheKey);

  // Retornar cache se válido
  if (cached && (Date.now() - cached.timestamp < CACHE_DURATION)) {
    return res.json({
      success: true,
      servers: cached.servers,
      cached: true,
      timestamp: Date.now(),
      total: cached.servers.length
    });
  }

  try {
    const servers = await fetchRobloxServers(placeId);
    
    // Atualizar cache
    serverCache.set(cacheKey, {
      servers: servers,
      timestamp: Date.now()
    });

    // Limpar cache antigo
    const now = Date.now();
    for (const [key, value] of serverCache.entries()) {
      if (now - value.timestamp > CACHE_DURATION * 2) {
        serverCache.delete(key);
      }
    }

    res.json({
      success: true,
      servers: servers,
      cached: false,
      timestamp: Date.now(),
      total: servers.length
    });

  } catch (error) {
    console.error('Erro na rota /servers:', error);
    
    // Tentar retornar cache mesmo expirado em caso de erro
    if (cached) {
      return res.json({
        success: true,
        servers: cached.servers,
        cached: true,
        expired: true,
        timestamp: Date.now(),
        total: cached.servers.length
      });
    }

    res.status(500).json({
      success: false,
      error: 'Erro interno do servidor'
    });
  }
});

// Rota de status do cache
app.get('/cache/status', (req, res) => {
  const cacheInfo = [];
  const now = Date.now();
  
  serverCache.forEach((value, key) => {
    const age = Math.floor((now - value.timestamp) / 1000);
    cacheInfo.push({
      key: key,
      servers: value.servers.length,
      ageSeconds: age,
      expired: age > (CACHE_DURATION / 1000)
    });
  });

  res.json({
    cacheSize: serverCache.size,
    cacheEntries: cacheInfo
  });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 API rodando na porta ${PORT}`);
  console.log(`📊 Endpoint: http://0.0.0.0:${PORT}`);
});