# Contributing to F# TranslationFiesta

Thank you for your interest in contributing to F# TranslationFiesta! This document provides guidelines and information for contributors.

## 🚀 Quick Start

### Prerequisites
- **.NET 9 SDK** or later
- **Windows 10/11** (for Windows Forms development)
- **Git** for version control
- **Visual Studio 2022** or **VS Code** (recommended)

### Setup Development Environment
```powershell
# Clone the repository
git clone https://github.com/yourusername/Vibes.git
cd Vibes/FSharpTranslate

# Restore dependencies
dotnet restore

# Build and test
dotnet build
dotnet run

# Run tests (if available)
dotnet test
```

## 📋 How to Contribute

### 1. Report Issues
- **Search existing issues** before creating new ones
- **Use issue templates** when available
- **Provide detailed information**:
  - Operating system and version
  - .NET version
  - Steps to reproduce
  - Expected vs actual behavior
  - Screenshots if UI-related

### 2. Suggest Features
- **Check the roadmap** in [CHANGELOG.md](CHANGELOG.md)
- **Open a discussion** before implementing large features
- **Explain the use case** and benefits
- **Consider backwards compatibility**

### 3. Submit Pull Requests
1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** following our coding standards
4. **Test thoroughly** including edge cases
5. **Update documentation** if needed
6. **Commit with clear messages**
7. **Push and create PR** with detailed description

## 🎯 Development Guidelines

### Code Style and Standards

#### F# Coding Standards
```fsharp
// ✅ Good: Clear, descriptive names
let translateWithRetriesAsync (text: string) (maxAttempts: int) =
    async { /* implementation */ }

// ❌ Avoid: Unclear abbreviations
let tWRA (txt: string) (max: int) = async { /* implementation */ }

// ✅ Good: Proper error handling with Result types
let parseInput input =
    if String.IsNullOrWhiteSpace input then
        Error "Input cannot be empty"
    else
        Ok (input.Trim())

// ✅ Good: Meaningful function decomposition
let setTheme isDark =
    if isDark then setDarkTheme() else setLightTheme()
```

#### Clean Code Principles
Following Robert C. Martin's "Clean Code":

1. **Meaningful Names**
   ```fsharp
   // ✅ Good
   let showProgressSpinner isVisible =
       progressSpinner.Visible <- isVisible
   
   // ❌ Avoid
   let sps vis = ps.V <- vis
   ```

2. **Small Functions**
   ```fsharp
   // ✅ Good: Single responsibility
   let enableTranslationControls () =
       btnBacktranslate.Enabled <- true
       btnImportTxt.Enabled <- true
   
   let disableTranslationControls () =
       btnBacktranslate.Enabled <- false
       btnImportTxt.Enabled <- false
   ```

3. **Error Handling**
   ```fsharp
   // ✅ Good: Explicit error handling
   let loadTextFile filePath =
       try
           let content = File.ReadAllText(filePath, Encoding.UTF8)
           Ok content
       with
       | :? FileNotFoundException -> Error "File not found"
       | :? UnauthorizedAccessException -> Error "Access denied"
       | ex -> Error (sprintf "Failed to load file: %s" ex.Message)
   ```

### UI Development Guidelines

#### Windows Forms Best Practices
```fsharp
// ✅ Good: Proper control initialization
let createButton text left top width onClick =
    let btn = new Button(
        Text = text,
        Left = left,
        Top = top,
        Width = width,
        FlatStyle = FlatStyle.Standard
    )
    btn.Click.Add(onClick)
    btn

// ✅ Good: Theme consistency
let applyDarkTheme control =
    control.BackColor <- Color.FromArgb(45, 45, 48)
    control.ForeColor <- Color.White
```

#### Accessibility Considerations
- **Keyboard Navigation**: Ensure all controls are accessible via keyboard
- **Screen Reader Support**: Use meaningful control names and descriptions
- **High Contrast**: Test with high contrast themes
- **Font Scaling**: Support Windows font scaling settings

### Testing Guidelines

#### Unit Testing (Future Implementation)
```fsharp
// Example test structure
[<Test>]
let ``translateUnofficialAsync should return error for empty text`` () =
    async {
        let! result = translateUnofficialAsync "" "en" "ja"
        match result with
        | Error msg -> Assert.IsTrue(msg.Contains("empty"))
        | Ok _ -> Assert.Fail("Expected error for empty text")
    }
```

#### Integration Testing
- **API Testing**: Test both unofficial and official Google Translate APIs
- **File Operations**: Test import/export functionality
- **UI Testing**: Verify control interactions and theming
- **Error Scenarios**: Test network failures, invalid inputs, etc.

## 🏗️ Project Structure

```
FSharpTranslate/
├── Program.fs              # Main application entry point
├── Logger.fs               # Logging functionality
├── FSharpTranslate.fsproj  # Project configuration
├── README.md               # Main documentation
├── INSTALLATION.md         # Installation guide
├── CHANGELOG.md            # Version history
├── CONTRIBUTING.md         # This file
├── publish/                # Distribution files
│   └── FSharpTranslate.exe # Self-contained executable
└── bin/                    # Build outputs
```

### Key Components

#### Core Translation Logic
- **`translateUnofficialAsync`**: Free Google Translate API
- **`translateOfficialAsync`**: Google Cloud Translation API
- **`translateWithRetriesAsync`**: Retry logic with exponential backoff

#### UI Management
- **Theme System**: Light/dark mode switching
- **Control Management**: Enable/disable during operations
- **Status Updates**: User feedback and progress indication

#### File Operations
- **Text Import**: UTF-8 file loading
- **Result Export**: Formatted text saving
- **Clipboard Integration**: Copy/paste functionality

## 🔍 Review Process

### Pull Request Requirements
- [ ] **Code compiles** without warnings
- [ ] **Follows coding standards** outlined above
- [ ] **Includes tests** for new functionality (when applicable)
- [ ] **Updates documentation** if needed
- [ ] **Describes changes** clearly in PR description
- [ ] **References related issues** if applicable

### Review Criteria
1. **Functionality**: Does it work as intended?
2. **Code Quality**: Is it clean, readable, and maintainable?
3. **Performance**: Are there any performance implications?
4. **Security**: Are there any security concerns?
5. **Compatibility**: Does it maintain backwards compatibility?
6. **Documentation**: Is it properly documented?

## 🐛 Bug Reports

### Bug Report Template
```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
 - OS: [e.g. Windows 11]
 - Version [e.g. 2.1.0]
 - .NET Version [e.g. .NET 9]

**Additional context**
Add any other context about the problem here.
```

## 💡 Feature Requests

### Feature Request Template
```markdown
**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request here.
```

## 🎨 Design Guidelines

### UI/UX Principles
- **Simplicity**: Keep the interface clean and focused
- **Consistency**: Maintain consistent styling and behavior
- **Feedback**: Provide clear feedback for user actions
- **Accessibility**: Support users with disabilities
- **Performance**: Ensure responsive UI during operations

### Visual Design
- **Typography**: Use Segoe UI for Windows consistency
- **Colors**: Support both light and dark themes
- **Spacing**: Maintain consistent margins and padding
- **Icons**: Use standard Windows icons where appropriate

## 📚 Resources

### Learning F#
- [F# Documentation](https://docs.microsoft.com/en-us/dotnet/fsharp/)
- [F# for Fun and Profit](https://fsharpforfunandprofit.com/)
- [F# Software Foundation](https://fsharp.org/)

### Windows Forms Development
- [Windows Forms Documentation](https://docs.microsoft.com/en-us/dotnet/desktop/winforms/)
- [Windows Forms Best Practices](https://docs.microsoft.com/en-us/dotnet/desktop/winforms/advanced/)

### Clean Code Resources
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

## 🤝 Community

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community support
- **Pull Requests**: Code contributions and reviews

### Code of Conduct
We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful, constructive, and professional in all interactions.

## 📝 License

By contributing to F# TranslationFiesta, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to F# TranslationFiesta!** 🎉

Your contributions help make this tool better for everyone. Whether you're fixing bugs, adding features, or improving documentation, every contribution is valuable and appreciated.
