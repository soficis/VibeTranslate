# Contributing to TranslateVibe

Welcome! This guide provides comprehensive information for contributors to the TranslateVibe project, which contains multiple implementations of the same translation application in different languages and frameworks.

## Table of Contents
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Workflows](#development-workflows)
- [Language-Specific Guidelines](#language-specific-guidelines)
- [Feature Development](#feature-development)
- [Testing](#testing)
- [Code Review Process](#code-review-process)
- [Documentation](#documentation)
- [Issue Reporting](#issue-reporting)
- [Community Guidelines](#community-guidelines)

## Getting Started

### Prerequisites
Before contributing, ensure you have:
- **Git** for version control
- **.NET 9 SDK** for .NET applications
- **Python 3.6+** for Python implementation
- **Windows 10/11** for Windows-specific applications
- **Visual Studio 2022** or **VS Code** for development

### Initial Setup
```bash
# Fork and clone the repository
git clone https://github.com/yourusername/TranslateVibe.git
cd TranslateVibe

# Set up upstream remote
git remote add upstream https://github.com/original/TranslateVibe.git

# Create a feature branch
git checkout -b feature/your-feature-name
```

### Development Environment
```bash
# Build all projects
foreach ($project in @("CsharpTranslationFiesta", "FreeTranslateWin", "FSharpTranslate", "TranslationFiesta.WinUI")) {
    cd $project
    dotnet restore
    dotnet build
    cd ..
}

# Python setup
cd TranslationFiestaPy
pip install -r requirements.txt
```

## Project Structure

```
TranslateVibe/
├── 📁 CsharpTranslationFiesta/     # C# WinForms implementation
├── 📁 FreeTranslateWin/           # C# WPF implementation
├── 📁 FSharpTranslate/            # F# implementation
├── 📁 TranslationFiesta.WinUI/    # WinUI 3 implementation
├── 📁 TranslationFiestaPy/        # Python implementation
├── 📁 docs/                       # Documentation
│   ├── FeatureComparison.md       # Feature comparison
│   ├── SetupAndBuild.md          # Build instructions
│   ├── TranslationFiestaPy.md    # Python docs
│   ├── FSharpTranslate.md        # F# docs
│   ├── CsharpImplementations.md  # C# docs
│   ├── TranslationFiesta.WinUI.md # WinUI docs
│   └── Contributing.md           # This file
├── 📄 README.md                   # Main repository README
└── 📄 .gitignore                  # Git ignore rules
```

## Development Workflows

### Branching Strategy
- **`main`**: Production-ready code
- **`develop`**: Integration branch for features
- **`feature/*`**: New features
- **`bugfix/*`**: Bug fixes
- **`hotfix/*`**: Critical production fixes

### Commit Message Format
```
type(scope): description

[optional body]

[optional footer]
```

#### Types
- **feat**: New features
- **fix**: Bug fixes
- **docs**: Documentation
- **style**: Code style changes
- **refactor**: Code refactoring
- **test**: Testing
- **chore**: Maintenance

#### Examples
```
feat(python): add batch file processing
fix(winui): resolve theme switching bug
docs: update setup instructions
```

### Pull Request Process
1. **Create Feature Branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make Changes**
   - Follow language-specific guidelines
   - Add tests if applicable
   - Update documentation

3. **Test Thoroughly**
   ```bash
   # Test all affected implementations
   dotnet test  # For .NET projects
   python -m pytest  # For Python
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/amazing-feature
   # Create PR on GitHub
   ```

## Language-Specific Guidelines

### Python (TranslationFiestaPy)

#### Code Style
```python
# Follow PEP 8
def function_name(parameter: str) -> bool:
    """Docstring describing function."""
    if parameter:
        return True
    return False

# Use type hints
from typing import Optional, List

def process_files(files: List[str]) -> Optional[str]:
    pass
```

#### Best Practices
- Use virtual environments
- Add comprehensive docstrings
- Handle exceptions appropriately
- Use context managers for file operations
- Follow import organization (standard, third-party, local)

#### Testing
```python
# Use pytest for testing
def test_translation_function():
    # Arrange
    input_text = "Hello world"

    # Act
    result = translate_text(input_text)

    # Assert
    assert result is not None
    assert "こんにちは" in result  # Japanese expected
```

### C# Implementations

#### Code Style (All C# Projects)
```csharp
// Use meaningful names
public class TranslationService
{
    private readonly HttpClient _httpClient;

    public async Task<string> TranslateTextAsync(string text)
    {
        // Implementation
        if (string.IsNullOrEmpty(text))
        {
            throw new ArgumentException("Text cannot be null or empty");
        }

        // Async/await pattern
        var response = await _httpClient.GetAsync("url");
        return await response.Content.ReadAsStringAsync();
    }
}
```

#### WinForms Specific
- Use proper event handler naming: `Button_Click`
- Dispose of resources properly
- Use `using` statements for disposables
- Avoid blocking UI thread

#### WPF Specific
- Use MVVM pattern where possible
- Bind to ViewModels for data
- Use dependency properties for custom controls
- Follow XAML naming conventions

#### WinUI 3 Specific
- Use modern async patterns
- Implement proper lifecycle management
- Follow Fluent Design guidelines
- Use WinUI controls over custom implementations

### F# Implementation

#### Code Style
```fsharp
// Use functional programming principles
module TranslationService

// Type definitions
type TranslationResult =
    | Success of string
    | Failure of string

// Pure functions
let validateInput input =
    if String.IsNullOrWhiteSpace input then
        Error "Input cannot be empty"
    else
        Ok input

// Async workflows
let translateTextAsync text = async {
    try
        let! response = httpClient.GetAsync(url) |> Async.AwaitTask
        return Success response
    with
    | ex -> return Failure ex.Message
}
```

#### Best Practices
- Use immutable data structures
- Prefer pure functions
- Use Result types for error handling
- Follow Clean Code principles
- Use meaningful names without abbreviations

## Feature Development

### Feature Implementation Strategy

#### 1. Plan the Feature
- **Define Requirements**: What should the feature do?
- **Identify Scope**: Which implementations need it?
- **Consider Impact**: How does it affect existing code?

#### 2. Choose Implementation Order
- **Start Simple**: Begin with Python or C# WinForms
- **Complex Languages**: Implement in F# or WinUI 3 next
- **Cross-Language**: Ensure consistency across implementations

#### 3. Maintain Feature Parity
```csharp
// Example: Adding a new feature consistently

// C# WinForms
public void EnableFeature(bool enabled)
{
    featureButton.Enabled = enabled;
    Settings.Default.FeatureEnabled = enabled;
}

// F# (functional approach)
let enableFeature enabled =
    featureButton.Enabled <- enabled
    Settings.Default.FeatureEnabled <- enabled
    saveSettings ()

// Python
def enable_feature(enabled: bool) -> None:
    feature_button.config(state='normal' if enabled else 'disabled')
    settings.feature_enabled = enabled
    settings.save()
```

### Adding New Languages/Frameworks
1. **Create Project Structure**
2. **Implement Core Functionality**
3. **Add Language-Specific Features**
4. **Update Documentation**
5. **Add to CI/CD Pipeline**

### API Design Guidelines
- **Consistent Naming**: Use similar names across languages
- **Error Handling**: Follow language conventions
- **Async Support**: Use appropriate async patterns
- **Documentation**: Document all public APIs

## Testing

### Testing Strategy
- **Unit Tests**: Test individual functions/classes
- **Integration Tests**: Test component interactions
- **UI Tests**: Test user interface functionality
- **Cross-Platform Tests**: Verify behavior across implementations

### Testing Frameworks

#### .NET (C#, F#)
```csharp
// Use xUnit or NUnit
public class TranslationServiceTests
{
    [Fact]
    public async Task TranslateTextAsync_ValidInput_ReturnsTranslation()
    {
        // Arrange
        var service = new TranslationService();
        var input = "Hello";

        // Act
        var result = await service.TranslateTextAsync(input);

        // Assert
        Assert.NotNull(result);
        Assert.Contains("こんにちは", result);
    }
}
```

#### Python
```python
# Use pytest
import pytest
from translation_service import TranslationService

def test_translate_text_valid_input():
    service = TranslationService()
    result = service.translate_text("Hello")

    assert result is not None
    assert "こんにちは" in result

def test_translate_text_empty_input():
    service = TranslationService()

    with pytest.raises(ValueError):
        service.translate_text("")
```

### Test Coverage Goals
- **Core Logic**: 80%+ coverage
- **UI Components**: 60%+ coverage
- **Error Paths**: All major error conditions tested
- **Edge Cases**: Boundary conditions covered

## Code Review Process

### Review Checklist
- [ ] **Functionality**: Does the code work as expected?
- [ ] **Code Quality**: Follows language conventions?
- [ ] **Documentation**: Adequate comments and docs?
- [ ] **Testing**: Appropriate test coverage?
- [ ] **Security**: No security vulnerabilities?
- [ ] **Performance**: Efficient implementation?
- [ ] **Consistency**: Matches other implementations?

### Review Comments
- **Be Specific**: Explain what needs to change and why
- **Suggest Solutions**: Provide concrete suggestions
- **Ask Questions**: Seek clarification when needed
- **Be Respectful**: Focus on code, not person

### Approval Process
1. **Automated Checks**: CI/CD must pass
2. **Peer Review**: At least one approval required
3. **Maintainer Review**: For significant changes
4. **Merge**: Squash and merge approved PRs

## Documentation

### Documentation Standards
- **README Files**: Keep implementation-specific READMEs updated
- **Code Comments**: Document complex logic
- **API Documentation**: Document public interfaces
- **Changelogs**: Track changes and fixes

### Documentation Updates
When making changes:
1. Update relevant README files
2. Add code comments for complex logic
3. Update feature comparison tables
4. Add migration guides for breaking changes

### Example Documentation
```csharp
/// <summary>
/// Translates text using the specified API.
/// </summary>
/// <param name="text">The text to translate.</param>
/// <param name="sourceLang">Source language code (e.g., "en").</param>
/// <param name="targetLang">Target language code (e.g., "ja").</param>
/// <returns>The translated text.</returns>
/// <exception cref="ArgumentException">Thrown when input is invalid.</exception>
public async Task<string> TranslateAsync(string text, string sourceLang, string targetLang)
```

## Issue Reporting

### Bug Reports
Use this template:
```
## Title: [BUG] Brief description

## Description
Detailed description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Expected behavior
4. Actual behavior

## Environment
- OS: Windows 10/11
- Implementation: Python/C#/F#/WinUI
- Version: v1.0.0

## Screenshots
If applicable, add screenshots

## Additional Context
Any other relevant information
```

### Feature Requests
Use this template:
```
## Title: [FEATURE] Brief description

## Problem
What problem does this solve?

## Solution
Describe the proposed solution

## Alternatives
Any alternative solutions considered?

## Implementation Impact
Which implementations would be affected?

## Additional Context
Any other relevant information
```

## Community Guidelines

### Code of Conduct
- **Be Respectful**: Treat all contributors with respect
- **Be Inclusive**: Welcome contributions from everyone
- **Be Collaborative**: Work together to improve the project
- **Be Patient**: Allow time for responses and reviews

### Communication
- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Pull Request Comments**: For code review feedback

### Recognition
- **Contributors**: Listed in repository contributors
- **Maintainers**: Core team managing the project
- **Community**: Everyone who helps improve the project

## Recognition

### Contributor Tiers
- **Contributors**: Anyone who submits a PR
- **Active Contributors**: Regular contributors with multiple PRs
- **Maintainers**: Core team with repository access

### Getting Help
- **Documentation**: Check docs/ folder first
- **Issues**: Search existing issues
- **Discussions**: Ask the community
- **Maintainers**: Contact for urgent matters

## Thank You!

Thank you for contributing to TranslateVibe! Your contributions help make this project better for everyone. Whether you're fixing bugs, adding features, improving documentation, or helping other contributors, your efforts are greatly appreciated.

Remember: **Every contribution counts**, from fixing a typo to implementing a major feature. Let's build something amazing together! 🚀
