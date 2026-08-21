using System.Diagnostics;
using System.IO;
using System.Text.Json;
using PathSpace.Contracts;

namespace PathSpace.App;

public sealed class WorkerActionExecutor(string? workerPath = null) : IActionExecutor
{
    private readonly string _workerPath = workerPath ?? Path.Combine(AppContext.BaseDirectory, "worker", "PathSpace.Worker.exe");

    public async Task<ActionResult> ExecuteAsync(ActionPreview preview, CancellationToken cancellationToken)
    {
        var manifestPath = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.manifest.json");
        var resultPath = Path.Combine(Path.GetTempPath(), $"pathspace-{Guid.NewGuid():N}.result.json");
        var now = DateTimeOffset.UtcNow;
        var manifest = new ActionManifest(1, "action.manifest", preview.ActionId, Guid.NewGuid().ToString("N"), now, now.AddMinutes(5), preview.Targets, string.Empty);
        manifest = manifest with { Digest = ActionManifestDigest.Create(manifest) };
        await File.WriteAllTextAsync(manifestPath, JsonSerializer.Serialize(manifest), cancellationToken);
        try
        {
            if (preview.RequiresElevation)
            {
                var launch = await ElevatedActionLauncher.LaunchConfirmedAsync(_workerPath, manifestPath, resultPath);
                if (launch.Cancelled) return new ActionResult(1, "action.result", preview.ActionId, "cancelled", 0, 0, 0, [launch.Message]);
            }
            else
            {
                var info = new ProcessStartInfo(_workerPath) { UseShellExecute=false,CreateNoWindow=true };
                info.ArgumentList.Add("--manifest"); info.ArgumentList.Add(manifestPath);
                info.ArgumentList.Add("--result"); info.ArgumentList.Add(resultPath);
                using var process=Process.Start(info) ?? throw new InvalidOperationException("Action worker did not start.");
                await process.WaitForExitAsync(cancellationToken);
            }
            if (!File.Exists(resultPath)) throw new InvalidDataException("Action worker did not create a result.");
            return JsonSerializer.Deserialize<ActionResult>(await File.ReadAllTextAsync(resultPath, cancellationToken), new JsonSerializerOptions { PropertyNameCaseInsensitive=true })
                ?? throw new InvalidDataException("Action result was empty.");
        }
        finally
        {
            File.Delete(manifestPath);
            File.Delete(resultPath);
        }
    }
}

public sealed class EngineActionVerifier(IEngineClient engine) : IActionVerifier
{
    public async Task<ScanSnapshot?> VerifyAsync(ActionPreview preview, CancellationToken cancellationToken)
    {
        var path = preview.Targets.Select(value => value.Path).FirstOrDefault(Directory.Exists);
        if (path is null) return null;
        return await engine.ScanAsync(path, new Progress<ScanProgress>(), cancellationToken);
    }
}
