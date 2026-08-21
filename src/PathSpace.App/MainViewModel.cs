using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.IO;
using PathSpace.Contracts;

namespace PathSpace.App;

public sealed class MainViewModel : INotifyPropertyChanged
{
    private readonly IEngineClient _engineClient;
    private CancellationTokenSource? _scanCancellation;
    private string _targetPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    private bool _isScanning;
    private string _status = "Choose a local drive or folder to analyze.";
    private ScanProgress? _progress;
    private ScanSnapshot? _snapshot;
    private ResultViewModel? _results;
    private bool _isAdvancedMode;
    private IReadOnlyList<Recommendation> _recommendations = [];
    private IReadOnlyList<AppDiagnostic> _diagnostics = [];
    private Recommendation? _selectedRecommendation;
    private ActionPreview? _currentPreview;
    private bool _hasConfirmedPreview;
    private bool _isExecutingAction;
    private string _actionStatus = "Select an actionable recommendation to preview it.";
    private readonly ActionCoordinator _actionCoordinator;
    private readonly IAuditLog _auditLog;
    private string _resultFilter = string.Empty;

    public MainViewModel() : this(new EngineClient()) { }
    public MainViewModel(IEngineClient engineClient, ActionCoordinator? actionCoordinator = null, IAuditLog? auditLog = null)
    {
        _engineClient = engineClient;
        _actionCoordinator = actionCoordinator ?? new ActionCoordinator(new WorkerActionExecutor(), new EngineActionVerifier(engineClient));
        _auditLog = auditLog ?? new LocalAuditLog(Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PathSpace", "Audit"));
        AnalyzeCommand = new RelayCommand(() => _ = AnalyzeAsync(), () => !IsScanning && !string.IsNullOrWhiteSpace(TargetPath));
        CancelCommand = new RelayCommand(Cancel, () => IsScanning);
        PreviewActionCommand = new RelayCommand(() => _ = PreviewSelectedAsync(), () => SelectedRecommendation?.Actionable == true && !IsScanning && !IsExecutingAction);
        ExecuteActionCommand = new RelayCommand(() => _ = ExecutePreviewAsync(), () => CurrentPreview is not null && HasConfirmedPreview && Snapshot?.Complete == true && !IsScanning && !IsExecutingAction);
        ProtectedDiagnosticsCommand = new RelayCommand(() => _ = RunProtectedDiagnosticsAsync(), () => !IsScanning && !IsExecutingAction);
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public RelayCommand AnalyzeCommand { get; }
    public RelayCommand CancelCommand { get; }
    public RelayCommand PreviewActionCommand { get; }
    public RelayCommand ExecuteActionCommand { get; }
    public RelayCommand ProtectedDiagnosticsCommand { get; }
    public IReadOnlyList<string> AvailableDrives { get; } = DriveInfo.GetDrives()
        .Where(value => value.DriveType is DriveType.Fixed or DriveType.Removable)
        .Select(value => value.RootDirectory.FullName).ToArray();
    public string TargetPath { get => _targetPath; set { if (SetField(ref _targetPath, value)) AnalyzeCommand.RaiseCanExecuteChanged(); } }
    public bool IsScanning
    {
        get => _isScanning;
        private set
        {
            if (!SetField(ref _isScanning, value)) return;
            AnalyzeCommand.RaiseCanExecuteChanged();
            CancelCommand.RaiseCanExecuteChanged();
            PreviewActionCommand.RaiseCanExecuteChanged();
            ExecuteActionCommand.RaiseCanExecuteChanged();
            ProtectedDiagnosticsCommand.RaiseCanExecuteChanged();
        }
    }
    public string Status { get => _status; private set => SetField(ref _status, value); }
    public ScanProgress? Progress { get => _progress; private set => SetField(ref _progress, value); }
    public ScanSnapshot? Snapshot { get => _snapshot; private set => SetField(ref _snapshot, value); }
    public ResultViewModel? Results
    {
        get => _results;
        private set
        {
            if(!SetField(ref _results,value)) return;
            PropertyChanged?.Invoke(this,new PropertyChangedEventArgs(nameof(FilteredCategories)));
            PropertyChanged?.Invoke(this,new PropertyChangedEventArgs(nameof(FilteredLargeFiles)));
        }
    }
    public string ResultFilter
    {
        get => _resultFilter;
        set
        {
            if(!SetField(ref _resultFilter,value)) return;
            PropertyChanged?.Invoke(this,new PropertyChangedEventArgs(nameof(FilteredCategories)));
            PropertyChanged?.Invoke(this,new PropertyChangedEventArgs(nameof(FilteredLargeFiles)));
        }
    }
    public IReadOnlyList<StorageRow> FilteredCategories => Results?.FilterCategories(ResultFilter) ?? [];
    public IReadOnlyList<LargeFileRow> FilteredLargeFiles => Results?.FilterLargeFiles(ResultFilter) ?? [];
    public bool IsAdvancedMode
    {
        get => _isAdvancedMode;
        set
        {
            if (!SetField(ref _isAdvancedMode, value)) return;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(ShowAdvancedDiagnostics)));
        }
    }
    public bool ShowAdvancedDiagnostics => IsAdvancedMode;
    public IReadOnlyList<Recommendation> Recommendations { get => _recommendations; private set => SetField(ref _recommendations, value); }
    public IReadOnlyList<AppDiagnostic> Diagnostics { get => _diagnostics; private set => SetField(ref _diagnostics, value); }
    public Recommendation? SelectedRecommendation
    {
        get => _selectedRecommendation;
        set
        {
            if(!SetField(ref _selectedRecommendation,value)) return;
            CurrentPreview=null; HasConfirmedPreview=false;
            PreviewActionCommand.RaiseCanExecuteChanged(); ExecuteActionCommand.RaiseCanExecuteChanged();
        }
    }
    public ActionPreview? CurrentPreview { get => _currentPreview; private set { if(SetField(ref _currentPreview,value)) ExecuteActionCommand.RaiseCanExecuteChanged(); } }
    public bool HasConfirmedPreview { get => _hasConfirmedPreview; set { if(SetField(ref _hasConfirmedPreview,value)) ExecuteActionCommand.RaiseCanExecuteChanged(); } }
    public bool IsExecutingAction { get => _isExecutingAction; private set { if(SetField(ref _isExecutingAction,value)){PreviewActionCommand.RaiseCanExecuteChanged();ExecuteActionCommand.RaiseCanExecuteChanged();ProtectedDiagnosticsCommand.RaiseCanExecuteChanged();} } }
    public string ActionStatus { get => _actionStatus; private set => SetField(ref _actionStatus,value); }

    public async Task AnalyzeAsync()
    {
        if (IsScanning || string.IsNullOrWhiteSpace(TargetPath)) return;
        _scanCancellation = new CancellationTokenSource();
        IsScanning = true;
        Snapshot = null;
        Results = null;
        Recommendations = [];
        Diagnostics = [];
        Progress = null;
        Status = "Analyzing local storage…";
        _auditLog.Record("scan", "started", new { targetType = Path.GetPathRoot(TargetPath) == TargetPath ? "drive" : "folder" });
        try
        {
            var progress = new Progress<ScanProgress>(value => { Progress = value; Status = $"Analyzing {value.CurrentPath}"; });
            Snapshot = await _engineClient.ScanAsync(TargetPath, progress, _scanCancellation.Token);
            Results = ResultViewModel.FromSnapshot(Snapshot);
            var optionalWarnings = new List<string>();
            try { Diagnostics = await _engineClient.DiagnoseAsync(_scanCancellation.Token); }
            catch (Exception exception) { Diagnostics = []; optionalWarnings.Add($"guided diagnostics unavailable: {exception.Message}"); }
            try { Recommendations = await _engineClient.RecommendAsync(Snapshot, Diagnostics, _scanCancellation.Token); }
            catch (Exception exception) { Recommendations = []; optionalWarnings.Add($"recommendations unavailable: {exception.Message}"); }
            var finalStatus = Snapshot.Complete ? $"Analysis complete: {Snapshot.FileCount:N0} files measured." : "Analysis cancelled. Partial results are read-only.";
            Status = optionalWarnings.Count == 0 ? finalStatus : $"{finalStatus} {string.Join("; ", optionalWarnings)}";
            _auditLog.Record("scan", Snapshot.Complete ? "completed" : "cancelled", new
            {
                Snapshot.LogicalBytes,
                Snapshot.FileCount,
                Snapshot.DirectoryCount,
                warningCount = Snapshot.Warnings.Count
            });
        }
        catch (Exception exception) { Status = $"Analysis failed: {exception.Message}"; _auditLog.Record("scan", "failed", new { errorType = exception.GetType().Name }); }
        finally
        {
            IsScanning = false;
            _scanCancellation.Dispose();
            _scanCancellation = null;
        }
    }

    private void Cancel() { Status = "Cancelling safely…"; _scanCancellation?.Cancel(); }
    public async Task PreviewSelectedAsync()
    {
        if(SelectedRecommendation?.Actionable != true) return;
        try
        {
            ActionStatus="Building an exact, read-only preview…";
            CurrentPreview=await _engineClient.PreviewAsync(SelectedRecommendation.Id, null, CancellationToken.None);
            HasConfirmedPreview=false;
            ActionStatus=$"Preview ready: {CurrentPreview.Targets.Count} target(s), up to {CurrentPreview.EstimatedBytes:N0} measured bytes.";
            _auditLog.Record("action.preview", "completed", new { CurrentPreview.ActionId, targetCount = CurrentPreview.Targets.Count, CurrentPreview.EstimatedBytes, CurrentPreview.RequiresElevation });
        }
        catch(Exception exception){CurrentPreview=null;ActionStatus=$"Preview unavailable: {exception.Message}";_auditLog.Record("action.preview", "failed", new { actionId = SelectedRecommendation?.Id, errorType = exception.GetType().Name });}
    }
    public async Task ExecutePreviewAsync()
    {
        if(CurrentPreview is null || !HasConfirmedPreview || Snapshot?.Complete != true) return;
        IsExecutingAction=true;
        try
        {
            ActionStatus="Executing the confirmed preview…";
            var outcome=await _actionCoordinator.ExecuteAsync(CurrentPreview,CancellationToken.None);
            ActionStatus=outcome.Status=="unverified"
                ? "Action finished, but recovery could not be verified; no success claim was recorded."
                : $"Action {outcome.Status}. Measured recovery: {outcome.MeasuredRecoveredBytes.GetValueOrDefault():N0} bytes.";
            HasConfirmedPreview=false;
            _auditLog.Record("action.execute", outcome.Status, new { CurrentPreview.ActionId, outcome.Result.TargetsProcessed, outcome.Result.TargetsSkipped, outcome.MeasuredRecoveredBytes });
        }
        catch(Exception exception){ActionStatus=$"Action failed safely: {exception.Message}";_auditLog.Record("action.execute", "failed", new { actionId = CurrentPreview.ActionId, errorType = exception.GetType().Name });}
        finally{IsExecutingAction=false;}
    }
    public async Task RunProtectedDiagnosticsAsync()
    {
        try
        {
            Status="Requesting administrator approval for a read-only protected scan…";
            Diagnostics=await _engineClient.DiagnoseProtectedAsync(CancellationToken.None);
            if(Snapshot?.Complete==true) Recommendations=await _engineClient.RecommendAsync(Snapshot,Diagnostics,CancellationToken.None);
            Status="Protected diagnostics complete. No cleanup action was performed.";
            _auditLog.Record("diagnostics.protected", "completed", new { diagnosticCount = Diagnostics.Count });
        }
        catch(OperationCanceledException exception){Status=exception.Message;_auditLog.Record("diagnostics.protected", "cancelled");}
        catch(Exception exception){Status=$"Protected diagnostics failed safely: {exception.Message}";_auditLog.Record("diagnostics.protected", "failed", new { errorType = exception.GetType().Name });}
    }
    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }
}
