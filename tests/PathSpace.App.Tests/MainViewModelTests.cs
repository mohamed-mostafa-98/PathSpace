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

    [Fact]
    public async Task Action_requires_preview_and_explicit_confirmation_before_execution()
    {
        var engine = new PreviewEngineClient();
        var executor = new RecordingExecutor();
        var coordinator = new ActionCoordinator(executor, new MissingActionVerifier());
        var viewModel = new MainViewModel(engine, coordinator);
        viewModel.SelectedRecommendation = new Recommendation(1, "recommendation", "temp.user", "Temp", "Review", [], 0, 10, RecoveryRisk.Low, Reversibility.Reversible, false, 1, true);

        await viewModel.PreviewSelectedAsync();
        Assert.NotNull(viewModel.CurrentPreview);
        Assert.False(viewModel.ExecuteActionCommand.CanExecute(null));

        viewModel.HasConfirmedPreview = true;
        Assert.False(viewModel.ExecuteActionCommand.CanExecute(null)); // a complete scan is also required
        Assert.Equal(0, executor.Calls);
    }

    [Fact]
    public async Task Protected_diagnostics_are_user_initiated_and_read_only()
    {
        var viewModel = new MainViewModel(new ProtectedDiagnosticEngine());
        await viewModel.RunProtectedDiagnosticsAsync();
        Assert.Single(viewModel.Diagnostics);
        Assert.Contains("No cleanup action was performed", viewModel.Status);
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
    private sealed class PreviewEngineClient : IEngineClient
    {
        public Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken token) => throw new NotSupportedException();
        public Task<ActionPreview> PreviewAsync(string actionId, string? driveLetter, CancellationToken token) =>
            Task.FromResult(new ActionPreview(1, "action.preview", actionId, "Temp", [new ActionTarget("temp", @"C:\Temp", false)], 10, RecoveryRisk.Low, Reversibility.Reversible, false));
    }
    private sealed class ProtectedDiagnosticEngine : IEngineClient
    {
        public Task<ScanSnapshot> ScanAsync(string target, IProgress<ScanProgress> progress, CancellationToken token) => throw new NotSupportedException();
        public Task<IReadOnlyList<AppDiagnostic>> DiagnoseProtectedAsync(CancellationToken token) =>
            Task.FromResult<IReadOnlyList<AppDiagnostic>>([new AppDiagnostic(1,"app.diagnostic","pagefile",true,default,"fixture")]);
    }
    private sealed class RecordingExecutor : IActionExecutor
    {
        public int Calls { get; private set; }
        public Task<ActionResult> ExecuteAsync(ActionPreview preview, CancellationToken token) { Calls++; return Task.FromResult(new ActionResult(1,"action.result",preview.ActionId,"completed",0,1,0,[])); }
    }
    private sealed class MissingActionVerifier : IActionVerifier
    {
        public Task<ScanSnapshot?> VerifyAsync(ActionPreview preview, CancellationToken token) => Task.FromResult<ScanSnapshot?>(null);
    }
}
