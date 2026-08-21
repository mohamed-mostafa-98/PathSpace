using System.Text.Json.Serialization;

namespace PathSpace.Contracts;

public sealed record ScanMessage(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("scanId")] string ScanId,
    [property: JsonPropertyName("timestamp")] DateTimeOffset Timestamp);

public sealed record ScanProgress(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("scanId")] string ScanId,
    [property: JsonPropertyName("currentPath")] string CurrentPath,
    [property: JsonPropertyName("logicalBytes")] long LogicalBytes,
    [property: JsonPropertyName("fileCount")] long FileCount,
    [property: JsonPropertyName("directoryCount")] long DirectoryCount);

public sealed record ScanSnapshot(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("targetPath")] string TargetPath,
    [property: JsonPropertyName("complete")] bool Complete,
    [property: JsonPropertyName("cancelled")] bool Cancelled,
    [property: JsonPropertyName("logicalBytes")] long LogicalBytes,
    [property: JsonPropertyName("fileCount")] long FileCount,
    [property: JsonPropertyName("directoryCount")] long DirectoryCount,
    [property: JsonPropertyName("aggregates")] IReadOnlyList<StorageAggregate> Aggregates,
    [property: JsonPropertyName("largeFiles")] IReadOnlyList<LargeFileEntry> LargeFiles,
    [property: JsonPropertyName("warnings")] IReadOnlyList<ScanWarning> Warnings,
    [property: JsonPropertyName("scanId")] string ScanId = "");

public sealed record StorageAggregate(
    [property: JsonPropertyName("path")] string Path,
    [property: JsonPropertyName("logicalBytes")] long LogicalBytes,
    [property: JsonPropertyName("fileCount")] long FileCount,
    [property: JsonPropertyName("directoryCount")] long DirectoryCount);

public sealed record LargeFileEntry(
    [property: JsonPropertyName("path")] string Path,
    [property: JsonPropertyName("logicalBytes")] long LogicalBytes,
    [property: JsonPropertyName("lastWriteTimeUtc")] DateTimeOffset LastWriteTimeUtc);

public sealed record ScanWarning(
    [property: JsonPropertyName("path")] string Path,
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("message")] string Message);
