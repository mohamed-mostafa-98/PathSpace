using System.ComponentModel;
using System.Diagnostics;
using System.IO;

namespace PathSpace.App;

public sealed record LaunchResult(bool Started, bool Cancelled, int? ExitCode, string Message);

public static class ElevatedActionLauncher
{
    public static async Task<LaunchResult> LaunchConfirmedAsync(string workerPath, string manifestPath, string resultPath)
    {
        if (!Path.IsPathFullyQualified(workerPath) || !Path.IsPathFullyQualified(manifestPath) || !Path.IsPathFullyQualified(resultPath))
            throw new ArgumentException("Worker, manifest, and result paths must be absolute.");
        var info = new ProcessStartInfo(workerPath) { UseShellExecute = true, Verb = "runas" };
        info.ArgumentList.Add("--manifest"); info.ArgumentList.Add(manifestPath);
        info.ArgumentList.Add("--result"); info.ArgumentList.Add(resultPath);
        try
        {
            using var process = Process.Start(info) ?? throw new InvalidOperationException("Elevated worker did not start.");
            await process.WaitForExitAsync();
            return new LaunchResult(true, false, process.ExitCode, process.ExitCode == 0 ? "Action completed." : "Action worker reported a failure.");
        }
        catch (Win32Exception exception) when (exception.NativeErrorCode == 1223)
        {
            return new LaunchResult(false, true, null, "Administrator approval was cancelled; no action was taken.");
        }
    }
}
