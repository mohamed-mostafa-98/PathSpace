using PathSpace.Contracts;

namespace PathSpace.App;

public interface IActionExecutor { Task<ActionResult> ExecuteAsync(ActionPreview preview, CancellationToken cancellationToken); }
public interface IActionVerifier { Task<ScanSnapshot?> VerifyAsync(ActionPreview preview, CancellationToken cancellationToken); }
public sealed record VerifiedActionOutcome(string Status, ActionResult Result, ScanSnapshot? Verification, long? MeasuredRecoveredBytes);

public sealed class ActionCoordinator(IActionExecutor executor, IActionVerifier verifier)
{
    public async Task<VerifiedActionOutcome> ExecuteAsync(ActionPreview preview, CancellationToken cancellationToken)
    {
        var result = await executor.ExecuteAsync(preview, cancellationToken);
        var verification = await verifier.VerifyAsync(preview, cancellationToken);
        if (verification is null || !verification.Complete)
            return new VerifiedActionOutcome("unverified", result, verification, null);
        return new VerifiedActionOutcome(result.Status, result, verification, result.RecoveredBytes);
    }
}
