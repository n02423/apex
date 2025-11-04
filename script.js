// Global variables
let repositoryData = null;
let selectedFile = null;
let searchTerm = '';

// File type icons mapping
const fileIcons = {
    // JavaScript/TypeScript
    'js': '📄',
    'jsx': '⚛️',
    'ts': '📘',
    'tsx': '⚛️',
    'mjs': '📄',
    // Python
    'py': '🐍',
    'pyw': '🐍',
    'pyc': '🐍',
    'pyo': '🐍',
    // Web
    'html': '🌐',
    'htm': '🌐',
    'css': '🎨',
    'scss': '🎨',
    'sass': '🎨',
    'less': '🎨',
    // Data/Config
    'json': '📋',
    'xml': '📋',
    'yaml': '📋',
    'yml': '📋',
    'toml': '📋',
    'ini': '⚙️',
    'conf': '⚙️',
    // Documentation
    'md': '📝',
    'txt': '📄',
    'rst': '📝',
    'pdf': '📕',
    'doc': '📘',
    'docx': '📘',
    // Images
    'png': '🖼️',
    'jpg': '🖼️',
    'jpeg': '🖼️',
    'gif': '🖼️',
    'svg': '🎨',
    'ico': '🖼️',
    // Video/Audio
    'mp4': '🎬',
    'avi': '🎬',
    'mov': '🎬',
    'mp3': '🎵',
    'wav': '🎵',
    'flac': '🎵',
    // Code
    'c': '⚙️',
    'cpp': '⚙️',
    'cc': '⚙️',
    'h': '⚙️',
    'hpp': '⚙️',
    'java': '☕',
    'go': '🐹',
    'rs': '🦀',
    'php': '🐘',
    'rb': '💎',
    'swift': '🍎',
    'kt': '🎯',
    'scala': '🔷',
    'sh': '🐚',
    'bash': '🐚',
    'zsh': '🐚',
    'fish': '🐚',
    'ps1': '💙',
    'bat': '⚡',
    'cmd': '⚡',
    // Build/Package
    'dockerfile': '🐳',
    'makefile': '🔧',
    'cmake': '🔧',
    'gradle': '🐘',
    'pom': '🐘',
    'gemfile': '💎',
    'requirements': '🐍',
    'package': '📦',
    'yarn': '📦',
    'lock': '🔒',
    // Git
    'gitignore': '🚫',
    'gitattributes': '🚫',
    'gitmodules': '🚫',
    'gitkeep': '📂',
    // Default
    'default': '📄'
};

// Initialize the application
document.addEventListener('DOMContentLoaded', async () => {
    try {
        await loadRepositoryData();
        setupEventListeners();
        renderFileTree();
        updateRepositoryInfo();
    } catch (error) {
        showError(error.message);
    }
});

// Load repository data from JSON file
async function loadRepositoryData() {
    try {
        const response = await fetch('repo-structure.json');
        if (!response.ok) {
            throw new Error('Could not load repository structure file. Make sure repo-structure.json exists.');
        }
        repositoryData = await response.json();
    } catch (error) {
        if (error instanceof TypeError && error.message.includes('Failed to fetch')) {
            throw new Error('Could not find repo-structure.json file. Please run the repository scanner first.');
        }
        throw error;
    }
}

// Setup event listeners
function setupEventListeners() {
    const searchInput = document.getElementById('search-input');
    const clearSearchBtn = document.getElementById('clear-search');

    searchInput.addEventListener('input', handleSearch);
    clearSearchBtn.addEventListener('click', clearSearch);

    // Clear search on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && searchTerm) {
            clearSearch();
        }
    });
}

// Render the file tree
function renderFileTree() {
    const fileTreeElement = document.getElementById('file-tree');

    if (!repositoryData || !repositoryData.structure) {
        fileTreeElement.innerHTML = '<div class="loading">No repository structure data available</div>';
        return;
    }

    fileTreeElement.innerHTML = '';

    repositoryData.structure.forEach(item => {
        const treeItem = createTreeItem(item, 0);
        fileTreeElement.appendChild(treeItem);
    });
}

// Create a tree item element
function createTreeItem(item, depth) {
    const itemElement = document.createElement('div');
    itemElement.className = 'tree-item';
    itemElement.dataset.name = item.name.toLowerCase();
    itemElement.dataset.path = item.path.toLowerCase();
    itemElement.dataset.type = item.type;

    // Create toggle for directories
    if (item.type === 'directory') {
        const toggle = document.createElement('span');
        toggle.className = 'tree-toggle';
        toggle.innerHTML = '▼';
        if (!item.children || item.children.length === 0) {
            toggle.classList.add('no-children');
        }
        itemElement.appendChild(toggle);

        toggle.addEventListener('click', (e) => {
            e.stopPropagation();
            toggleDirectory(itemElement, toggle);
        });
    }

    // Create icon
    const icon = document.createElement('span');
    icon.className = 'tree-icon';
    icon.innerHTML = getFileIcon(item);
    itemElement.appendChild(icon);

    // Create name
    const name = document.createElement('span');
    name.className = 'tree-name';
    name.textContent = item.name;
    itemElement.appendChild(name);

    // Create size display for files
    if (item.type === 'file' && item.size) {
        const size = document.createElement('span');
        size.className = 'tree-size';
        size.textContent = formatFileSize(item.size);
        itemElement.appendChild(size);
    }

    // Add click handler
    itemElement.addEventListener('click', () => {
        if (item.type === 'file') {
            selectFile(item, itemElement);
        } else if (item.type === 'directory') {
            const toggle = itemElement.querySelector('.tree-toggle');
            if (toggle && !toggle.classList.contains('no-children')) {
                toggleDirectory(itemElement, toggle);
            }
        }
    });

    // Add children container for directories
    if (item.type === 'directory' && item.children && item.children.length > 0) {
        const childrenContainer = document.createElement('div');
        childrenContainer.className = 'tree-children';

        item.children.forEach(child => {
            const childElement = createTreeItem(child, depth + 1);
            childElement.style.marginLeft = '20px';
            childrenContainer.appendChild(childElement);
        });

        itemElement.appendChild(childrenContainer);
    }

    return itemElement;
}

// Toggle directory expansion/collapse
function toggleDirectory(itemElement, toggle) {
    const childrenContainer = itemElement.querySelector('.tree-children');
    if (!childrenContainer) return;

    if (childrenContainer.classList.contains('collapsed')) {
        childrenContainer.classList.remove('collapsed');
        toggle.classList.remove('collapsed');
        toggle.innerHTML = '▼';
    } else {
        childrenContainer.classList.add('collapsed');
        toggle.classList.add('collapsed');
        toggle.innerHTML = '▶';
    }
}

// Get file icon based on file type
function getFileIcon(item) {
    if (item.type === 'directory') {
        return '📁';
    }

    const extension = item.extension ? item.extension.toLowerCase() : '';
    const fileName = item.name.toLowerCase();

    // Special cases for specific filenames
    if (fileName === 'dockerfile') return '🐳';
    if (fileName === 'makefile') return '🔧';
    if (fileName === 'gitignore') return '🚫';
    if (fileName === 'readme.md') return '📖';
    if (fileName === 'license') return '📜';
    if (fileName === 'package.json') return '📦';
    if (fileName.includes('requirements')) return '🐍';

    // Return icon based on extension
    return fileIcons[extension] || fileIcons.default;
}

// Select a file and show its details
function selectFile(file, element) {
    // Remove previous selection
    document.querySelectorAll('.tree-item.selected').forEach(el => {
        el.classList.remove('selected');
    });

    // Add selection to current element
    element.classList.add('selected');

    selectedFile = file;
    showFileDetails(file);
}

// Show file details in the details panel
function showFileDetails(file) {
    const detailsElement = document.getElementById('file-details');

    const detailsHTML = `
        <div class="detail-row">
            <span class="detail-label">Name:</span>
            <span class="detail-value">${file.name}</span>
        </div>
        <div class="detail-row">
            <span class="detail-label">Path:</span>
            <span class="detail-value">${file.path}</span>
        </div>
        <div class="detail-row">
            <span class="detail-label">Type:</span>
            <span class="detail-value">${file.type}</span>
        </div>
        ${file.extension ? `
        <div class="detail-row">
            <span class="detail-label">Extension:</span>
            <span class="detail-value">${file.extension}</span>
        </div>
        ` : ''}
        ${file.size ? `
        <div class="detail-row">
            <span class="detail-label">Size:</span>
            <span class="detail-value">${formatFileSize(file.size)}</span>
        </div>
        ` : ''}
        ${file.modified ? `
        <div class="detail-row">
            <span class="detail-label">Modified:</span>
            <span class="detail-value">${new Date(file.modified).toLocaleString()}</span>
        </div>
        ` : ''}
    `;

    detailsElement.innerHTML = detailsHTML;
}

// Handle search functionality
function handleSearch(e) {
    searchTerm = e.target.value.toLowerCase();
    const clearBtn = document.getElementById('clear-search');
    const searchCount = document.getElementById('search-count');

    if (searchTerm) {
        clearBtn.style.display = 'block';
        filterTree();
        updateSearchCount();
    } else {
        clearSearch();
    }
}

// Clear search
function clearSearch() {
    searchTerm = '';
    document.getElementById('search-input').value = '';
    document.getElementById('clear-search').style.display = 'none';
    document.getElementById('search-count').textContent = '';

    // Remove all search-related classes
    document.querySelectorAll('.tree-item.hidden, .tree-item.highlight').forEach(el => {
        el.classList.remove('hidden', 'highlight');
    });

    // Collapse all directories that were auto-expanded
    document.querySelectorAll('.tree-children').forEach(el => {
        el.classList.remove('collapsed');
    });
    document.querySelectorAll('.tree-toggle').forEach(el => {
        el.classList.remove('collapsed');
        el.innerHTML = '▼';
    });
}

// Filter tree based on search term
function filterTree() {
    const allItems = document.querySelectorAll('.tree-item');
    let hasResults = false;

    allItems.forEach(item => {
        const name = item.dataset.name;
        const path = item.dataset.path;
        const matches = name.includes(searchTerm) || path.includes(searchTerm);

        if (matches) {
            item.classList.remove('hidden');
            item.classList.add('highlight');
            hasResults = true;

            // Auto-expand parent directories
            expandParentDirectories(item);

            // Scroll to first match
            if (!document.querySelector('.tree-item.highlight:first-of-type')) {
                item.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        } else {
            item.classList.add('hidden');
            item.classList.remove('highlight');
        }
    });

    if (!hasResults && searchTerm) {
        document.getElementById('search-count').textContent = 'No results';
    }
}

// Expand parent directories to show search results
function expandParentDirectories(item) {
    let parent = item.parentElement;
    while (parent && parent.classList.contains('tree-children')) {
        parent.classList.remove('collapsed');
        const parentItem = parent.parentElement;
        if (parentItem && parentItem.classList.contains('tree-item')) {
            const toggle = parentItem.querySelector('.tree-toggle');
            if (toggle) {
                toggle.classList.remove('collapsed');
                toggle.innerHTML = '▼';
            }
        }
        parent = parentItem ? parentItem.parentElement : null;
    }
}

// Update search count
function updateSearchCount() {
    const visibleItems = document.querySelectorAll('.tree-item:not(.hidden)');
    const totalItems = document.querySelectorAll('.tree-item');
    const fileItems = Array.from(visibleItems).filter(item =>
        item.dataset.type === 'file'
    );

    let countText = '';
    if (searchTerm) {
        const fileCount = fileItems.length;
        const dirCount = Array.from(visibleItems).filter(item =>
            item.dataset.type === 'directory'
        ).length;

        if (fileCount === 1) {
            countText = '1 file';
        } else if (fileCount > 0) {
            countText = `${fileCount} files`;
        }

        if (dirCount > 0) {
            countText += fileCount > 0 ? `, ${dirCount} folders` : `${dirCount} folders`;
        }
    }

    document.getElementById('search-count').textContent = countText;
}

// Update repository information in header
function updateRepositoryInfo() {
    if (!repositoryData) return;

    document.getElementById('repo-name').textContent = repositoryData.name || 'Unknown Repository';

    if (repositoryData.scanned_at) {
        const scanDate = new Date(repositoryData.scanned_at).toLocaleString();
        document.getElementById('scan-time').textContent = `Scanned: ${scanDate}`;
    }

    // Update tree stats
    const totalFiles = repositoryData.total_files || countFiles(repositoryData.structure);
    const totalSize = repositoryData.total_size || calculateTotalSize(repositoryData.structure);

    document.getElementById('total-files').textContent = `${totalFiles} files`;
    document.getElementById('total-size').textContent = formatFileSize(totalSize);
}

// Count total files recursively
function countFiles(structure) {
    let count = 0;
    structure.forEach(item => {
        if (item.type === 'file') {
            count++;
        } else if (item.children) {
            count += countFiles(item.children);
        }
    });
    return count;
}

// Calculate total size recursively
function calculateTotalSize(structure) {
    let size = 0;
    structure.forEach(item => {
        if (item.type === 'file' && item.size) {
            size += item.size;
        } else if (item.children) {
            size += calculateTotalSize(item.children);
        }
    });
    return size;
}

// Format file size
function formatFileSize(bytes) {
    if (!bytes) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
        size /= 1024;
        unitIndex++;
    }

    return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}

// Show error message
function showError(message) {
    const errorElement = document.getElementById('error-message');
    const errorText = document.getElementById('error-text');

    errorText.textContent = message;
    errorElement.style.display = 'flex';

    // Hide loading state
    const fileTree = document.getElementById('file-tree');
    if (fileTree) {
        fileTree.innerHTML = '';
    }
}

// Utility function to escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}