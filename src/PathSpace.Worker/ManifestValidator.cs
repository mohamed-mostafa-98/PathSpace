using System.Security.Cryptography;
using System.Text.Json;
using PathSpace.Contracts;

namespace PathSpace.Worker;

public static class ManifestValidator
{
    private static readonly HashSet<string> AllowedActions =
    ["temp.user", "temp.windows", "recycle.currentUser", "cache.npm", "windows.componentCleanup", "power.hibernate", "volume.optimize"];
    private static readonly HashSet<string> DeletionActions = ["temp.user", "temp.windows", "cache.npm"];

    public static string CreateDigest(ActionManifest manifest)
        => ActionManifestDigest.Create(manifest);

    public static void Validate(ActionManifest manifest, ReadOnlySpan<byte> manifestBytes, DateTimeOffset? now = null)
    {
        if (!manifestBytes.IsEmpty) ValidateJsonShape(manifestBytes);
        var current = now ?? DateTimeOffset.UtcNow;
        if (manifest.SchemaVersion != 1 || manifest.Kind != "action.manifest") throw new InvalidDataException("Unsupported action manifest schema.");
        if (!AllowedActions.Contains(manifest.ActionId)) throw new InvalidDataException("Action ID is not allow-listed.");
        if (string.IsNullOrWhiteSpace(manifest.Nonce) || manifest.Nonce.Length < 16) throw new InvalidDataException("Manifest nonce is invalid.");
        if (manifest.ExpiresAt <= current || manifest.CreatedAt > current.AddMinutes(1) || manifest.ExpiresAt - manifest.CreatedAt > TimeSpan.FromMinutes(5))
            throw new InvalidDataException("Manifest is expired or exceeds the five-minute lifetime.");
        var expected = Convert.FromHexString(CreateDigest(manifest));
        byte[] supplied;
        try { supplied = Convert.FromHexString(manifest.Digest); } catch { throw new InvalidDataException("Manifest digest is malformed."); }
        if (expected.Length != supplied.Length || !CryptographicOperations.FixedTimeEquals(expected, supplied)) throw new InvalidDataException("Manifest digest does not match its content.");
        if (manifest.Targets.Count == 0) throw new InvalidDataException("Manifest contains no targets.");
        foreach (var target in manifest.Targets)
        {
            if (string.IsNullOrWhiteSpace(target.TargetId) || string.IsNullOrWhiteSpace(target.Path)) throw new InvalidDataException("Manifest target identity is missing.");
            if (target.Path.StartsWith(@"\\", StringComparison.Ordinal) || target.Path.IndexOfAny(['*', '?', '%']) >= 0) throw new InvalidDataException("Network, wildcard, and unresolved targets are forbidden.");
            if (DeletionActions.Contains(manifest.ActionId) && Path.GetPathRoot(target.Path)?.Equals(Path.GetFullPath(target.Path), StringComparison.OrdinalIgnoreCase) == true)
                throw new InvalidDataException("Drive roots are forbidden for deletion actions.");
        }
    }

    private static void ValidateJsonShape(ReadOnlySpan<byte> manifestBytes)
    {
        using var document = JsonDocument.Parse(manifestBytes.ToArray());
        if (document.RootElement.ValueKind != JsonValueKind.Object) throw new InvalidDataException("Manifest JSON root must be an object.");
        var allowed = new HashSet<string>(StringComparer.Ordinal) { "schemaVersion","kind","actionId","nonce","createdAt","expiresAt","targets","digest" };
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in document.RootElement.EnumerateObject())
            if (!allowed.Contains(property.Name) || !seen.Add(property.Name)) throw new InvalidDataException($"Manifest contains unknown or duplicate property '{property.Name}'.");
        if (!document.RootElement.TryGetProperty("targets", out var targets) || targets.ValueKind != JsonValueKind.Array) throw new InvalidDataException("Manifest targets must be an array.");
        var targetAllowed = new HashSet<string>(StringComparer.Ordinal) { "targetId","path","requiresElevation" };
        foreach (var target in targets.EnumerateArray())
        {
            if (target.ValueKind != JsonValueKind.Object) throw new InvalidDataException("Manifest target must be an object.");
            var targetSeen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in target.EnumerateObject())
                if (!targetAllowed.Contains(property.Name) || !targetSeen.Add(property.Name)) throw new InvalidDataException($"Manifest target contains unknown or duplicate property '{property.Name}'.");
        }
    }
}
