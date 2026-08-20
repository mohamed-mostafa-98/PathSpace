using System.Text.Json.Serialization;

namespace PathSpace.Contracts;

public sealed record ActionTarget(
    [property: JsonPropertyName("targetId")] string TargetId,
    [property: JsonPropertyName("path")] string Path,
    [property: JsonPropertyName("requiresElevation")] bool RequiresElevation);

public sealed record ActionPreview(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("actionId")] string ActionId,
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("targets")] IReadOnlyList<ActionTarget> Targets,
    [property: JsonPropertyName("estimatedBytes")] long EstimatedBytes,
    [property: JsonPropertyName("risk")] RecoveryRisk Risk,
    [property: JsonPropertyName("reversibility")] Reversibility Reversibility,
    [property: JsonPropertyName("requiresElevation")] bool RequiresElevation);

public sealed record ActionManifest(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("actionId")] string ActionId,
    [property: JsonPropertyName("nonce")] string Nonce,
    [property: JsonPropertyName("createdAt")] DateTimeOffset CreatedAt,
    [property: JsonPropertyName("expiresAt")] DateTimeOffset ExpiresAt,
    [property: JsonPropertyName("targets")] IReadOnlyList<ActionTarget> Targets,
    [property: JsonPropertyName("digest")] string Digest);

public sealed record ActionResult(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("actionId")] string ActionId,
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("recoveredBytes")] long RecoveredBytes,
    [property: JsonPropertyName("targetsProcessed")] long TargetsProcessed,
    [property: JsonPropertyName("targetsSkipped")] long TargetsSkipped,
    [property: JsonPropertyName("messages")] IReadOnlyList<string> Messages);
