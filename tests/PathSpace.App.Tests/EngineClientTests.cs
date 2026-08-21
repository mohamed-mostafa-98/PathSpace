using PathSpace.App;
using PathSpace.Contracts;

namespace PathSpace.App.Tests;

public sealed class EngineClientTests
{
    [Fact]
    public async Task Jsonl_parser_reports_progress_before_returning_snapshot()
    {
        const string input = """
            {"schemaVersion":1,"kind":"scan.progress","scanId":"one","currentPath":"C:\\Data","logicalBytes":10,"fileCount":1,"directoryCount":0}
            {"schemaVersion":1,"kind":"scan.snapshot","targetPath":"C:\\Data","complete":true,"cancelled":false,"logicalBytes":10,"fileCount":1,"directoryCount":0,"aggregates":[],"largeFiles":[],"warnings":[]}
            """;
        var progressValues = new List<ScanProgress>();

        var snapshot = await EngineClient.ParseJsonLinesAsync(
            new StringReader(input),
            new InlineProgress<ScanProgress>(progressValues.Add),
            CancellationToken.None);

        Assert.Single(progressValues);
        Assert.Equal(10, progressValues[0].LogicalBytes);
        Assert.Equal(10, snapshot.LogicalBytes);
    }

    [Fact]
    public async Task Real_cli_scans_recommends_and_previews_without_shell_concatenation()
    {
        var cli = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "cli", "pathspace.ps1"));
        var root = Path.Combine(Path.GetTempPath(), $"pathspace-engine-{Guid.NewGuid():N}");
        Directory.CreateDirectory(Path.Combine(root, "npm-cache"));
        await File.WriteAllBytesAsync(Path.Combine(root, "npm-cache", "package.bin"), new byte[32]);
        try
        {
            var client = new EngineClient(cli);
            var snapshot = await client.ScanAsync(root, new InlineProgress<ScanProgress>(_ => { }), CancellationToken.None);
            var recommendations = await client.RecommendAsync(snapshot, CancellationToken.None);
            var preview = await client.PreviewAsync("volume.optimize", "C", CancellationToken.None);

            Assert.True(snapshot.Complete);
            Assert.Contains(recommendations, value => value.Id == "cache.npm");
            Assert.Equal("volume.optimize", preview.ActionId);
            Assert.Equal(@"C:\", Assert.Single(preview.Targets).Path);
        }
        finally { Directory.Delete(root, true); }
    }

    private sealed class InlineProgress<T>(Action<T> report) : IProgress<T>
    {
        public void Report(T value) => report(value);
    }
}
