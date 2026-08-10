# LUAX SSG V0.3

**Static Site Generator built with Lua**

LUAX is a lightweight, fast, and modern **static site generator** built with [Lua](https://www.lua.org/). It uses the LAX template engine to generate static websites from Markdown content with YAML frontmatter.

Read Documentation on [https://luax.axcora.com](https://luax.axcora.com)


![SSG LUA](lua-ssg.jpg)

---

## Support & Donation

If you find LUAX helpful, consider supporting us:

[![PayPal](https://img.shields.io/badge/Donate-PayPal-00457C.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=JVZVXBC4N9DAN) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00.svg)](https://creativitaz.gumroad.com/coffee) [![GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub-181717.svg)](https://github.com/sponsors/mesinkasir)

Your support helps us maintain and improve LUAX! ❤️

---

## ✨ Features
+ ⚡ Fast - Built with Lua for speed
+ 📦 Lightweight - Minimal dependencies
+ 🔧 Easy - Simple template system with LAX
+ 📝 Markdown - Write content in Markdown with YAML frontmatter
+ 🏷️ Tags - Automatic tag pages
+ 📄 Pagination - Blog posts pagination
+ 📱 Responsive - Bootstrap ready
+ 🔍 SEO - Open Graph, JSON-LD, sitemap, RSS feed
+ 📂 Assets - Automatic public assets copying

## 📦 Installation

Prerequisites
+ Lua (version 5.3 or higher)
+ Python or PHP (for development server)

## Clone & Setup

```
git clone https://github.com/mesinkasir/luax.git
cd luax
```

## File Structure

```
luax/
├── build.lua          # Build engine
├── start.lua          # Development server
├── lax.lua            # LAX template engine
├── yaml.lua           # YAML parser
├── metadata.yaml      # Site configuration
├── luax.bat           # Windows command line
├── luax.sh            # Linux/Mac command line
├── src/
│   ├── posts/         # Blog posts (.md)
│   └── pages/         # Static pages (.md)
├── templates/
│   ├── layouts/       # Layout templates (.lax)
│   └── partials/      # Partial templates (.lax)
├── public/            # Static assets (css, img, js)
├── dist/              # Generated output
```

## 🚀 Usage

### Windows
```
luax build    # Build static site
luax start    # Start development server
open localhost:8080
```

### Linux / Mac
```
chmod +x luax.sh
./luax.sh build    # Build static site
./luax.sh start    # Start development server
```
### Development Server
After running luax start, open your browser to:
```
http://localhost:8080
```

## 🗂️ Site Configuration

Edit `metadata.yaml` to configure your site:

```
title: LUAX SSG
description: Static Site Generator built with Lua
url: http://localhost:8080
image: /img/logo.webp
favicon: /img/favicon.webp
```

## 📦 Building

Run command
```
luax build
```
The site will be generated in the `dist/` folder.

## 🛠️ Development Server

Run command
```
luax start
```

The server will start at `http://localhost:8080`

## Optional: Live Reload

For automatic browser refresh, install one of these:

Browser-Sync:
```
npm install -g browser-sync
browser-sync start --server dist --port 8080 --files dist/**/*
```

Python Livereload:
```
pip install livereload
livereload dist --port 8080
```

---

Read Docs: [https://luax.axcora.com](https://luax.axcora.com)

---

## Support & Donation

If you find LUAX helpful, consider supporting us:

[![PayPal](https://img.shields.io/badge/Donate-PayPal-00457C.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=JVZVXBC4N9DAN) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00.svg)](https://creativitaz.gumroad.com/coffee) [![GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub-181717.svg)](https://github.com/sponsors/mesinkasir)

Your support helps us maintain and improve LUAX! ❤️
