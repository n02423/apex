# Git Repository Browser

A local web application that dynamically displays Git repository file structures in a clean, collapsible tree view interface. Built with pure HTML, CSS, and JavaScript with a Node.js scanner for generating repository structure data.

## Features

- **Interactive Tree View**: Browse repository structure with expandable/collapsible folders
- **File Type Icons**: Visual indicators for different file types (JavaScript, Python, HTML, CSS, etc.)
- **Real-time Search**: Filter files and folders with highlighting and auto-expansion
- **File Details Panel**: View file metadata including path, size, and modification dates
- **Responsive Design**: Works on desktop and mobile devices
- **Modern UI**: Clean, minimalist interface with smooth animations
- **Fast Performance**: Efficient rendering even for large repositories

## Quick Start

### Prerequisites

- **Node.js** (version 12 or higher) - required for the repository scanner
- **Modern web browser** (Chrome, Firefox, Safari, Edge) - for viewing the interface

### Setup Instructions

1. **Clone or download this repository**:
   ```bash
   git clone <repository-url>
   cd git-repo-browser
   ```

2. **Scan your repository**:
   ```bash
   # Scan current directory
   node repo-scan.js

   # Or scan a specific directory
   node repo-scan.js /path/to/your/repository
   ```

3. **Open the website**:
   - Simply double-click `index.html` in your file explorer
   - Or open it in your browser: `file:///path/to/git-repo-browser/index.html`

That's it! Your repository structure will be displayed in an interactive tree view.

## Usage

### Repository Scanner

The `repo-scan.js` script generates a JSON file containing your repository structure:

```bash
# Basic usage
node repo-scan.js

# Scan specific directory
node repo-scan.js ./my-project

# Show help
node repo-scan.js --help

# Show version
node repo-scan.js --version
```

**What the scanner does:**
- Recursively scans all directories and files
- Ignores common build/cache directories (`.git`, `node_modules`, `dist`, etc.)
- Collects file metadata (size, type, modification dates)
- Generates `repo-structure.json` in the repository root

### Web Interface

**Tree Navigation:**
- Click folders to expand/collapse them
- Click files to view details in the right panel
- Use the search bar to filter files and folders

**Search Features:**
- Real-time filtering as you type
- Highlights matching files and auto-expands parent folders
- Shows search result count
- Click × to clear search or press Escape

**File Details:**
- Click any file to see:
  - File name and path
  - File type and extension
  - File size (human-readable format)
  - Last modification date

## File Structure

```
git-repo-browser/
├── index.html          # Main webpage interface
├── style.css           # Complete styling for the interface
├── script.js           # Core JavaScript functionality
├── repo-scan.js        # Node.js repository scanner
├── repo-structure.json # Generated repository data
├── package.json        # Node.js project configuration
├── README.md           # This file
└── .gitignore          # Ignore patterns for generated files
```

## Supported File Types

The browser recognizes and shows appropriate icons for:

- **Code**: JavaScript, TypeScript, Python, Java, C/C++, Go, Rust, PHP, Ruby, Swift, etc.
- **Web**: HTML, CSS, SCSS, JavaScript, JSON, XML
- **Documentation**: Markdown, TXT, PDF, DOC, etc.
- **Media**: PNG, JPG, GIF, SVG, MP4, MP3, etc.
- **Configuration**: YAML, TOML, INI, Dockerfile, Makefile
- **Version Control**: .gitignore, .gitattributes, etc.

## Scanner Configuration

The scanner automatically ignores these directories:
- `.git/`, `node_modules/`, `.cache/`, `dist/`, `build/`
- `coverage/`, `.pytest_cache/`, `__pycache__/`, `.mypy_cache/`
- `.idea/`, `.vscode/`, `.venv/`, `venv/`, `env/`

And these file patterns:
- `.DS_Store`, `Thumbs.db`, `*.log`, `*.tmp`, `*.swp`

You can modify these patterns in `repo-scan.js` if needed.

## Data Structure

The generated `repo-structure.json` follows this format:

```json
{
  "name": "repository-name",
  "path": "/absolute/path/to/repository",
  "scanned_at": "2025-01-03T10:30:00Z",
  "total_files": 42,
  "total_size": 1024000,
  "structure": [
    {
      "name": "src",
      "type": "directory",
      "path": "src",
      "size": 4096,
      "children": [
        {
          "name": "index.js",
          "type": "file",
          "path": "src/index.js",
          "size": 2048,
          "extension": "js",
          "modified": "2025-01-03T10:00:00Z"
        }
      ]
    }
  ]
}
```

## Browser Compatibility

- **Chrome 70+** ✅
- **Firefox 65+** ✅
- **Safari 12+** ✅
- **Edge 79+** ✅

## Performance

- Handles repositories with thousands of files efficiently
- Lazy rendering prevents UI freezing
- Optimized search with debouncing
- Smooth animations and transitions

## Troubleshooting

### "Could not load repository structure file"
**Solution**: Run the scanner first:
```bash
node repo-scan.js
```

### "Permission denied" errors
**Solution**: Check file permissions or run with appropriate privileges:
```bash
# On Unix systems
chmod +x repo-scan.js
```

### Scanner is very slow
**Solution**: The scanner processes large repositories efficiently, but you can:
- Exclude additional directories in the scanner configuration
- Run on SSD storage for better performance

### Search not working
**Solution**: Ensure JavaScript is enabled in your browser and try refreshing the page.

## Development

### Modifying the Scanner
Edit `repo-scan.js` to:
- Change ignored directories/files
- Modify data structure format
- Add new file metadata collection

### Customizing the Interface
Edit `style.css` and `script.js` to:
- Change colors and styling
- Add new file type icons
- Modify search behavior
- Add new features

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE).

## Examples

### Viewing a Large Project
```bash
# Clone a large repository
git clone https://github.com/facebook/react.git
cd react

# Scan it
node /path/to/git-repo-browser/repo-scan.js .

# Open the browser
open /path/to/git-repo-browser/index.html
```

### Multiple Repositories
You can reuse the scanner for multiple repositories:
```bash
# Scan different repositories
node repo-scan.js ~/project-1
node repo-scan.js ~/project-2
node repo-scan.js ~/project-3

# Each generates its own repo-structure.json
# Open index.html in each directory to browse
```

## Support

If you encounter issues or have questions:
1. Check this README for common solutions
2. Ensure you're using Node.js 12 or higher
3. Verify your browser supports modern JavaScript
4. Check file permissions if scanner fails

---

**Happy browsing!** 🎉