using PathSpace.App;
using PathSpace.Contracts;
using System.Text.Json;

namespace PathSpace.App.Tests;

public sealed class ReportExporterTests
{
    [Fact]
    public void Redacted_export_replaces_profile_prefix_and_csv_escapes_paths()
    {
        var snapshot = new ScanSnapshot(1, "scan.snapshot", @"C:\Users\Example", true, false, 1, 1, 0,
            [new StorageAggregate("C:\\Users\\Example\\Data,One", 1, 1, 0)], [], []);
        var json = ReportExporter.ExportRedactedJson(snapshot, @"C:\Users\Example");
        var csv = ReportExporter.ExportCsv(snapshot);
        Assert.Contains("%USERPROFILE%", json);
        Assert.DoesNotContain(@"C:\Users\Example", json, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("\"C:\\Users\\Example\\Data,One\"", csv);
    }

    [Fact]
    public void Local_audit_log_rotates_at_the_bounded_size()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pathspace-log-{Guid.NewGuid():N}");
        try
        {
            var log = new LocalAuditLog(directory);
            log.Append(new string('x', 5 * 1024 * 1024));
            log.Append("next");
            Assert.True(File.Exists(Path.Combine(directory, "pathspace-0.jsonl")));
            Assert.True(File.Exists(Path.Combine(directory, "pathspace-1.jsonl")));
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }

    [Fact]
    public void Local_audit_log_writes_structured_versioned_events()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pathspace-log-{Guid.NewGuid():N}");
        try
        {
            var log = new LocalAuditLog(directory);
            log.Record("scan", "completed", new { fileCount = 2 });
            using var entry = JsonDocument.Parse(File.ReadAllLines(Path.Combine(directory, "pathspace-0.jsonl"))[0]);
            Assert.Equal(1, entry.RootElement.GetProperty("schemaVersion").GetInt32());
            Assert.Equal("audit.event", entry.RootElement.GetProperty("kind").GetString());
            Assert.Equal("scan", entry.RootElement.GetProperty("eventName").GetString());
            Assert.Equal(2, entry.RootElement.GetProperty("details").GetProperty("fileCount").GetInt32());
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }

    [Fact]
    public void Audit_write_failure_does_not_fail_the_primary_workflow()
    {
        var file = Path.GetTempFileName();
        try
        {
            var log = new LocalAuditLog(file);
            var exception = Record.Exception(() => log.Record("scan", "completed"));
            Assert.Null(exception);
        }
        finally { File.Delete(file); }
    }
}
