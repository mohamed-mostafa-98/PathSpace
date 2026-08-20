// See https://aka.ms/new-console-template for more information
using System.Diagnostics;
using System.Text.Json;
using PathSpace.Contracts;
using PathSpace.Worker;

if (!TryGetArgument(args, "--manifest", out var manifestPath) || !TryGetArgument(args, "--result", out var resultPath)) return 2;
if (!Path.IsPathFullyQualified(manifestPath) || !Path.IsPathFullyQualified(resultPath)) return 2;
try
{
    var bytes = await File.ReadAllBytesAsync(manifestPath);
    var manifest = JsonSerializer.Deserialize<ActionManifest>(bytes, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new InvalidDataException("Action manifest is empty.");
    ManifestValidator.Validate(manifest, bytes);
    var scriptPath = Path.Combine(AppContext.BaseDirectory, "cli", "worker-action.ps1");
    var startInfo = new ProcessStartInfo("powershell.exe") { UseShellExecute=false, RedirectStandardOutput=true, RedirectStandardError=true, CreateNoWindow=true };
    foreach (var argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, "-ActionId", manifest.ActionId }) startInfo.ArgumentList.Add(argument);
    if (manifest.ActionId == "volume.optimize") { startInfo.ArgumentList.Add("-DriveLetter"); startInfo.ArgumentList.Add(manifest.Targets[0].Path[..1]); }
    using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Action process could not start.");
    var outputTask = process.StandardOutput.ReadToEndAsync();
    var errorTask = process.StandardError.ReadToEndAsync();
    await process.WaitForExitAsync();
    var output = await outputTask;
    var error = await errorTask;
    if (process.ExitCode != 0) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? "Action process failed." : error.Trim());
    await File.WriteAllTextAsync(resultPath, output);
    return 0;
}
catch (Exception exception)
{
    var failure = new ActionResult(1, "action.result", "unknown", "failed", 0, 0, 1, [exception.Message]);
    await File.WriteAllTextAsync(resultPath, JsonSerializer.Serialize(failure));
    return 1;
}

static bool TryGetArgument(string[] values, string name, out string value)
{
    var index = Array.IndexOf(values, name);
    value = index >= 0 && index + 1 < values.Length ? values[index + 1] : string.Empty;
    return value.Length > 0;
}
