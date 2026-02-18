# Web Development Environment Template

This template provides a comprehensive development environment with:

- **Node.js 22** with npm and pnpm
- **Playwright** for browser testing (via playwright-web-flake)
- **Prisma** for database management
- **Common development tools**: jq, curl, wget, entr, watchexec, tree, netcat, sqlite, stripe-cli

## Usage

### For New Projects

```bash
# Create a new project directory
mkdir my-project
cd my-project

# Initialize with this template
nix flake init -t ~/nixos-config

# Allow direnv to load the environment
direnv allow

# The development environment will be automatically loaded!
```

### For Existing Projects

```bash
# Navigate to your project
cd /path/to/existing/project

# Initialize the template (adds flake.nix and .envrc)
nix flake init -t ~/nixos-config

# Allow direnv
direnv allow
```

## What Gets Created

- `flake.nix` - Nix flake definition with development environment
- `.envrc` - direnv configuration (`use flake`)
- `.gitignore` - Excludes `.direnv/` directory

## Customization

### Adding Packages

Edit `flake.nix` and add packages to the `packages` list:

```nix
packages = [
  pkgs.nodejs_22
  pkgs.your-package-here  # Add your packages
  # ...
];
```

### Changing Node.js Version

Replace `pkgs.nodejs_22` with your desired version:
- `pkgs.nodejs_20`
- `pkgs.nodejs_23`
- etc.

### Updating Playwright Version

The Playwright version is managed by the playwright-web-flake input. To use a specific version:

```nix
inputs = {
  # ...
  playwright.url = "github:pietdevries94/playwright-web-flake/1.37.1";
};
```

See available versions at: https://github.com/pietdevries94/playwright-web-flake/tags

### Adding Shell Hooks

Add custom commands to run when entering the shell:

```nix
shellHook = ''
  # Existing configuration...

  # Your custom commands
  echo "Welcome to my project!"
  npm install  # Auto-install dependencies
'';
```

## How It Works

1. **direnv** monitors your directory and detects `.envrc`
2. When you `cd` into the directory, direnv reads `.envrc`
3. `.envrc` contains `use flake`, which loads the Nix flake
4. **nix-direnv** caches the environment for fast loading
5. All packages and environment variables are automatically available

## Updating the Environment

After modifying `flake.nix`:

```bash
# Update flake.lock (if you changed input versions)
nix flake update

# Reload the environment
direnv reload
```

## Troubleshooting

### Environment not loading

```bash
# Re-allow direnv
direnv allow
```

### Playwright browsers not found

The browsers are pre-installed via Nix and located at `$PLAYWRIGHT_BROWSERS_PATH`. The environment variables are set automatically in the shellHook.

### Prisma engines not found

The Prisma engine binaries are explicitly set via environment variables in the shellHook. Make sure you're inside the project directory (direnv loaded).

## Without direnv

If you prefer not to use direnv:

```bash
# Manually enter the development shell
nix develop

# Or run a command in the environment
nix develop -c npm install
```
