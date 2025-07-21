# Design Document

## Overview

The Windows PowerShell version of Wifade will be a complete rewrite that maintains functional parity with the existing Linux bash implementation while leveraging PowerShell's object-oriented capabilities and Windows-specific networking APIs. The design follows object-oriented principles with clear separation of concerns, robust error handling, and extensible architecture to support future enhancements.

## Architecture

### High-Level Architecture

The application follows a modular, object-oriented design with the following core components:

```
WifadePS (Main Entry Point)
├── ConfigurationManager (Parameter parsing, file handling)
├── NetworkManager (Wi-Fi operations, adapter management)
├── PasswordManager (Password list management, attack strategies)
├── UIManager (Console output, progress tracking)
├── LoggingManager (Error handling, audit trails)
└── SecurityManager (Ethical usage enforcement, safety features)
```

### Design Principles

1. **Single Responsibility**: Each class handles one specific aspect of functionality
2. **Dependency Injection**: Classes receive dependencies through constructors
3. **Interface Segregation**: Well-defined interfaces for testability and extensibility
4. **Error Handling**: Structured exception handling with meaningful error messages
5. **Extensibility**: Plugin-like architecture for future attack methods and export formats

## Components and Interfaces

### ConfigurationManager Class

**Purpose**: Handles command-line parameter parsing and configuration file management

**Key Methods**:
- `ParseCommandLineArguments($args)`: Process command-line parameters
- `LoadSSIDList($filePath)`: Read and validate SSID file
- `LoadPasswordList($filePath)`: Read and validate password file
- `ValidateConfiguration()`: Ensure all required files exist and are readable

**Properties**:
- `SSIDFilePath`: Path to SSID configuration file
- `PasswordFilePath`: Path to password configuration file
- `ShowHelp`: Boolean flag for help display
- `Configuration`: Hashtable containing all configuration settings

### NetworkManager Class

**Purpose**: Manages Wi-Fi adapter detection, network operations, and connection attempts

**Key Methods**:
- `DetectWiFiAdapters()`: Enumerate and validate available Wi-Fi adapters
- `GetNetworkProfiles()`: Retrieve detailed network information
- `AttemptConnection($ssid, $password)`: Execute connection attempt
- `DisconnectFromNetwork()`: Clean disconnect from current network
- `GetAdapterStatus()`: Monitor adapter health and capabilities

**Properties**:
- `PrimaryAdapter`: Reference to the primary Wi-Fi adapter
- `AvailableNetworks`: Collection of discovered networks with metadata
- `ConnectionStatus`: Current connection state

**Windows API Integration**:
- Uses `netsh wlan` commands for profile management
- Leverages WMI classes for adapter detection and status monitoring
- Implements Windows credential management for authentication

### PasswordManager Class

**Purpose**: Manages password lists and implements various attack strategies

**Key Methods**:
- `LoadPasswords($filePath)`: Load and validate password list
- `GetNextPassword()`: Iterator pattern for password retrieval
- `ImplementRateLimiting()`: Control attack speed for stealth mode
- `GenerateCommonPatterns($ssid)`: Create SSID-based password variations
- `ExportResults($format, $filePath)`: Export findings to various formats

**Properties**:
- `PasswordList`: Collection of passwords to attempt
- `CurrentIndex`: Current position in password list
- `AttackStatistics`: Success/failure metrics
- `RateLimitSettings`: Timing controls for stealth operations

### UIManager Class

**Purpose**: Handles all console output, progress tracking, and user interaction

**Key Methods**:
- `DisplayBanner()`: Show application header and version
- `ShowProgress($current, $total, $eta)`: Real-time progress updates
- `DisplayNetworkInfo($networkDetails)`: Show discovered network information
- `ShowEthicalWarning()`: Display usage warnings and require acknowledgment
- `DisplayResults($statistics)`: Present final results and statistics

**Properties**:
- `ColorScheme`: ANSI color codes for consistent output formatting
- `ProgressTracker`: Real-time progress calculation and ETA estimation
- `VerbosityLevel`: Control detail level of output

### LoggingManager Class

**Purpose**: Comprehensive logging, error handling, and audit trail management

**Key Methods**:
- `LogActivity($level, $message, $details)`: Structured logging with levels
- `HandleException($exception, $context)`: Centralized exception processing
- `CreateAuditTrail()`: Generate comprehensive activity logs
- `ExportLogs($format, $destination)`: Export logs in various formats

**Properties**:
- `LogLevel`: Current logging verbosity
- `AuditTrail`: Collection of all activities for compliance
- `ErrorStatistics`: Categorized error tracking

### SecurityManager Class

**Purpose**: Implements ethical usage enforcement and safety features

**Key Methods**:
- `DisplayEthicalWarning()`: Show legal disclaimers and usage warnings
- `DetectSuspiciousPatterns()`: Monitor for potential misuse
- `ImplementSafetyLimits()`: Enforce rate limiting and connection limits
- `GenerateComplianceReport()`: Create audit documentation

**Properties**:
- `EthicalAcknowledgment`: User consent tracking
- `SafetyLimits`: Configurable limits for responsible usage
- `ComplianceSettings`: Legal and ethical configuration options

## Data Models

### NetworkProfile Class

```powershell
class NetworkProfile {
    [string]$SSID
    [string]$EncryptionType
    [int]$SignalStrength
    [string]$AuthenticationMethod
    [bool]$IsConnectable
    [datetime]$LastSeen
}
```

### ConnectionAttempt Class

```powershell
class ConnectionAttempt {
    [string]$SSID
    [string]$Password
    [datetime]$Timestamp
    [bool]$Success
    [string]$ErrorMessage
    [timespan]$Duration
}
```

### AttackStatistics Class

```powershell
class AttackStatistics {
    [int]$TotalAttempts
    [int]$SuccessfulConnections
    [int]$FailedAttempts
    [timespan]$TotalDuration
    [hashtable]$ErrorBreakdown
}
```

## Error Handling

### Exception Hierarchy

1. **WifadeException**: Base exception class for all application errors
2. **NetworkException**: Wi-Fi adapter and connection-related errors
3. **ConfigurationException**: File and parameter validation errors
4. **SecurityException**: Ethical usage and safety violations

### Error Recovery Strategies

- **Network Failures**: Automatic retry with exponential backoff
- **File Access Issues**: Graceful degradation with user notification
- **Adapter Problems**: Automatic adapter re-detection and failover
- **Authentication Failures**: Detailed logging without credential exposure

### Logging Strategy

- **Debug Level**: Detailed technical information for troubleshooting
- **Info Level**: General operation status and progress updates
- **Warning Level**: Non-critical issues that don't stop execution
- **Error Level**: Critical failures requiring user attention
- **Audit Level**: All security-relevant activities for compliance



## Design Decisions and Rationales

### Object-Oriented Architecture

**Decision**: Implement full OOP design with classes and interfaces
**Rationale**: Improves maintainability, testability, and extensibility compared to procedural PowerShell scripts. Enables better error handling and code reuse.

### Windows Native APIs

**Decision**: Use netsh, WMI, and Windows credential management instead of third-party tools
**Rationale**: Ensures compatibility across Windows versions, eliminates external dependencies, and provides better integration with Windows security features.

### Modular Design

**Decision**: Separate concerns into distinct manager classes
**Rationale**: Enables independent testing, easier maintenance, and future extensibility for new features like additional attack methods or export formats.

### Comprehensive Logging

**Decision**: Implement detailed audit trails and structured logging
**Rationale**: Supports ethical usage requirements, enables troubleshooting, and provides compliance documentation for security testing activities.

### Safety-First Approach

**Decision**: Build in ethical usage enforcement and safety features
**Rationale**: Prevents tool misuse, demonstrates responsible security tool development, and provides legal protection through documented ethical usage requirements.

### Future Extensibility

**Decision**: Design plugin-like architecture for attack methods and export formats
**Rationale**: Enables easy addition of new features without modifying core code, supports the roadmap for enhanced capabilities, and maintains backward compatibility.