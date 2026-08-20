using System.Text.Json.Serialization;

namespace PathSpace.Contracts;

public enum RecoveryRisk
{
    Low,
    Medium,
    High
}

public enum Reversibility
{
    Reversible,
    BackupRecommended,
    Irreversible
}

public sealed record Recommendation(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("summary")] string Summary,
    [property: JsonPropertyName("evidence")] IReadOnlyList<string> Evidence,
    [property: JsonPropertyName("estimatedMinBytes")] long EstimatedMinBytes,
    [property: JsonPropertyName("estimatedMaxBytes")] long EstimatedMaxBytes,
    [property: JsonPropertyName("risk")] RecoveryRisk Risk,
    [property: JsonPropertyName("reversibility")] Reversibility Reversibility,
    [property: JsonPropertyName("requiresElevation")] bool RequiresElevation,
    [property: JsonPropertyName("priority")] int Priority);
