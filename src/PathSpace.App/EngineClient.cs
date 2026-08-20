using System.Diagnostics;
using System.IO;
using System.Text.Json;
using PathSpace.Contracts;

namespace PathSpace.App;

public interface IEngineClient
{
    Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken);
}

public sealed class EngineClient : IEngineClient
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private readonly string _cliPath;

    public EngineClient(string? cliPath = null) =>
        _cliPath = cliPath ?? Path.Combine(AppContext.BaseDirectory, "cli", "pathspace.ps1");

    public async Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken)
    {
        var cancellationFile = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.cancel");
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _cliPath, "scan", "-LiteralPath", target, "-CancellationFile", cancellationFile })
            startInfo.ArgumentList.Add(argument);

        using var process = new Process { StartInfo = startInfo };
        if (!process.Start()) throw new InvalidOperationException("The PathSpace analysis engine could not be started.");
        using var registration = cancellationToken.Register(static state => File.WriteAllText((string)state!, "cancel"), cancellationFile);
        try
        {
            var stderrTask = process.StandardError.ReadToEndAsync();
            var snapshot = await ParseJsonLinesAsync(process.StandardOutput, progress, CancellationToken.None);
            await process.WaitForExitAsync(CancellationToken.None);
            var stderr = await stderrTask;
            if (process.ExitCode != 0)
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(stderr) ? "The PathSpace analysis engine failed." : stderr.Trim());
            return snapshot;
        }
        finally
        {
            File.Delete(cancellationFile);
        }
    }

    public static async Task<ScanSnapshot> ParseJsonLinesAsync(TextReader reader, IProgress<ScanProgress> progress, CancellationToken cancellationToken)
    {
        ScanSnapshot? snapshot = null;
        while (await reader.ReadLineAsync(cancellationToken) is { } line)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            using var document = JsonDocument.Parse(line);
            var kind = document.RootElement.GetProperty("kind").GetString();
            if (kind == "scan.progress")
                progress.Report(JsonSerializer.Deserialize<ScanProgress>(line, JsonOptions) ?? throw new JsonException("Progress message was empty."));
            else if (kind == "scan.snapshot")
                snapshot = JsonSerializer.Deserialize<ScanSnapshot>(line, JsonOptions);
            else if (kind == "scan.error")
                throw new InvalidOperationException(document.RootElement.TryGetProperty("message", out var value) ? value.GetString() : "The analysis engine reported an error.");
        }
        return snapshot ?? throw new InvalidDataException("The analysis engine ended without a final snapshot.");
    }
}
