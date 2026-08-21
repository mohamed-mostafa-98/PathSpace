# Third-party notices

PathSpace application binaries use the [.NET 8 runtime](https://github.com/dotnet/runtime), licensed by Microsoft under the MIT License. Framework components may include their own notices in the installed .NET runtime distribution.

The development and test toolchain uses the following packages. They are not shipped as PathSpace application code in the framework-dependent portable package unless a package explicitly becomes a runtime dependency:

| Component | Version | Purpose | License |
|---|---:|---|---|
| JsonSchema.Net | 7.3.4 | JSON Schema contract tests | MIT |
| Microsoft.NET.Test.Sdk | 17.11.1 | .NET test host | MIT |
| xUnit.net | 2.9.2 | Unit testing | Apache-2.0 |
| xunit.runner.visualstudio | 2.8.2 | Visual Studio test adapter | Apache-2.0 |
| coverlet.collector | 6.0.2 | Test coverage collection | MIT |

PowerShell and Pester may be used to run the CLI and engine tests on the developer or user machine. Their licenses remain with their respective projects.

The PathSpace icon is original project artwork generated for PathSpace on 2026-08-21. It contains no third-party logo or trademark.
