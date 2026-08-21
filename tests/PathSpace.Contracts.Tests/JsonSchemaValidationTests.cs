using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Json.Schema;
using PathSpace.Contracts;
using Xunit;

namespace PathSpace.Contracts.Tests;

public sealed class JsonSchemaValidationTests
{
    private static readonly JsonSerializerOptions Options = new() { Converters = { new JsonStringEnumConverter() } };
    private static readonly string SchemaDirectory = FindSchemaDirectory();

    public static IEnumerable<object[]> ValidContracts()
    {
        var now = DateTimeOffset.UtcNow;
        var target = new ActionTarget("temp", @"C:\Users\Example\Temp", false);
        var unsigned = new ActionManifest(1, "action.manifest", "temp.user", Guid.NewGuid().ToString("N"), now, now.AddMinutes(5), [target], string.Empty);
        var manifest = unsigned with { Digest = ActionManifestDigest.Create(unsigned) };
        using var diagnosticData = JsonDocument.Parse("{\"bytes\":42}");
        yield return ["scan-message.v1.schema.json", new ScanProgress(1, "scan.progress", "scan-1", @"C:\Data", 1, 1, 1)];
        yield return ["scan-message.v1.schema.json", new ScanSnapshot(1, "scan.snapshot", @"C:\Data", true, false, 1, 1, 0, [], [], [], "scan-1")];
        yield return ["recommendation.v1.schema.json", new Recommendation(1, "recommendation", "temp.user", "Temporary files", "Review", ["Measured"], 0, 10, RecoveryRisk.Low, Reversibility.Irreversible, false, 1, true)];
        yield return ["app-diagnostic.v1.schema.json", new AppDiagnostic(1, "app.diagnostic", "pagefile", true, diagnosticData.RootElement.Clone(), "Measured locally")];
        yield return ["action-preview.v1.schema.json", new ActionPreview(1, "action.preview", "temp.user", "Temporary files", [target], 10, RecoveryRisk.Low, Reversibility.Irreversible, false)];
        yield return ["action-manifest.v1.schema.json", manifest];
        yield return ["action-result.v1.schema.json", new ActionResult(1, "action.result", "temp.user", "completed", 10, 1, 0, [])];
        yield return ["audit-event.v1.schema.json", JsonNode.Parse("{\"schemaVersion\":1,\"kind\":\"audit.event\",\"timestamp\":\"2026-08-21T00:00:00Z\",\"eventName\":\"scan\",\"outcome\":\"completed\",\"details\":{}}")!];
    }

    [Theory]
    [MemberData(nameof(ValidContracts))]
    public void Versioned_contract_matches_its_schema(string schemaFile, object value)
    {
        var schema = JsonSchema.FromText(File.ReadAllText(Path.Combine(SchemaDirectory, schemaFile)));
        var node = value as JsonNode ?? JsonSerializer.SerializeToNode(value, value.GetType(), Options)!;
        var result = schema.Evaluate(node, new EvaluationOptions { OutputFormat = OutputFormat.List });
        Assert.True(result.IsValid, $"{schemaFile}: {JsonSerializer.Serialize(result)}");
    }

    [Fact]
    public void Schemas_reject_unknown_properties_and_wrong_discriminators()
    {
        var schema = JsonSchema.FromText(File.ReadAllText(Path.Combine(SchemaDirectory, "action-result.v1.schema.json")));
        var invalid = JsonNode.Parse("{\"schemaVersion\":2,\"kind\":\"action.result\",\"actionId\":\"x\",\"status\":\"completed\",\"recoveredBytes\":0,\"targetsProcessed\":0,\"targetsSkipped\":0,\"messages\":[],\"unexpected\":true}")!;
        Assert.False(schema.Evaluate(invalid).IsValid);
    }

    private static string FindSchemaDirectory()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, "schemas");
            if (Directory.Exists(candidate)) return candidate;
            directory = directory.Parent;
        }
        throw new DirectoryNotFoundException("Repository schemas directory was not found.");
    }
}
