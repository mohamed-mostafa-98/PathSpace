using PathSpace.Contracts;

namespace PathSpace.App;

public sealed record StorageRow(string Path, long Bytes, string DisplaySize, long FileCount, long DirectoryCount);
public sealed record LargeFileRow(string Path, long Bytes, string DisplaySize, DateTimeOffset LastWriteTimeUtc);

public sealed class ResultViewModel
{
    public required IReadOnlyList<StorageRow> Categories { get; init; }
    public required IReadOnlyList<LargeFileRow> LargeFiles { get; init; }
    public required IReadOnlyList<ScanWarning> Warnings { get; init; }
    public bool IsComplete { get; init; }

    public static ResultViewModel FromSnapshot(ScanSnapshot snapshot) => new()
    {
        Categories = snapshot.Aggregates
            .OrderByDescending(value => value.LogicalBytes)
            .ThenBy(value => value.Path, StringComparer.OrdinalIgnoreCase)
            .Select(value => new StorageRow(value.Path, value.LogicalBytes, ByteFormatter.Format(value.LogicalBytes), value.FileCount, value.DirectoryCount))
            .ToArray(),
        LargeFiles = snapshot.LargeFiles
            .OrderByDescending(value => value.LogicalBytes)
            .ThenBy(value => value.Path, StringComparer.OrdinalIgnoreCase)
            .Select(value => new LargeFileRow(value.Path, value.LogicalBytes, ByteFormatter.Format(value.LogicalBytes), value.LastWriteTimeUtc))
            .ToArray(),
        Warnings = snapshot.Warnings,
        IsComplete = snapshot.Complete
    };
}

public static class ByteFormatter
{
    private static readonly string[] Units = ["B", "KB", "MB", "GB", "TB", "PB"];
    public static string Format(long bytes)
    {
        var value = Math.Max(0, bytes);
        var unit = 0;
        var display = (double)value;
        while (display >= 1024 && unit < Units.Length - 1) { display /= 1024; unit++; }
        return $"{display:0.##} {Units[unit]}";
    }
}
