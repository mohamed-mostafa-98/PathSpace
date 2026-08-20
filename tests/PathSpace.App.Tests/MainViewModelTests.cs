using PathSpace.App;
using PathSpace.Contracts;

namespace PathSpace.App.Tests;

public sealed class MainViewModelTests
{
    [Fact]
    public async Task Scan_state_disables_analyze_and_enables_cancel_until_complete()
    {
        var completion = new TaskCompletionSource<ScanSnapshot>();
        var viewModel = new MainViewModel(new StubEngineClient(completion.Task)) { TargetPath = @"C:\Data" };

        var scan = viewModel.AnalyzeAsync();
        Assert.True(viewModel.IsScanning);
        Assert.False(viewModel.AnalyzeCommand.CanExecute(null));
        Assert.True(viewModel.CancelCommand.CanExecute(null));

        completion.SetResult(new ScanSnapshot(1, "scan.snapshot", @"C:\Data", true, false, 1, 1, 0, [], [], []));
        await scan;

        Assert.False(viewModel.IsScanning);
        Assert.True(viewModel.AnalyzeCommand.CanExecute(null));
        Assert.False(viewModel.CancelCommand.CanExecute(null));
    }

    [Fact]
    public async Task Cancelled_snapshot_is_labeled_partial_and_read_only()
    {
        var engine = new CancellingEngineClient();
        var viewModel = new MainViewModel(engine) { TargetPath = @"C:\Data" };
        var scan = viewModel.AnalyzeAsync();

        viewModel.CancelCommand.Execute(null);
        await scan;

        Assert.False(viewModel.Snapshot!.Complete);
        Assert.Contains("Partial results are read-only", viewModel.Status);
    }

    [Fact]
    public async Task Engine_failure_is_reported_and_a_retry_remains_available()
    {
        var viewModel = new MainViewModel(new FailingEngineClient()) { TargetPath = @"C:\Data" };

        await viewModel.AnalyzeAsync();

        Assert.Contains("Analysis failed", viewModel.Status);
        Assert.True(viewModel.AnalyzeCommand.CanExecute(null));
    }

    private sealed class StubEngineClient(Task<ScanSnapshot> result) : IEngineClient
    {
        public Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken) => result;
    }

    private sealed class CancellingEngineClient : IEngineClient
    {
        public async Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested) await Task.Yield();
            return new ScanSnapshot(1, "scan.snapshot", target, false, true, 0, 0, 0, [], [], []);
        }
    }

    private sealed class FailingEngineClient : IEngineClient
    {
        public Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken cancellationToken) =>
            Task.FromException<ScanSnapshot>(new InvalidOperationException("fixture failure"));
    }
}
