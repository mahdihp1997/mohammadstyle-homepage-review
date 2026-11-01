// Rebuild derivatives after editing the single canonical SVG. No private image input.
import fs from'node:fs';import path from'node:path';import sharp from'sharp';import{root}from'./local.mjs';
const site=path.resolve(root,'..'),svg=fs.readFileSync(path.join(site,'public/brand/mohammadstyle-mark.svg'),'utf8');
if(!svg.includes('viewBox="0 0 256 256"')||/<(?:image|script)\b|(?:https?:|data:)/i.test(svg.replace('http://www.w3.org/2000/svg','')))throw Error('Expected self-contained editable SVG geometry');
const inner=svg.replace(/^<svg[^>]*>/,'').replace(/<\/svg>\s*$/,'');const icon='<svg xmlns="http://www.w3.org/2000/svg" viewBox="-32 -32 320 320"><rect x="-32" y="-32" width="320" height="320" rx="80" fill="#0f0f10"/>'+inner+'</svg>\n';
fs.writeFileSync(path.join(site,'app/icon.svg'),icon);await sharp(Buffer.from(icon)).resize(180,180).png().toFile(path.join(site,'app/apple-icon.png'));console.log('Favicon/apple icon regenerated from the canonical SVG.');
