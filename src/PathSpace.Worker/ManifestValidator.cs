using System.Security.Cryptography;
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
}
