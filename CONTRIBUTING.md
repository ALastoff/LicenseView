# Contributing to LicenseView

Thank you for your interest in contributing to LicenseView! This document provides guidelines for contributions.

## Code of Conduct

Be respectful, inclusive, and professional in all interactions.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** - Your bug may already be reported
2. **Open a new issue** with:
   - Clear title describing the issue
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, PowerShell/Python version, Zerto version)
   - Relevant log excerpts (redact credentials!)

### Suggesting Features

1. **Check existing feature requests** - Similar ideas may exist
2. **Open a new issue** labeled "enhancement" with:
   - Use case description
   - Proposed solution
   - Alternative approaches considered
   - Potential impact on existing functionality

### Submitting Code

#### Setup Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/licenseview.git
cd licenseview

# Create feature branch
git checkout -b feature/my-awesome-feature

# Copy config template
cp config.example.yaml config.yaml
# (Edit config.yaml with test ZVM details)
```

#### Code Standards

**PowerShell:**
- Follow [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/)
- Run PSScriptAnalyzer before committing:
  ```powershell
  Invoke-ScriptAnalyzer -Path . -Recurse
  ```
- Use approved verbs (`Get-`, `Set-`, `New-`, etc.)
- Document parameters with comment-based help

**Python:**
- Follow PEP 8 style guide
- Format with `black`:
  ```bash
  black src/ tests/
  ```
- Lint with `flake8`:
  ```bash
  flake8 src/ tests/
  ```
- Type hints encouraged (validated with `mypy`)

**General:**
- Write clear commit messages (present tense, imperative mood)
- Keep commits focused and atomic
- Update tests for new functionality
- Update documentation for user-facing changes

#### Testing

**PowerShell:**
```powershell
# Run all tests
Invoke-Pester ./tests -Output Detailed

# Run specific test file
Invoke-Pester ./tests/ps/Test-ZertoAuth.Tests.ps1
```

**Python:**
```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=src/py/zerto --cov-report=html
```

**Integration Testing:**
- Use mocked Zerto API responses (`tests/fixtures/mock_zvm_responses.json`)
- Never commit test credentials
- Test both Zerto 10.x and pre-10.x authentication paths
- Verify TLS validation behavior

#### Pull Request Process

1. **Update your branch** with latest main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all tests** and ensure they pass

3. **Create pull request** with:
   - Clear title describing the change
   - Description of what changed and why
   - Link to related issues (e.g., "Fixes #123")
   - Screenshots for UI changes
   - Confirmation that tests pass

4. **Respond to feedback** - Maintainers may request changes

5. **Squash commits** if requested before merge

## Development Workflow

### Project Structure

```
src/
  ps/                 # PowerShell modules
    Zerto.Auth.psm1   # Authentication
    Zerto.Api.psm1    # API client
    Zerto.Data.psm1   # Data transformation
    Zerto.Output.psm1 # Report generation
  py/                 # Python package (mirrors PS structure)
    zerto/
      auth.py
      api.py
      data.py
      output.py

tests/
  ps/                 # PowerShell Pester tests
  py/                 # Python pytest tests
  fixtures/           # Mock API responses
```

### Adding New Features

1. **Module changes**: Edit appropriate module in `src/ps/` or `src/py/`
2. **Add tests**: Create test file in `tests/ps/` or `tests/py/`
3. **Update docs**: Modify README.md if user-facing
4. **Add fixtures**: Update `tests/fixtures/` with new API response examples

### Debugging

**PowerShell verbose output:**
```powershell
./zerto-licensing-report.ps1 -Config ./config.yaml -Verbose
```

**Python debug logging:**
```bash
python main.py --config ./config.yaml --verbose
```

**Check generated logs:**
```
logs/report.log
```

## API Development

### Adding New API Endpoints

1. **Update API client** (`Zerto.Api.psm1` or `api.py`):
   ```powershell
   function Get-ZertoNewEndpoint {
       param($AuthContext)
       $url = "$($AuthContext.ZvmUrl)/v1/newdata"
       Invoke-ZertoApiCall -Url $url -AuthContext $AuthContext
   }
   ```

2. **Add mock response** to `tests/fixtures/mock_zvm_responses.json`:
   ```json
   {
     "endpoint": "/v1/newdata",
     "response": { "data": "example" }
   }
   ```

3. **Update data transformation** (`Zerto.Data.psm1` or `data.py`)

4. **Add to report output** (`Zerto.Output.psm1` or `output.py`)

5. **Write tests** for new functionality

### Version Compatibility

When adding features that differ between Zerto versions:

```powershell
if ($ZertoVersion -ge [Version]"10.0") {
    # Zerto 10.x logic
} else {
    # Pre-10.x fallback
}
```

## Documentation

### Code Documentation

**PowerShell:**
```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.PARAMETER ParamName
    Parameter description

.EXAMPLE
    Get-Example -ParamName "value"
    Description of example

.NOTES
    Additional information
#>
```

**Python:**
```python
def function_name(param: str) -> dict:
    """Brief description.
    
    Detailed description.
    
    Args:
        param: Parameter description
        
    Returns:
        Dictionary containing result
        
    Raises:
        ValueError: When validation fails
    """
```

### User Documentation

Update these files when making user-facing changes:

- **README.md** - Quick start, usage examples
- **TLS_SETUP_GUIDE.md** - Certificate configuration
- **SECURITY.md** - Security best practices
- **CHANGELOG.md** - Version history

## Release Process

(For maintainers)

1. Update `CHANGELOG.md` with version and changes
2. Tag release: `git tag -a v1.2.0 -m "Release 1.2.0"`
3. Push tags: `git push origin v1.2.0`
4. Create GitHub release with notes from CHANGELOG

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Open a GitHub Issue
- **Security concerns**: See [SECURITY.md](SECURITY.md)
- **Collaboration**: Email aaron.lastoff@gmail.com

## Maintainer

**Aaron Lastoff**
- 📧 Email: aaron.lastoff@gmail.com
- 🐙 GitHub: [@AaronLastoff](https://github.com/AaronLastoff)
- 💼 Open to collaboration, feature discussions, and code reviews!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
