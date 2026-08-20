using PathSpace.App;
using PathSpace.Contracts;

namespace PathSpace.App.Tests;

public sealed class ActionCoordinatorTests
{
    [Fact]
    public async Task Successful_execution_without_verification_is_unverified()
    {
        var preview = new ActionPreview(1, "action.preview", "temp.user", "Temp", [], 100, RecoveryRisk.Low, Reversibility.Reversible, false);
        var coordinator = new ActionCoordinator(new Executor(), new MissingVerifier());
        var outcome = await coordinator.ExecuteAsync(preview, CancellationToken.None);
        Assert.Equal("unverified", outcome.Status);
        Assert.Null(outcome.MeasuredRecoveredBytes);
    }
    private sealed class Executor : IActionExecutor
    {
        public Task<ActionResult> ExecuteAsync(ActionPreview preview, CancellationToken token) => Task.FromResult(new ActionResult(1, "action.result", preview.ActionId, "completed", 100, 1, 0, []));
    }
    private sealed class MissingVerifier : IActionVerifier
    {
        public Task<ScanSnapshot?> VerifyAsync(ActionPreview preview, CancellationToken token) => Task.FromResult<ScanSnapshot?>(null);
    }
}
