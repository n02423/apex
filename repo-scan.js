#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Repository Scanner
 * Scans a local git repository and generates a JSON structure file
 */

class RepositoryScanner {
    constructor(repoPath = '.') {
        this.repoPath = path.resolve(repoPath);
        this.ignoredDirectories = [
            '.git',
            'node_modules',
            '.node_modules',
            '.npm',
            '.cache',
            'dist',
            'build',
            'coverage',
            '.coverage',
            '.nyc_output',
            '.pytest_cache',
            '__pycache__',
            '.mypy_cache',
            '.tox',
            '.venv',
            'venv',
            'env',
            '.env',
            '.idea',
            '.vscode',
            '*.egg-info'
        ];
        this.ignoredFiles = [
            '.DS_Store',
            'Thumbs.db',
            '*.log',
            '*.tmp',
            '*.swp',
            '*.swo',
            '*~',
            '.gitkeep',
            '.gitignore',
            '.gitattributes',
            '.gitmodules'
        ];
        this.stats = {
            totalFiles: 0,
            totalSize: 0,
            scannedDirs: 0,
            errors: []
        };
    }

    /**
     * Scan the repository and generate structure
     */
    async scan() {
        console.log(`Scanning repository: ${this.repoPath}`);

        try {
            // Check if path exists
            if (!fs.existsSync(this.repoPath)) {
                throw new Error(`Repository path does not exist: ${this.repoPath}`);
            }

            // Check if it's a directory
            const stats = fs.statSync(this.repoPath);
            if (!stats.isDirectory()) {
                throw new Error(`Path is not a directory: ${this.repoPath}`);
            }

            // Get repository name
            const repoName = path.basename(this.repoPath);

            // Scan directory structure
            const structure = await this.scanDirectory(this.repoPath, '');

            // Calculate total size
            const totalSize = this.calculateTotalSize(structure);

            // Create output data
            const output = {
                name: repoName,
                path: this.repoPath,
                scanned_at: new Date().toISOString(),
                total_files: this.stats.totalFiles,
                total_size: totalSize,
                stats: {
                    scanned_directories: this.stats.scannedDirs,
                    errors: this.stats.errors.length
                },
                structure: structure
            };

            // Write to file
            const outputPath = path.join(this.repoPath, 'repo-structure.json');
            fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));

            console.log(`✅ Scan completed successfully!`);
            console.log(`📊 Statistics:`);
            console.log(`   - Total files: ${this.stats.totalFiles}`);
            console.log(`   - Total size: ${this.formatFileSize(totalSize)}`);
            console.log(`   - Directories scanned: ${this.stats.scannedDirs}`);
            console.log(`   - Errors encountered: ${this.stats.errors.length}`);
            console.log(`📁 Output saved to: ${outputPath}`);

            if (this.stats.errors.length > 0) {
                console.log(`\n⚠️  Errors encountered:`);
                this.stats.errors.forEach(error => {
                    console.log(`   - ${error}`);
                });
            }

            return output;

        } catch (error) {
            console.error(`❌ Scan failed: ${error.message}`);
            process.exit(1);
        }
    }

    /**
     * Scan a directory recursively
     */
    async scanDirectory(dirPath, relativePath) {
        const structure = [];

        try {
            const items = fs.readdirSync(dirPath);
            this.stats.scannedDirs++;

            // Sort items: directories first, then files, both alphabetically
            const sortedItems = items.sort((a, b) => {
                const aStats = fs.statSync(path.join(dirPath, a));
                const bStats = fs.statSync(path.join(dirPath, b));

                // Directories come first
                if (aStats.isDirectory() && !bStats.isDirectory()) return -1;
                if (!aStats.isDirectory() && bStats.isDirectory()) return 1;

                // Then alphabetical
                return a.toLowerCase().localeCompare(b.toLowerCase());
            });

            for (const item of sortedItems) {
                const itemPath = path.join(dirPath, item);
                const itemRelativePath = relativePath ? path.join(relativePath, item) : item;

                try {
                    const itemStats = fs.lstatSync(itemPath);

                    if (itemStats.isDirectory()) {
                        // Check if directory should be ignored
                        if (this.shouldIgnoreDirectory(item)) {
                            continue;
                        }

                        // Recursively scan directory
                        const children = await this.scanDirectory(itemPath, itemRelativePath);
                        const dirSize = this.calculateTotalSize(children);

                        structure.push({
                            name: item,
                            type: 'directory',
                            path: itemRelativePath,
                            size: dirSize,
                            children: children,
                            child_count: children.length
                        });

                    } else if (itemStats.isFile()) {
                        // Check if file should be ignored
                        if (this.shouldIgnoreFile(item)) {
                            continue;
                        }

                        // Get file extension
                        const extension = path.extname(item).slice(1);
                        const fileName = path.basename(item, extension);

                        structure.push({
                            name: item,
                            type: 'file',
                            path: itemRelativePath,
                            size: itemStats.size,
                            extension: extension || undefined,
                            modified: itemStats.mtime.toISOString(),
                            created: itemStats.birthtime.toISOString()
                        });

                        this.stats.totalFiles++;
                        this.stats.totalSize += itemStats.size;
                    } else if (itemStats.isSymbolicLink()) {
                        // Handle symbolic links
                        const linkTarget = fs.readlinkSync(itemPath);

                        structure.push({
                            name: item,
                            type: 'symlink',
                            path: itemRelativePath,
                            target: linkTarget,
                            modified: itemStats.mtime.toISOString()
                        });
                    }

                } catch (error) {
                    // Log error but continue with other items
                    const errorMessage = `Failed to process ${itemRelativePath}: ${error.message}`;
                    this.stats.errors.push(errorMessage);
                    continue;
                }
            }

        } catch (error) {
            const errorMessage = `Failed to read directory ${relativePath}: ${error.message}`;
            this.stats.errors.push(errorMessage);
            console.warn(`⚠️  ${errorMessage}`);
        }

        return structure;
    }

    /**
     * Check if directory should be ignored
     */
    shouldIgnoreDirectory(dirName) {
        return this.ignoredDirectories.some(pattern => {
            // Simple glob-like matching
            if (pattern.includes('*')) {
                const regex = new RegExp(pattern.replace(/\*/g, '.*'), 'i');
                return regex.test(dirName);
            }
            return dirName === pattern || dirName.startsWith(pattern);
        });
    }

    /**
     * Check if file should be ignored
     */
    shouldIgnoreFile(fileName) {
        return this.ignoredFiles.some(pattern => {
            if (pattern.includes('*')) {
                const regex = new RegExp(pattern.replace(/\*/g, '.*'), 'i');
                return regex.test(fileName);
            }
            return fileName === pattern;
        });
    }

    /**
     * Calculate total size of structure recursively
     */
    calculateTotalSize(structure) {
        let totalSize = 0;

        structure.forEach(item => {
            if (item.type === 'file') {
                totalSize += item.size || 0;
            } else if (item.type === 'directory' && item.children) {
                totalSize += this.calculateTotalSize(item.children);
            }
        });

        return totalSize;
    }

    /**
     * Format file size in human readable format
     */
    formatFileSize(bytes) {
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
}

// CLI interface
function main() {
    const args = process.argv.slice(2);
    const repoPath = args[0] || '.';

    // Show help
    if (args.includes('--help') || args.includes('-h')) {
        console.log(`
Repository Scanner

Usage: node repo-scan.js [repository-path]

Arguments:
  repository-path    Path to the repository to scan (default: current directory)

Options:
  --help, -h        Show this help message

Examples:
  node repo-scan.js                    # Scan current directory
  node repo-scan.js ./my-project       # Scan specific directory
  node repo-scan.js /path/to/repo      # Scan repository at path

The scanner will:
  - Recursively scan all directories and files
  - Ignore common build/cache directories (.git, node_modules, etc.)
  - Generate repo-structure.json in the repository root
  - Show file sizes, types, and modification dates
        `);
        process.exit(0);
    }

    // Show version
    if (args.includes('--version') || args.includes('-v')) {
        const packagePath = path.join(__dirname, 'package.json');
        if (fs.existsSync(packagePath)) {
            const packageInfo = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
            console.log(`Repository Scanner v${packageInfo.version}`);
        } else {
            console.log('Repository Scanner v1.0.0');
        }
        process.exit(0);
    }

    // Run scanner
    const scanner = new RepositoryScanner(repoPath);
    scanner.scan().catch(error => {
        console.error(`❌ Fatal error: ${error.message}`);
        process.exit(1);
    });
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = RepositoryScanner;