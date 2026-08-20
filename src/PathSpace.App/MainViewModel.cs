using System.ComponentModel;
using System.Runtime.CompilerServices;
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

    public MainViewModel() : this(new EngineClient()) { }
    public MainViewModel(IEngineClient engineClient)
    {
        _engineClient = engineClient;
        AnalyzeCommand = new RelayCommand(() => _ = AnalyzeAsync(), () => !IsScanning && !string.IsNullOrWhiteSpace(TargetPath));
        CancelCommand = new RelayCommand(Cancel, () => IsScanning);
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public RelayCommand AnalyzeCommand { get; }
    public RelayCommand CancelCommand { get; }
    public string TargetPath { get => _targetPath; set { if (SetField(ref _targetPath, value)) AnalyzeCommand.RaiseCanExecuteChanged(); } }
    public bool IsScanning
    {
        get => _isScanning;
        private set
        {
            if (!SetField(ref _isScanning, value)) return;
            AnalyzeCommand.RaiseCanExecuteChanged();
            CancelCommand.RaiseCanExecuteChanged();
        }
    }
    public string Status { get => _status; private set => SetField(ref _status, value); }
    public ScanProgress? Progress { get => _progress; private set => SetField(ref _progress, value); }
    public ScanSnapshot? Snapshot { get => _snapshot; private set => SetField(ref _snapshot, value); }
    public ResultViewModel? Results { get => _results; private set => SetField(ref _results, value); }
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

    public async Task AnalyzeAsync()
    {
        if (IsScanning || string.IsNullOrWhiteSpace(TargetPath)) return;
        _scanCancellation = new CancellationTokenSource();
        IsScanning = true;
        Snapshot = null;
        Results = null;
        Progress = null;
        Status = "Analyzing local storage…";
        try
        {
            var progress = new Progress<ScanProgress>(value => { Progress = value; Status = $"Analyzing {value.CurrentPath}"; });
            Snapshot = await _engineClient.ScanAsync(TargetPath, progress, _scanCancellation.Token);
            Results = ResultViewModel.FromSnapshot(Snapshot);
            Status = Snapshot.Complete ? $"Analysis complete: {Snapshot.FileCount:N0} files measured." : "Analysis cancelled. Partial results are read-only.";
        }
        catch (Exception exception) { Status = $"Analysis failed: {exception.Message}"; }
        finally
        {
            IsScanning = false;
            _scanCancellation.Dispose();
            _scanCancellation = null;
        }
    }

    private void Cancel() { Status = "Cancelling safely…"; _scanCancellation?.Cancel(); }
    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }
}
