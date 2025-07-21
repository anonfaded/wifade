---
inclusion: always
---

# PowerShell Best Practices

## Coding Style

### Naming Conventions
- Use PascalCase for function names, class names, and module names
- Use camelCase for variable names and parameter names
- Use verb-noun format for function names (e.g., `Get-NetworkStatus`, `Set-WifiConnection`)
- Prefix private functions with an underscore (e.g., `_ConnectToNetwork`)
- Use full, descriptive names rather than abbreviations

### Formatting
- Use 4 spaces for indentation, not tabs
- Keep line length under 100 characters when possible
- Use single quotes for string literals unless interpolation is needed
- Use double quotes for strings with variables: `"Current SSID: $SSID"`
- Place opening braces on the same line as control statements
- Add a space after commas and around operators

## Object-Oriented Programming

### Class Structure
- Define classes in separate files within the Classes directory
- Use inheritance appropriately for specialized functionality
- Implement interfaces for consistent behavior across classes
- Keep classes focused on a single responsibility
- Make properties read-only when they shouldn't be modified externally

### Encapsulation
- Use access modifiers (public, private, protected) appropriately
- Expose properties through getters/setters when validation is needed
- Hide implementation details behind public methods

## Error Handling

### Best Practices
- Use try/catch blocks for operations that may fail
- Implement proper error messages with actionable information
- Use `$ErrorActionPreference = 'Stop'` at the beginning of scripts
- Return meaningful error objects that can be caught and handled
- Avoid using `-ErrorAction SilentlyContinue` unless absolutely necessary

### Logging
- Implement consistent logging throughout the codebase
- Use Write-Verbose for detailed operational information
- Use Write-Warning for potential issues that don't stop execution
- Use Write-Error for recoverable errors
- Use throw for fatal errors

## Code Quality

### Modularity
- Break code into small, reusable functions
- Keep functions focused on a single task
- Avoid duplicating code; extract common functionality
- Use parameter sets for functions with multiple operation modes

### Documentation
- Include comment-based help for all public functions
- Document parameters, return values, and examples
- Use inline comments for complex logic
- Include a synopsis at the top of each script file

### Testing
- Write Pester tests for all public functions
- Test both success and failure scenarios
- Mock external dependencies in tests
- Organize tests to mirror the structure of the code

## Performance

### Optimization
- Use the pipeline efficiently; avoid unnecessary objects in memory
- Prefer foreach loops over ForEach-Object for large collections
- Use [OutputType()] to declare function return types
- Avoid string concatenation in loops; use StringBuilder or arrays

### Resource Management
- Dispose of resources properly using try/finally blocks
- Close connections and file handles explicitly
- Use the using statement for IDisposable objects

## Security

### Best Practices
- Never store credentials in plain text
- Use SecureString for passwords and sensitive data
- Validate all user input before processing
- Follow the principle of least privilege
- Avoid using Invoke-Expression with user-supplied input

## PowerShell Modules

### Structure
- Use a consistent directory structure for modules
- Include a module manifest (.psd1) file
- Separate public and private functions
- Export only the functions that should be publicly available
- Version modules according to semantic versioning

### Dependencies
- Clearly document required modules and versions
- Use Import-Module with minimum version requirements
- Check for required dependencies at module load time

## Version Control

### Practices
- Only modify relevant files for a given change
- Keep commits focused on a single logical change
- Write meaningful commit messages
- Use feature branches for new development