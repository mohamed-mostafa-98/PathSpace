using System.Diagnostics;
using System.Text.Json;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.Tools;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;

namespace PathSpace.E2E.Tests;

[CollectionDefinition("Packaged GUI", DisableParallelization = true)]
public sealed class PackagedGuiCollection;

[Collection("Packaged GUI")]
public sealed class PackagedGuiWorkflowTests
{
    private static bool Enabled => Environment.GetEnvironmentVariable("PATHSPACE_RUN_PACKAGED_E2E") == "1";
    private static bool UacCancellationEnabled => Environment.GetEnvironmentVariable("PATHSPACE_RUN_UAC_CANCEL_E2E") == "1";

    [SkippableFact]
    public void Complete_scan_filter_export_preview_confirm_worker_and_verify()
    {
        Skip.IfNot(Enabled, "Set PATHSPACE_RUN_PACKAGED_E2E=1 and build the portable package first.");
        using var fixture = PackagedFixture.Create();
        File.WriteAllBytes(Path.Combine(fixture.NpmCache, "reclaimable.bin"), new byte[4096]);
        File.WriteAllText(Path.Combine(fixture.Root, "keep.txt"), "keep");

        using var session = GuiSession.Launch(fixture);
        session.SetTargetAndAnalyze(fixture.Root);
        session.WaitForText("StatusText", value => value.Contains("Analysis complete", StringComparison.Ordinal));

        session.SelectTab("CategoriesTab");
        session.TextBox("ResultFilter").Enter("npm-cache");
        Assert.NotNull(session.Window.FindFirstDescendant(value => value.ByName(fixture.NpmCache)));

        var exportPath = Path.Combine(fixture.Root, "report.json");
        session.SelectTab("SummaryTab");
        session.Button("ExportJsonButton").Click();
        session.CompleteSaveDialog(exportPath);
        using (var report = JsonDocument.Parse(File.ReadAllText(exportPath)))
            Assert.Equal("scan.snapshot", report.RootElement.GetProperty("kind").GetString());

        session.SelectTab("RecommendationsTab");
        var list = session.Element("RecommendationList").AsListBox();
        var recommendation = Retry.WhileNull(() => list.Items.FirstOrDefault(value => value.Name.Contains("Clear npm", StringComparison.OrdinalIgnoreCase)), TimeSpan.FromSeconds(10)).Result;
        Assert.NotNull(recommendation);
        recommendation!.Select();
        session.Button("PreviewActionButton").Invoke();
        session.WaitForText("ActionStatusText", value => value.Contains("Preview ready", StringComparison.Ordinal));
        session.Element("ConfirmActionCheckBox").AsCheckBox().IsChecked = true;
        session.Button("ExecuteActionButton").Invoke();
        session.WaitForText("ActionStatusText", value => value.Contains("Action completed", StringComparison.Ordinal));

        Assert.Empty(Directory.EnumerateFileSystemEntries(fixture.NpmCache));
        Assert.True(File.Exists(Path.Combine(fixture.Root, "keep.txt")));
        Assert.Contains(Directory.EnumerateFiles(fixture.Audit, "*.jsonl"), path => File.ReadAllText(path).Contains("action.execute", StringComparison.Ordinal));
    }

    [SkippableFact]
    public void Cancellation_produces_partial_read_only_results_without_cleanup()
    {
        Skip.IfNot(Enabled, "Set PATHSPACE_RUN_PACKAGED_E2E=1 and build the portable package first.");
        using var fixture = PackagedFixture.Create();
        for (var index = 0; index < 4000; index++)
        {
            var directory = Directory.CreateDirectory(Path.Combine(fixture.Root, "cancel", index.ToString("D4")));
            File.WriteAllText(Path.Combine(directory.FullName, "item.txt"), "fixture");
        }

        using var session = GuiSession.Launch(fixture);
        session.SetTargetAndAnalyze(fixture.Root);
        session.Button("CancelButton").Invoke();
        session.WaitForText("StatusText", value => value.Contains("Partial results are read-only", StringComparison.Ordinal), TimeSpan.FromSeconds(30));
        session.SelectTab("RecommendationsTab");
        Assert.False(session.Button("ExecuteActionButton").IsEnabled);
    }

    [SkippableFact]
    public void Keyboard_only_navigation_can_scan_filter_preview_confirm_and_execute()
    {
        Skip.IfNot(Enabled, "Set PATHSPACE_RUN_PACKAGED_E2E=1 and build the portable package first.");
        using var fixture = PackagedFixture.Create();
        File.WriteAllBytes(Path.Combine(fixture.NpmCache, "keyboard-data.bin"), new byte[4096]);

        using var session = GuiSession.Launch(fixture);
        session.Element("TargetPath").FocusNative();
        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
        Keyboard.Type(fixture.Root);
        Keyboard.Press(VirtualKeyShort.TAB);
        session.WaitForFocus("BrowseButton");
        Keyboard.Press(VirtualKeyShort.TAB);
        session.WaitForFocus("AnalyzeButton");
        Keyboard.Press(VirtualKeyShort.ENTER);
        session.WaitForText("StatusText", value => value.Contains("Analysis complete", StringComparison.Ordinal));

        session.Element("SummaryTab").FocusNative();
        Keyboard.Press(VirtualKeyShort.RIGHT);
        Assert.True(session.Element("CategoriesTab").AsTabItem().IsSelected);
        session.TabTo("ResultFilter");
        Keyboard.Type("npm-cache");
        Assert.NotNull(session.Window.FindFirstDescendant(value => value.ByName(fixture.NpmCache)));

        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.TAB);
        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.TAB);
        Assert.True(session.Element("RecommendationsTab").AsTabItem().IsSelected);
        session.TabToAny(ControlType.ListItem, ControlType.List);
        Keyboard.Press(VirtualKeyShort.HOME);
        session.TabTo("PreviewActionButton");
        Keyboard.Press(VirtualKeyShort.ENTER);
        session.WaitForText("ActionStatusText", value => value.Contains("Preview ready", StringComparison.Ordinal));
        session.TabTo("ConfirmActionCheckBox");
        Keyboard.TypeSimultaneously(VirtualKeyShort.ALT, VirtualKeyShort.KEY_I);
        Assert.True(Retry.WhileFalse(() => session.Element("ConfirmActionCheckBox").AsCheckBox().IsChecked == true, TimeSpan.FromSeconds(5)).Success);
        session.WaitForEnabled("ExecuteActionButton");
        session.TabTo("ExecuteActionButton");
        Keyboard.Press(VirtualKeyShort.ENTER);
        session.WaitForText("ActionStatusText", value => value.Contains("Action completed", StringComparison.Ordinal));

        Assert.Empty(Directory.EnumerateFileSystemEntries(fixture.NpmCache));
    }

    [SkippableFact]
    public void Packaged_controls_expose_screen_reader_names_roles_and_live_regions()
    {
        Skip.IfNot(Enabled, "Set PATHSPACE_RUN_PACKAGED_E2E=1 and build the portable package first.");
        using var fixture = PackagedFixture.Create();
        using var session = GuiSession.Launch(fixture);

        Assert.Equal(ControlType.Edit, session.Element("TargetPath").ControlType);
        Assert.Equal("Local drive or folder path", session.Element("TargetPath").Name);
        Assert.Equal(ControlType.Button, session.Element("AnalyzeButton").ControlType);
        Assert.Equal("Analyze", session.Element("AnalyzeButton").Name);
        Assert.Equal(LiveSetting.Polite, session.Element("StatusText").Properties.LiveSetting.Value);

        session.SelectTab("RecommendationsTab");
        Assert.Equal("Storage recovery recommendations", session.Element("RecommendationList").Name);
        Assert.Equal(LiveSetting.Polite, session.Element("ActionStatusText").Properties.LiveSetting.Value);

        session.SelectTab("AdvancedTab");
        var protectedDiagnostics = session.Element("ProtectedDiagnosticsButton");
        Assert.Equal(ControlType.Button, protectedDiagnostics.ControlType);
        Assert.Contains("administrator approval", protectedDiagnostics.HelpText, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("read-only", protectedDiagnostics.HelpText, StringComparison.OrdinalIgnoreCase);
    }

    [SkippableFact]
    public void Declining_protected_diagnostics_uac_leaves_the_app_running_and_records_cancellation()
    {
        Skip.IfNot(Enabled && UacCancellationEnabled, "Set PATHSPACE_RUN_PACKAGED_E2E=1 and PATHSPACE_RUN_UAC_CANCEL_E2E=1, then decline the UAC prompt.");
        using var fixture = PackagedFixture.Create();
        using var session = GuiSession.Launch(fixture);

        session.SelectTab("AdvancedTab");
        session.Button("ProtectedDiagnosticsButton").Invoke();
        session.WaitForText("StatusText", value => value.Contains("Administrator approval was cancelled", StringComparison.Ordinal), TimeSpan.FromSeconds(60));

        Assert.Contains(Directory.EnumerateFiles(fixture.Audit, "*.jsonl"), path => File.ReadAllText(path).Contains("diagnostics.protected", StringComparison.Ordinal) && File.ReadAllText(path).Contains("cancelled", StringComparison.Ordinal));
        Assert.True(session.IsWindowVisible());
    }
}

internal sealed class GuiSession : IDisposable
{
    private readonly Application _application;
    private readonly UIA3Automation _automation;
    public Window Window { get; }
    private GuiSession(Application application, UIA3Automation automation, Window window) => (_application, _automation, Window) = (application, automation, window);

    public static GuiSession Launch(PackagedFixture fixture)
    {
        var executable = Path.Combine(RepositoryRoot(), "artifacts", "PathSpace-win-x64", "PathSpace.App.exe");
        Assert.True(File.Exists(executable), $"Packaged application not found: {executable}");
        var startInfo = new ProcessStartInfo(executable) { WorkingDirectory = Path.GetDirectoryName(executable)! };
        startInfo.Environment["LOCALAPPDATA"] = fixture.Root;
        startInfo.Environment["PATHSPACE_AUDIT_DIRECTORY"] = fixture.Audit;
        var application = Application.Launch(startInfo);
        var automation = new UIA3Automation();
        var window = Retry.WhileNull(() => application.GetMainWindow(automation), TimeSpan.FromSeconds(15)).Result;
        Assert.NotNull(window);
        return new GuiSession(application, automation, window!);
    }

    public AutomationElement Element(string id) => Retry.WhileNull(() =>
        Window.FindFirstDescendant(value => value.ByAutomationId(id)) ??
        _application.GetMainWindow(_automation)?.FindFirstDescendant(value => value.ByAutomationId(id)), TimeSpan.FromSeconds(10)).Result ?? throw new InvalidOperationException($"UI element '{id}' was not found.");
    public bool IsWindowVisible() => !(_application.GetMainWindow(_automation)?.IsOffscreen ?? true);
    public Button Button(string id) => Element(id).AsButton();
    public TextBox TextBox(string id) => Element(id).AsTextBox();
    public void SelectTab(string id) => Element(id).AsTabItem().Select();
    public void SetTargetAndAnalyze(string path) { TextBox("TargetPath").Enter(path); Button("AnalyzeButton").Invoke(); }
    public void WaitForText(string id, Func<string, bool> predicate, TimeSpan? timeout = null)
    {
        var result = Retry.WhileFalse(() => predicate(Element(id).Name ?? string.Empty), timeout ?? TimeSpan.FromSeconds(45), TimeSpan.FromMilliseconds(200));
        Assert.True(result.Success, $"Timed out waiting for '{id}'. Last text: {Element(id).Name}");
    }
    public void WaitForFocus(string id)
    {
        var result = Retry.WhileFalse(() => _automation.FocusedElement()?.AutomationId == id, TimeSpan.FromSeconds(10), TimeSpan.FromMilliseconds(100));
        Assert.True(result.Success, $"Timed out waiting for keyboard focus on '{id}'. Focus was '{_automation.FocusedElement()?.AutomationId}'.");
    }
    public void WaitForEnabled(string id)
    {
        Assert.True(Retry.WhileFalse(() => Element(id).IsEnabled, TimeSpan.FromSeconds(10), TimeSpan.FromMilliseconds(100)).Success, $"Timed out waiting for '{id}' to become enabled.");
    }
    public void TabTo(string id, int maximumTabs = 30)
    {
        var visited = new List<string>();
        for (var index = 0; index < maximumTabs; index++)
        {
            var focused = _automation.FocusedElement();
            visited.Add($"{focused?.AutomationId}:{focused?.Name}:{focused?.ControlType}");
            if (focused?.AutomationId == id) return;
            Keyboard.Press(VirtualKeyShort.TAB);
            if (Retry.WhileFalse(() => _automation.FocusedElement()?.AutomationId == id, TimeSpan.FromMilliseconds(500), TimeSpan.FromMilliseconds(50)).Success) return;
        }
        throw new InvalidOperationException($"Keyboard traversal did not reach '{id}'. Visited: {string.Join(" -> ", visited)}");
    }
    public void TabToAny(params ControlType[] controlTypes)
    {
        for (var index = 0; index < 30; index++)
        {
            if (_automation.FocusedElement() is { } focused && controlTypes.Contains(focused.ControlType)) return;
            Keyboard.Press(VirtualKeyShort.TAB);
            Thread.Sleep(100);
        }
        throw new InvalidOperationException($"Keyboard traversal did not reach any of: {string.Join(", ", controlTypes)}.");
    }
    public void CompleteSaveDialog(string path)
    {
        Thread.Sleep(750);
        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
        Keyboard.Type(path);
        Keyboard.Press(VirtualKeyShort.ENTER);
        Assert.True(Retry.WhileFalse(() => File.Exists(path), TimeSpan.FromSeconds(10)).Success);
    }
    public void Dispose()
    {
        try { if (!_application.HasExited) _application.Close(); } catch { if (!_application.HasExited) _application.Kill(); }
        _automation.Dispose();
        _application.Dispose();
    }
    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null) { if (File.Exists(Path.Combine(directory.FullName, "PathSpace.sln"))) return directory.FullName; directory = directory.Parent; }
        throw new DirectoryNotFoundException("PathSpace repository root was not found.");
    }
}

internal sealed class PackagedFixture : IDisposable
{
    public string Root { get; }
    public string NpmCache => Path.Combine(Root, "npm-cache");
    public string Audit => Path.Combine(Root, "PathSpace", "Audit");
    private PackagedFixture(string root) { Root = root; Directory.CreateDirectory(NpmCache); }
    public static PackagedFixture Create() => new(Path.Combine(Path.GetTempPath(), $"pathspace-e2e-{Guid.NewGuid():N}"));
    public void Dispose() { if (Directory.Exists(Root)) Directory.Delete(Root, true); }
}
