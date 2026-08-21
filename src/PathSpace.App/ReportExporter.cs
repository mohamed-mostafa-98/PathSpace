using System.Text;
using System.Text.Json;
using System.IO;
using PathSpace.Contracts;

namespace PathSpace.App;

public static class ReportExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };
    public static string ExportJson(ScanSnapshot snapshot) => JsonSerializer.Serialize(snapshot, Options);
    public static string ExportRedactedJson(ScanSnapshot snapshot, string profilePath)
    {
        if (string.IsNullOrWhiteSpace(profilePath)) return ExportJson(snapshot);
        string Redact(string value) => value.Replace(profilePath, "%USERPROFILE%", StringComparison.OrdinalIgnoreCase);
        var redacted = snapshot with
        {
            TargetPath = Redact(snapshot.TargetPath),
            Aggregates = snapshot.Aggregates.Select(value => value with { Path = Redact(value.Path) }).ToArray(),
            LargeFiles = snapshot.LargeFiles.Select(value => value with { Path = Redact(value.Path) }).ToArray(),
            Warnings = snapshot.Warnings.Select(value => value with { Path = Redact(value.Path) }).ToArray()
        };
        return ExportJson(redacted);
    }
    public static string ExportCsv(ScanSnapshot snapshot)
    {
        var output = new StringBuilder("Path,LogicalBytes,FileCount,DirectoryCount\r\n");
        foreach (var row in snapshot.Aggregates)
            output.Append(Csv(row.Path)).Append(',').Append(row.LogicalBytes).Append(',').Append(row.FileCount).Append(',').Append(row.DirectoryCount).Append("\r\n");
        return output.ToString();
    }
    private static string Csv(string value) => $"\"{value.Replace("\"", "\"\"")}\"";
}

public interface IAuditLog
{
    void Record(string eventName, string outcome, object? details = null);
}

public sealed class LocalAuditLog(string directory) : IAuditLog
{
    private const long MaximumBytes = 5 * 1024 * 1024;
    private const int MaximumFiles = 5;
    private readonly object _sync = new();

    public void Record(string eventName, string outcome, object? details = null)
    {
        try
        {
            var entry = JsonSerializer.Serialize(new
            {
                schemaVersion = 1,
                kind = "audit.event",
                timestamp = DateTimeOffset.UtcNow,
                eventName,
                outcome,
                details
            });
            Append(entry);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    public void Append(string jsonLine)
    {
        lock (_sync)
        {
            Directory.CreateDirectory(directory);
            var current = Path.Combine(directory, "pathspace-0.jsonl");
            if (File.Exists(current) && new FileInfo(current).Length + Encoding.UTF8.GetByteCount(jsonLine) > MaximumBytes) Rotate();
            File.AppendAllText(current, jsonLine + Environment.NewLine, Encoding.UTF8);
        }
    }
    private void Rotate()
    {
        var oldest = Path.Combine(directory, $"pathspace-{MaximumFiles - 1}.jsonl");
        if (File.Exists(oldest)) File.Delete(oldest);
        for (var index = MaximumFiles - 2; index >= 0; index--)
        {
            var source = Path.Combine(directory, $"pathspace-{index}.jsonl");
            if (File.Exists(source)) File.Move(source, Path.Combine(directory, $"pathspace-{index + 1}.jsonl"));
        }
    }
}
