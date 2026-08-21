using System.Security.Cryptography;
using System.Text.Json;

namespace PathSpace.Contracts;

public static class ActionManifestDigest
{
    public static string Create(ActionManifest manifest)
    {
        var canonical = JsonSerializer.SerializeToUtf8Bytes(new
        {
            manifest.SchemaVersion, manifest.Kind, manifest.ActionId, manifest.Nonce,
            manifest.CreatedAt, manifest.ExpiresAt, manifest.Targets
        });
        return Convert.ToHexString(SHA256.HashData(canonical));
    }
}
