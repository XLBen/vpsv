import { defineConfig, type Plugin } from 'vite';
import fs from 'node:fs';
import path from 'node:path';

const ASSETS = path.resolve(__dirname, '../assets');

/** 把 ../assets 挂在 /__assets 下，预览页可以对照查看导出结果。 */
function serveAssets(): Plugin {
  return {
    name: 'serve-exported-assets',
    configureServer(server) {
      server.middlewares.use('/__assets', (req, res, next) => {
        const file = path.join(ASSETS, decodeURIComponent((req.url || '/').split('?')[0]));
        if (!file.startsWith(ASSETS) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return next();
        const ext = path.extname(file);
        res.setHeader('Content-Type', { '.png': 'image/png', '.json': 'application/json', '.wav': 'audio/wav' }[ext] || 'application/octet-stream');
        res.setHeader('Cache-Control', 'no-store');
        fs.createReadStream(file).pipe(res);
      });
    },
  };
}

export default defineConfig({
  plugins: [serveAssets()],
  build: { rollupOptions: { input: { preview: 'index.html', render: 'render.html' } } },
});
