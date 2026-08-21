using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using PathSpace.Contracts;

namespace PathSpace.App;

public interface IEngineClient
{
    Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken);
    Task<IReadOnlyList<Recommendation>> RecommendAsync(ScanSnapshot snapshot, CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<Recommendation>>([]);
    Task<IReadOnlyList<Recommendation>> RecommendAsync(ScanSnapshot snapshot, IReadOnlyList<AppDiagnostic> diagnostics, CancellationToken cancellationToken) => RecommendAsync(snapshot, cancellationToken);
    Task<IReadOnlyList<AppDiagnostic>> DiagnoseAsync(CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<AppDiagnostic>>([]);
    Task<IReadOnlyList<AppDiagnostic>> DiagnoseProtectedAsync(CancellationToken cancellationToken) => DiagnoseAsync(cancellationToken);
    Task<ActionPreview> PreviewAsync(string actionId, string? driveLetter, CancellationToken cancellationToken) => throw new NotSupportedException();
}

public sealed class EngineClient : IEngineClient
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true, Converters = { new JsonStringEnumConverter() } };
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

    public async Task<IReadOnlyList<Recommendation>> RecommendAsync(ScanSnapshot snapshot, CancellationToken cancellationToken)
        => await RecommendAsync(snapshot, [], cancellationToken);

    public async Task<IReadOnlyList<Recommendation>> RecommendAsync(ScanSnapshot snapshot, IReadOnlyList<AppDiagnostic> diagnostics, CancellationToken cancellationToken)
    {
        var input = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.snapshot.json");
        var diagnosticsInput = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.diagnostics.json");
        await File.WriteAllTextAsync(input, JsonSerializer.Serialize(snapshot, JsonOptions), cancellationToken);
        await File.WriteAllTextAsync(diagnosticsInput, JsonSerializer.Serialize(diagnostics, JsonOptions), cancellationToken);
        try { return await RunJsonLinesAsync<Recommendation>(["recommend", "-InputPath", input, "-DiagnosticsPath", diagnosticsInput], "recommendation", cancellationToken); }
        finally { File.Delete(input); File.Delete(diagnosticsInput); }
    }

    public Task<IReadOnlyList<AppDiagnostic>> DiagnoseAsync(CancellationToken cancellationToken) =>
        RunJsonLinesAsync<AppDiagnostic>(["diagnose"], "app.diagnostic", cancellationToken);

    public async Task<IReadOnlyList<AppDiagnostic>> DiagnoseProtectedAsync(CancellationToken cancellationToken)
    {
        var output = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.diagnostics.jsonl");
        var info = new ProcessStartInfo("powershell.exe") { UseShellExecute=true,Verb="runas" };
        foreach(var argument in new[]{"-NoProfile","-ExecutionPolicy","Bypass","-File",_cliPath,"diagnose","-OutputPath",output}) info.ArgumentList.Add(argument);
        try
        {
            using var process=Process.Start(info) ?? throw new InvalidOperationException("Protected diagnostics did not start.");
            await process.WaitForExitAsync(cancellationToken);
            if(process.ExitCode!=0) throw new InvalidOperationException("Protected diagnostics reported a failure.");
            if(!File.Exists(output)) throw new InvalidDataException("Protected diagnostics produced no output.");
            var values=new List<AppDiagnostic>();
            foreach(var line in await File.ReadAllLinesAsync(output,cancellationToken))
                if(!string.IsNullOrWhiteSpace(line)) values.Add(JsonSerializer.Deserialize<AppDiagnostic>(line,JsonOptions) ?? throw new JsonException("Empty diagnostic message."));
            return values;
        }
        catch(System.ComponentModel.Win32Exception exception) when(exception.NativeErrorCode==1223)
        { throw new OperationCanceledException("Administrator approval was cancelled; no protected scan was run.",exception,cancellationToken); }
        finally { File.Delete(output); }
    }

    public async Task<ActionPreview> PreviewAsync(string actionId, string? driveLetter, CancellationToken cancellationToken)
    {
        var arguments = new List<string> { "preview", "-ActionId", actionId };
        if (!string.IsNullOrWhiteSpace(driveLetter)) { arguments.Add("-DriveLetter"); arguments.Add(driveLetter); }
        var result = await RunJsonLinesAsync<ActionPreview>(arguments, "action.preview", cancellationToken);
        return result.Single();
    }

    private async Task<IReadOnlyList<T>> RunJsonLinesAsync<T>(IEnumerable<string> commandArguments, string expectedKind, CancellationToken cancellationToken)
    {
        var info = new ProcessStartInfo { FileName="powershell.exe",UseShellExecute=false,RedirectStandardOutput=true,RedirectStandardError=true,CreateNoWindow=true };
        foreach(var argument in new[]{"-NoProfile","-ExecutionPolicy","Bypass","-File",_cliPath}) info.ArgumentList.Add(argument);
        foreach(var argument in commandArguments) info.ArgumentList.Add(argument);
        using var process=Process.Start(info) ?? throw new InvalidOperationException("The PathSpace engine could not be started.");
        var values=new List<T>();
        while(await process.StandardOutput.ReadLineAsync(cancellationToken) is { } line)
        {
            if(string.IsNullOrWhiteSpace(line)) continue;
            using var document=JsonDocument.Parse(line);
            var kind=document.RootElement.GetProperty("kind").GetString();
            if(kind=="scan.error") throw new InvalidOperationException(document.RootElement.GetProperty("message").GetString());
            if(kind==expectedKind) values.Add(JsonSerializer.Deserialize<T>(line,JsonOptions) ?? throw new JsonException($"Empty {expectedKind} message."));
        }
        var error=await process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        if(process.ExitCode!=0) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error)?"The PathSpace engine failed.":error.Trim());
        return values;
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
