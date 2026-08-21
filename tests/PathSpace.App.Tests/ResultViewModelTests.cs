using PathSpace.App;
using PathSpace.Contracts;

namespace PathSpace.App.Tests;

public sealed class ResultViewModelTests
{
    [Fact]
    public void Result_paths_filter_case_insensitively_without_changing_source_order()
    {
        var snapshot = new ScanSnapshot(1,"scan.snapshot",@"C:\Data",true,false,30,2,0,
            [new StorageAggregate(@"C:\Data\Alpha",20,1,0),new StorageAggregate(@"C:\Data\Beta",10,1,0)],
            [new LargeFileEntry(@"C:\Data\Alpha\one.bin",20,DateTimeOffset.UnixEpoch),new LargeFileEntry(@"C:\Data\Beta\two.bin",10,DateTimeOffset.UnixEpoch)],[]);
        var results=ResultViewModel.FromSnapshot(snapshot);
        Assert.Equal(@"C:\Data\Beta",Assert.Single(results.FilterCategories("bEtA")).Path);
        Assert.Equal(@"C:\Data\Alpha\one.bin",Assert.Single(results.FilterLargeFiles("ALPHA")).Path);
        Assert.Equal(2,results.Categories.Count);
    }
    [Fact]
    public void Results_sort_categories_and_large_files_descending_by_bytes()
    {
        var snapshot = new ScanSnapshot(1, "scan.snapshot", @"C:\Data", true, false, 30, 2, 2,
            [new StorageAggregate("small", 10, 1, 1), new StorageAggregate("large", 20, 1, 1)],
            [new LargeFileEntry("small.bin", 10, DateTimeOffset.UtcNow), new LargeFileEntry("large.bin", 20, DateTimeOffset.UtcNow)],
            []);

        var result = ResultViewModel.FromSnapshot(snapshot);

        Assert.Equal("large", result.Categories[0].Path);
        Assert.Equal("large.bin", result.LargeFiles[0].Path);
        Assert.Equal("20 B", result.LargeFiles[0].DisplaySize);
    }

    [Fact]
    public void Advanced_diagnostics_are_hidden_by_default()
    {
        var viewModel = new MainViewModel(new UnusedEngineClient());
        Assert.False(viewModel.IsAdvancedMode);
        Assert.False(viewModel.ShowAdvancedDiagnostics);
        viewModel.IsAdvancedMode = true;
        Assert.True(viewModel.ShowAdvancedDiagnostics);
    }

    private sealed class UnusedEngineClient : IEngineClient
    {
        public Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken) => throw new NotSupportedException();
    }
}
