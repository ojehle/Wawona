#!/usr/bin/env node

const express = require('express');
const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const app = express();
const PORT = process.env.PORT || 8080;
const DOCS_DIR = __dirname;

// Configure marked options
marked.setOptions({
    breaks: true,
    gfm: true,
    headerIds: true,
    mangle: false
});

// Serve static files (HTML, CSS, JS, etc.)
app.use(express.static(DOCS_DIR));

// API endpoint to get markdown as JSON
app.get('/api/markdown/:filename', (req, res) => {
    const filename = req.params.filename;
    const mdPath = path.join(DOCS_DIR, filename);
    
    if (!fs.existsSync(mdPath)) {
        return res.status(404).json({ error: 'File not found' });
    }
    
    try {
        const content = fs.readFileSync(mdPath, 'utf8');
        const html = marked.parse(content);
        res.json({ html, filename });
    } catch (error) {
        res.status(500).json({ error: 'Error processing markdown' });
    }
});

// Serve markdown files directly
app.get('/*.md', (req, res) => {
    const mdPath = path.join(DOCS_DIR, req.path);
    
    if (!fs.existsSync(mdPath)) {
        return res.status(404).send('File not found');
    }
    
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.sendFile(mdPath);
});

// Serve index.html for root
app.get('/', (req, res) => {
    res.sendFile(path.join(DOCS_DIR, 'index.html'));
});

// Start server
app.listen(PORT, () => {
    console.log('📚 CALayerWayland Documentation Server');
    console.log('======================================');
    console.log('');
    console.log(`Serving: ${DOCS_DIR}`);
    console.log(`Port: ${PORT}`);
    console.log('');
    console.log('Open in your browser:');
    console.log(`  http://localhost:${PORT}`);
    console.log('');
    console.log('Press Ctrl+C to stop');
    console.log('');
    
    // Try to open browser (macOS)
    if (process.platform === 'darwin') {
        setTimeout(() => {
            const { exec } = require('child_process');
            exec(`open http://localhost:${PORT}`);
        }, 500);
    }
});

