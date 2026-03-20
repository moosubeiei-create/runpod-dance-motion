const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 8080;

const MIME_TYPES = {
  '.html': 'text/html',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
};

function proxyToRunPod(req, res) {
  let body = '';
  req.on('data', chunk => { body += chunk; });
  req.on('end', () => {
    const parsed = url.parse(req.url, true);
    const targetPath = parsed.pathname.replace('/api/runpod', '');
    const targetUrl = `https://api.runpod.ai/v2${targetPath}`;

    const options = url.parse(targetUrl);
    options.method = req.method;
    options.headers = {
      'Authorization': req.headers['authorization'] || '',
      'Content-Type': 'application/json',
    };

    const proxyReq = https.request(options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': proxyRes.headers['content-type'] || 'application/json',
        'Access-Control-Allow-Origin': '*',
      });
      proxyRes.pipe(res);
    });

    proxyReq.on('error', (err) => {
      console.error('Proxy error:', err.message);
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: `Proxy error: ${err.message}` }));
    });

    if (body) proxyReq.write(body);
    proxyReq.end();
  });
}

function serveStatic(req, res) {
  let filePath = path.join(__dirname, req.url === '/' ? 'dance-motion-ui.html' : req.url);
  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404);
        res.end('Not Found');
      } else {
        res.writeHead(500);
        res.end('Server Error');
      }
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  if (req.url.startsWith('/api/runpod/')) {
    proxyToRunPod(req, res);
  } else {
    serveStatic(req, res);
  }
});

server.maxHeaderSize = 16 * 1024;
server.timeout = 600000; // 10 min for long video uploads

server.listen(PORT, () => {
  console.log(`\n  Server running at http://localhost:${PORT}`);
  console.log(`  UI:    http://localhost:${PORT}/`);
  console.log(`  Proxy: http://localhost:${PORT}/api/runpod/...\n`);
});
