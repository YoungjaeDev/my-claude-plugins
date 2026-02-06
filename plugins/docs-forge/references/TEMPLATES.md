# README Templates

Copy-paste templates for different project types.

---

## Template 1: CLI Tool

```markdown
<div align="center">

# tool-name

One-line description of what this CLI tool does.

[![npm version](https://img.shields.io/npm/v/tool-name.svg)](https://www.npmjs.com/package/tool-name)
[![Build Status](https://img.shields.io/github/actions/workflow/status/user/tool-name/ci.yml)](https://github.com/user/tool-name/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Documentation](link) | [Examples](link) | [Contributing](link)

</div>

---

## Install

```bash
npm install -g tool-name
```

## Quick Start

```bash
# Basic usage
tool-name input.txt

# With options
tool-name input.txt --output result.json
```

## Features

- Feature 1 - benefit description
- Feature 2 - benefit description
- Feature 3 - benefit description

## Usage

### Basic

```bash
tool-name <input> [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --output` | Output file path | stdout |
| `-v, --verbose` | Enable verbose logging | false |
| `-c, --config` | Config file path | .toolrc |

### Examples

```bash
# Example 1: Basic usage
tool-name file.txt

# Example 2: With config
tool-name file.txt -c custom.json

# Example 3: Pipe support
cat file.txt | tool-name
```

## Configuration

Create `.toolrc` in your project root:

```json
{
  "option1": "value",
  "option2": true
}
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Run tool-name
  run: npx tool-name input.txt
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Command not found | Run `npm install -g tool-name` |
| Permission denied | Check file permissions |

## License

MIT
```

---

## Template 2: Library/Package

```markdown
<div align="center">

# library-name

One-line description of what this library does.

[![npm version](https://img.shields.io/npm/v/library-name.svg)](https://www.npmjs.com/package/library-name)
[![Bundle Size](https://img.shields.io/bundlephobia/minzip/library-name)](https://bundlephobia.com/package/library-name)
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue.svg)](https://www.typescriptlang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Documentation](link) | [API Reference](link) | [Examples](link)

</div>

---

## Install

```bash
npm install library-name
```

## Quick Start

```javascript
import { feature } from 'library-name';

const result = feature('input');
console.log(result); // => expected output
```

## Features

- Feature 1 - benefit
- Feature 2 - benefit
- Feature 3 - benefit

## API

### `feature(input, options?)`

Description of what this function does.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `input` | `string` | Yes | Input to process |
| `options` | `Options` | No | Configuration options |

**Returns:** `Result`

**Example:**

```javascript
const result = feature('hello', { uppercase: true });
// => 'HELLO'
```

### `Options`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `uppercase` | `boolean` | `false` | Convert to uppercase |
| `trim` | `boolean` | `true` | Trim whitespace |

## Advanced Usage

<details>
<summary>Custom Configuration</summary>

```javascript
import { configure, feature } from 'library-name';

configure({
  // global options
});

feature('input');
```

</details>

<details>
<summary>TypeScript</summary>

```typescript
import { feature, Options, Result } from 'library-name';

const options: Options = { uppercase: true };
const result: Result = feature('input', options);
```

</details>

## Browser Support

| Browser | Version |
|---------|---------|
| Chrome | 80+ |
| Firefox | 75+ |
| Safari | 13+ |
| Edge | 80+ |

## License

MIT
```

---

## Template 3: React Component

```markdown
<div align="center">

# react-component-name

One-line description of what this component does.

[![npm version](https://img.shields.io/npm/v/react-component-name.svg)](https://www.npmjs.com/package/react-component-name)
[![Bundle Size](https://img.shields.io/bundlephobia/minzip/react-component-name)](https://bundlephobia.com/package/react-component-name)
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue.svg)](https://www.typescriptlang.org/)

[Demo](link) | [Documentation](link) | [Storybook](link)

</div>

---

![Demo](demo.gif)

## Install

```bash
npm install react-component-name
```

## Quick Start

```jsx
import { Component } from 'react-component-name';

function App() {
  return (
    <Component>
      Content here
    </Component>
  );
}
```

## Features

- Feature 1 - benefit
- Feature 2 - benefit
- Feature 3 - benefit

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `children` | `ReactNode` | - | Content to render |
| `enabled` | `boolean` | `true` | Enable effect |
| `className` | `string` | - | CSS class name |
| `style` | `CSSProperties` | - | Inline styles |
| `onEvent` | `() => void` | - | Event callback |

## Examples

### Basic

```jsx
<Component>
  Hello World
</Component>
```

### With Props

```jsx
<Component
  enabled={true}
  className="custom-class"
  onEvent={() => console.log('event')}
>
  Content
</Component>
```

### Controlled

```jsx
function App() {
  const [active, setActive] = useState(false);

  return (
    <Component enabled={active}>
      Content
    </Component>
  );
}
```

## Styling

### CSS Classes

| Class | Description |
|-------|-------------|
| `.component` | Root element |
| `.component--active` | Active state |
| `.component__inner` | Inner wrapper |

### CSS Variables

```css
:root {
  --component-color: #000;
  --component-size: 16px;
}
```

## TypeScript

```tsx
import { Component, ComponentProps } from 'react-component-name';

const props: ComponentProps = {
  enabled: true,
};

<Component {...props}>Content</Component>
```

## License

MIT
```

---

## Template 4: MCP Server / Claude Code Plugin

```markdown
<div align="center">

# plugin-name

One-line description of what this plugin does for Claude Code.

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/user/plugin-name/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

[Quick Start](#quick-start) | [Commands](#commands) | [Configuration](#configuration)

</div>

---

## Quick Start

```bash
# Install
claude plugin add plugin-name

# Use
/plugin-name:command
```

## Features

| Feature | Description |
|---------|-------------|
| Feature 1 | What it does |
| Feature 2 | What it does |
| Feature 3 | What it does |

## Commands

| Command | Description |
|---------|-------------|
| `/plugin-name:main` | Primary action |
| `/plugin-name:config` | Configure settings |
| `/plugin-name:help` | Show help |

## Usage

### Basic

```
/plugin-name:main "input"
```

### With Options

```
/plugin-name:main "input" --option value
```

## Configuration

Create `.claude/plugin-name.local.md`:

```markdown
# Plugin Name Settings

- api_key: your-key-here
- option: value
```

## Requirements

- Claude Code v1.0+
- API key for external service (if applicable)

## Examples

### Example 1: Basic Usage

```
User: /plugin-name:main "hello"
Result: Expected output
```

### Example 2: Advanced

```
User: /plugin-name:main "hello" --format json
Result: {"message": "hello"}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| API error | Check API key in config |
| Not found | Reinstall plugin |

## License

MIT
```

---

## Template 5: SaaS / Web Application

```markdown
<div align="center">

<img src="logo.svg" width="150" alt="App Name">

# App Name

One-line description of your SaaS application.

[![Website](https://img.shields.io/badge/website-appname.com-blue)](https://appname.com)
[![Status](https://img.shields.io/badge/status-live-green)](https://status.appname.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Website](https://appname.com) | [Documentation](link) | [Community](link)

</div>

---

![Screenshot](screenshot.png)

## Features

- **Feature 1** - Benefit description
- **Feature 2** - Benefit description
- **Feature 3** - Benefit description

## Cloud (Recommended)

Sign up at [appname.com](https://appname.com)

Free tier includes:
- X events/month
- Y storage
- Z features

## Self-Hosted

```bash
docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://... \
  appname/appname:latest
```

**Requirements:**
- 4GB RAM minimum
- PostgreSQL 14+
- Redis 6+

**Note:** Limited support for self-hosted deployments.

## SDKs

| Platform | Package |
|----------|---------|
| JavaScript | `npm install @appname/sdk` |
| Python | `pip install appname` |
| Go | `go get github.com/appname/go` |

## Quick Start

```javascript
import { AppName } from '@appname/sdk';

const client = new AppName({ apiKey: 'your-key' });
await client.track('event', { property: 'value' });
```

## Documentation

- [Getting Started](link)
- [API Reference](link)
- [Self-Hosting Guide](link)
- [FAQ](link)

## Community

- [Discord](link)
- [GitHub Discussions](link)
- [Twitter](link)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT (see [LICENSE](LICENSE) for details)
```

---

## Template 6: Desktop Application

```markdown
<div align="center">

<img src="icon.png" width="100" alt="App Name">

# App Name

One-line description of your desktop application.

[![Version](https://img.shields.io/github/v/release/user/app-name)](https://github.com/user/app-name/releases)
[![Downloads](https://img.shields.io/github/downloads/user/app-name/total)](https://github.com/user/app-name/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Download](#download) | [Features](#features) | [Screenshots](#screenshots)

</div>

---

![Demo](demo.gif)

## Download

| Platform | Link |
|----------|------|
| Windows | [Download .exe](link) |
| macOS | [Download .dmg](link) |
| Linux | [Download .AppImage](link) |

Or install via package manager:

```bash
# macOS
brew install --cask app-name

# Windows
choco install app-name

# Linux
snap install app-name
```

## Features

- Feature 1 - benefit
- Feature 2 - benefit
- Feature 3 - benefit
- Cross-platform - Windows, macOS, Linux

## Screenshots

![Screenshot 1](screenshot1.png)
![Screenshot 2](screenshot2.png)

## Development

```bash
# Clone
git clone https://github.com/user/app-name
cd app-name

# Install
npm install

# Run
npm start

# Build
npm run build
```

## Tech Stack

- [Electron](https://electronjs.org/)
- [React](https://reactjs.org/)
- [TypeScript](https://typescriptlang.org/)

## Credits

- [Dependency 1](link)
- [Dependency 2](link)

## License

MIT

---

Made by [Your Name](https://yoursite.com)
```
