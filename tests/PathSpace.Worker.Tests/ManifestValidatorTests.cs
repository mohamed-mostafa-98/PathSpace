using System.Text;
using PathSpace.Contracts;
using PathSpace.Worker;

namespace PathSpace.Worker.Tests;

public sealed class ManifestValidatorTests
{
    [Fact]
    public void Valid_manifest_passes_and_tampered_target_fails_digest()
    {
        var manifest = ValidManifest("temp.user", @"C:\Users\Example\AppData\Local\Temp");
        ManifestValidator.Validate(manifest, Encoding.UTF8.GetBytes("fixture"), DateTimeOffset.UtcNow);
        var tampered = manifest with { Targets = [manifest.Targets[0] with { Path = @"C:\Windows" }] };
        Assert.Throws<InvalidDataException>(() => ManifestValidator.Validate(tampered, [], DateTimeOffset.UtcNow));
    }

    [Theory]
    [InlineData("unknown.action", "C:\\Data")]
    [InlineData("temp.user", "\\\\server\\share")]
    [InlineData("temp.user", "C:\\")]
    public void Unsafe_action_or_scope_is_rejected(string actionId, string path)
    {
        var manifest = ValidManifest(actionId, path);
        Assert.ThrowsAny<Exception>(() => ManifestValidator.Validate(manifest, [], DateTimeOffset.UtcNow));
    }

    [Fact]
    public void Expired_or_long_lived_manifest_is_rejected()
    {
        var manifest = ValidManifest("temp.user", @"C:\Users\Example\Temp") with
        { CreatedAt = DateTimeOffset.UtcNow.AddMinutes(-10), ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-5) };
        manifest = manifest with { Digest = ManifestValidator.CreateDigest(manifest) };
        Assert.Throws<InvalidDataException>(() => ManifestValidator.Validate(manifest, [], DateTimeOffset.UtcNow));
    }

    private static ActionManifest ValidManifest(string actionId, string path)
    {
        var now = DateTimeOffset.UtcNow;
        var manifest = new ActionManifest(1, "action.manifest", actionId, Guid.NewGuid().ToString("N"), now, now.AddMinutes(5), [new ActionTarget("target", path, false)], "");
        return manifest with { Digest = ManifestValidator.CreateDigest(manifest) };
    }
}
