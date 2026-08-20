using System.Text.Json;
using PathSpace.Contracts;
using Xunit;

namespace PathSpace.Contracts.Tests;

public sealed class ContractSerializationTests
{
    [Fact]
    public void Snapshot_round_trips_with_schema_version()
    {
        var source = new ScanSnapshot(
            1,
            "scan.snapshot",
            @"C:\",
            true,
            false,
            42,
            1,
            0,
            [],
            [],
            []);

        var json = JsonSerializer.Serialize(source);
        var result = JsonSerializer.Deserialize<ScanSnapshot>(json)!;

        Assert.Equal(1, result.SchemaVersion);
        Assert.Equal("scan.snapshot", result.Kind);
        Assert.Equal(42, result.LogicalBytes);
    }

    [Fact]
    public void Action_manifest_round_trips_with_stable_action_identity()
    {
        var createdAt = DateTimeOffset.Parse("2026-08-20T12:00:00Z");
        var source = new ActionManifest(
            1,
            "action.manifest",
            "cache.npm",
            "nonce-1",
            createdAt,
            createdAt.AddMinutes(5),
            [new ActionTarget("target-1", @"C:\Users\Example\AppData\Local\npm-cache", false)],
            "ABCDEF");

        var json = JsonSerializer.Serialize(source);
        var result = JsonSerializer.Deserialize<ActionManifest>(json)!;

        Assert.Equal("cache.npm", result.ActionId);
        Assert.Equal("target-1", Assert.Single(result.Targets).TargetId);
    }
}
