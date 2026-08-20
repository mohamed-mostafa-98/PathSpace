using PathSpace.App;
using PathSpace.Contracts;

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
}
