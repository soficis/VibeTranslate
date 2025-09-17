# Usage Guide: TranslationFiestaRuby

**Repository**: [https://github.com/soficis/VibeTranslate](https://github.com/soficis/VibeTranslate) - TranslationFiestaRuby

This guide provides detailed instructions for using the Ruby implementation of TranslationFiesta, including setup, usage, and troubleshooting.

## 🌟 Overview

TranslationFiestaRuby is a Ruby port of the TranslationFiesta application, providing English ↔ Japanese back-translation with quality assessment. This implementation uses Sinatra for the web UI and follows Clean Architecture principles.

> **⚠️ Note**: This Ruby port is experimental and currently untested. It provides feature parity with other implementations but may require additional setup.

## 🏗️ Architecture

```
lib/translation_fiesta/
├── domain/                    # Business logic and entities
├── use_cases/               # Application orchestration
├── data/                    # Data access implementations
├── features/                # Feature-specific modules
├── infrastructure/          # Cross-cutting concerns
├── web/                     # Sinatra web UI
└── gui/                     # Legacy Tk GUI (deprecated)
```

## 🚀 Quick Start

### Prerequisites
- Ruby 3.2+ (recommended: 3.4.x)
- Bundler gem
- On Windows: RubyInstaller with DevKit or MSYS2

### Installation
```bash
cd TranslationFiestaRuby

# Install dependencies
bundle install

# Setup database
rake setup_db
```

### Running the Application
```bash
# Web UI (recommended)
rake web

# Web UI with browser launch
rake web:open

# CLI mode
rake cli translate "Hello world"

# Mock mode (no API keys needed)
TF_USE_MOCK=1 rake web
```

## 💻 Detailed Usage

### Web UI (Sinatra)

The web interface provides a modern, cross-platform alternative to the legacy Tk GUI.

#### Starting the Server
```bash
# Default configuration
rake web

# Custom port
TF_WEB_PORT=8080 rake web

# Custom bind address
TF_WEB_BIND=0.0.0.0 rake web
```

#### Environment Variables
```bash
# Server configuration
TF_WEB_BIND=127.0.0.1    # Bind address
TF_WEB_PORT=4567         # Port number

# Security (optional)
TF_API_TOKEN=secret      # API token for authentication
TF_RATE_LIMIT=60         # Requests per minute per IP

# Application
TF_USE_MOCK=1            # Enable mock translations
TF_EXPORT_DIR=exports    # Export directory
```

#### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Main web interface |
| POST | `/api/translate` | Translate text |
| GET | `/api/result/:id` | Get translation result |
| POST | `/api/export/:id` | Export result |
| GET | `/health` | Health check |

#### Example API Usage
```bash
# Translate text
curl -X POST http://127.0.0.1:4567/api/translate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world","api_type":"unofficial"}'

# Get result
curl http://127.0.0.1:4567/api/result/abc-123

# Export result
curl -X POST http://127.0.0.1:4567/api/export/abc-123 \
  -H "Content-Type: application/json" \
  -d '{"format":"txt"}'
```

### Command Line Interface

#### Basic Translation
```bash
# Translate text
rake cli translate "Hello world"

# Specify API type
rake cli translate "Hello world" --api official

# Process a file
rake cli file sample.txt

# Batch process directory
rake cli batch ./documents --threads 4
```

#### Advanced Options
```bash
# Export formats
rake cli translate "Hello" --format pdf --output result.pdf

# Verbose output
rake cli translate "Hello" --verbose

# View cost summary
rake cli cost
```

### Mock Mode

For development and testing without API keys:
```bash
# Enable mock translations
TF_USE_MOCK=1 rake web

# CLI with mock
TF_USE_MOCK=1 rake cli translate "Hello world"
```

Mock mode returns deterministic translations:
- Japanese: `[ja] {original_text}`
- Back translation: `[en] [ja] {original_text}`

## 🔧 Configuration

### API Keys

#### Official Google Translate API
1. Create project in Google Cloud Console
2. Enable Cloud Translation API
3. Create service account key
4. Set environment variables:
```bash
$env:GOOGLE_APPLICATION_CREDENTIALS = "path/to/key.json"
```

#### Unofficial API
No setup required, but rate-limited and may be unreliable.

### Database Setup
```bash
# Initialize SQLite database
rake setup_db

# Database location: lib/translation_fiesta/data/databases/
```

## 🧪 Testing

### Running Tests
```bash
# All tests
rake spec

# Specific test file
rspec spec/domain/entities/translation_result_spec.rb

# Request specs (web API)
rspec spec/requests/web_app_spec.rb
```

### Test Configuration
```bash
# Mock mode for tests
TF_USE_MOCK=1 rspec

# Coverage report
COVERAGE=1 rake spec
```

## 📁 File Support

| Format | Read | Export | Notes |
|--------|------|--------|-------|
| TXT    | ✅   | ✅     | Plain text |
| MD     | ✅   | ✅     | Markdown |
| HTML   | ✅   | ✅     | HTML content |
| EPUB   | ✅   | ❌     | Text extraction only |
| PDF    | ❌   | ✅     | Export only |
| DOCX   | ❌   | ✅     | Export only (requires docx gem) |

## 🔐 Security Features

### API Token Authentication
```bash
# Set API token
TF_API_TOKEN=my-secret-token

# API requests must include:
# Header: X-API-Token: my-secret-token
# Or query param: ?api_token=my-secret-token
```

### Rate Limiting
```bash
# Configure requests per minute
TF_RATE_LIMIT=60

# Rate limit exceeded returns HTTP 429
```

## 📊 Cost Tracking

### Viewing Costs
```bash
# CLI cost summary
rake cli cost

# Database location
# lib/translation_fiesta/data/databases/cost_tracking.db
```

### Cost Structure
- **Unofficial API**: Free (rate-limited)
- **Official API**: $20 per 1M characters

## 🚀 Deployment

### Production Setup
```bash
# Environment variables
TF_WEB_BIND=0.0.0.0
TF_WEB_PORT=80
TF_API_TOKEN=production-token
TF_RATE_LIMIT=100

# Start server
rake web
```

### Docker (Future)
```dockerfile
FROM ruby:3.4-slim
WORKDIR /app
COPY . .
RUN bundle install
EXPOSE 4567
CMD ["rake", "web"]
```

## 🐛 Troubleshooting

### Common Issues

#### Bundle Install Fails
```bash
# Windows: Ensure DevKit is installed
ridk install
ridk enable

# Clear cache and retry
bundle clean --force
bundle install

# Install problematic gems individually
gem install nokogiri --platform=ruby
gem install sqlite3 --platform=ruby
```

#### Server Won't Start
```bash
# Check port availability
netstat -ano | findstr :4567

# Kill process on port
taskkill /PID <PID> /F

# Check Ruby version
ruby -v
```

#### Database Issues
```bash
# Reinitialize database
rake setup_db

# Check database file
ls lib/translation_fiesta/data/databases/
```

#### Mock Mode Not Working
```bash
# Explicitly set environment
$env:TF_USE_MOCK = "1"
rake web
```

### Debug Information
```bash
# Ruby information
ruby -e "puts RUBY_VERSION; puts RUBY_PLATFORM"

# Gem list
gem list | grep -E "(sinatra|nokogiri|sqlite3)"

# Environment variables
Get-ChildItem env: | Where-Object {$_.Name -like "TF_*"}
```

### Log Files
- Application logs: `translationfiesta.log`
- Web server logs: Console output
- Database logs: SQLite query logs (if enabled)

## 🔄 Migration from Other Ports

### From Python
- API keys: Set `GOOGLE_APPLICATION_CREDENTIALS`
- Database: Run `rake setup_db`
- Configuration: Environment variables instead of config files

### From .NET
- API keys: Same Google Cloud setup
- Database: SQLite instead of SQL Server
- UI: Web-based instead of WinForms

### From Go
- API keys: Same Google Cloud setup
- Dependencies: Bundle instead of go mod
- Build: `rake web` instead of `go run`

## 📚 Advanced Usage

### Custom Export Formats
```ruby
# In Ruby code
require 'translation_fiesta'
container = TranslationFiesta::Infrastructure::DependencyContainer.new
exporter = container.export_manager
exporter.export_single_result(result, 'output.custom')
```

### Batch Processing
```ruby
# Programmatic batch processing
require 'translation_fiesta'
processor = TranslationFiesta::Features::BatchProcessor.new
processor.process_directory('./docs', threads: 4)
```

### Plugin Development
```ruby
# Custom translation repository
class CustomTranslationRepository
  include TranslationFiesta::Domain::Repositories::TranslationRepository
  # Implement interface methods
end
```

## 🤝 Contributing

### Development Setup
```bash
# Fork and clone
git clone https://github.com/yourusername/VibeTranslate.git
cd VibeTranslate/TranslationFiestaRuby

# Install dependencies
bundle install

# Setup database
rake setup_db

# Run tests
rake spec

# Start development server
TF_USE_MOCK=1 rake web
```

### Code Style
```bash
# Lint code
rubocop

# Auto-fix issues
rubocop -a

# Check test coverage
COVERAGE=1 rake spec
```

## 📄 License

This implementation is part of the VibeTranslate collection. See the main repository for license information.

## 🔗 Related Documentation

- [Setup and Build Guide](../SetupAndBuild.md)
- [Feature Comparison](../FeatureComparison.md)
- [Contributing Guidelines](../Contributing.md)
- [Main Repository README](../../README.md)