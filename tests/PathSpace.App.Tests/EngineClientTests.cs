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

    private sealed class InlineProgress<T>(Action<T> report) : IProgress<T>
    {
        public void Report(T value) => report(value);
    }
}
