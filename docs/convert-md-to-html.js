#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const marked = require('marked');

const DOCS_DIR = __dirname;

// Get all markdown files (including README.md)
const mdFiles = fs.readdirSync(DOCS_DIR)
    .filter(file => file.endsWith('.md'));

console.log('Converting markdown files to HTML...\n');

mdFiles.forEach(mdFile => {
    const mdPath = path.join(DOCS_DIR, mdFile);
    const htmlFile = mdFile.replace('.md', '.html');
    const htmlPath = path.join(DOCS_DIR, htmlFile);
    
    try {
        const content = fs.readFileSync(mdPath, 'utf8');
        const html = marked.parse(content);
        
        // Wrap in basic HTML structure
        const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${mdFile.replace('.md', '')} - CALayerWayland</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
            color: #333;
            background: #f5f5f7;
        }
        .document {
            background: white;
            padding: 3rem;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        h1 { font-size: 2.5rem; margin-bottom: 1rem; border-bottom: 3px solid #007aff; padding-bottom: 0.5rem; }
        h2 { font-size: 2rem; margin-top: 2.5rem; margin-bottom: 1rem; border-bottom: 2px solid #e5e5e7; padding-bottom: 0.5rem; }
        h3 { font-size: 1.5rem; margin-top: 2rem; margin-bottom: 0.75rem; }
        code { background: #f5f5f7; padding: 0.2em 0.4em; border-radius: 4px; font-family: 'SF Mono', Monaco, monospace; }
        pre { background: #1d1d1f; color: #f5f5f7; padding: 1.5rem; border-radius: 8px; overflow-x: auto; }
        pre code { background: transparent; padding: 0; }
        a { color: #007aff; }
        blockquote { border-left: 4px solid #007aff; padding-left: 1.5rem; margin: 1.5rem 0; }
        table { width: 100%; border-collapse: collapse; margin: 1.5rem 0; }
        th, td { padding: 0.75rem; border-bottom: 1px solid #e5e5e7; }
        th { background: #f5f5f7; font-weight: 600; }
    </style>
</head>
<body>
    <div class="document">
${html}
    </div>
</body>
</html>`;
        
        fs.writeFileSync(htmlPath, fullHtml);
        console.log(`✓ Converted ${mdFile} → ${htmlFile}`);
    } catch (error) {
        console.error(`✗ Error converting ${mdFile}:`, error.message);
    }
});

console.log('\nDone!');

