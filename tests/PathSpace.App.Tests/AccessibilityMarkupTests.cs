using System.Text.RegularExpressions;

namespace PathSpace.App.Tests;

public sealed class AccessibilityMarkupTests
{
    [Fact]
    public void Main_window_uses_system_colors_and_named_live_filter_controls()
    {
        var path=Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,"..","..","..","..","..","src","PathSpace.App","MainWindow.xaml"));
        var xaml=File.ReadAllText(path);
        Assert.DoesNotMatch(new Regex("#[0-9A-Fa-f]{6}"),xaml);
        Assert.Contains("SystemColors.GrayTextBrushKey",xaml);
        Assert.Contains("SystemColors.ActiveBorderBrushKey",xaml);
        Assert.Contains("AutomationProperties.LiveSetting=\"Polite\"",xaml);
        Assert.Contains("AutomationProperties.Name=\"Filter result paths\"",xaml);
        Assert.Contains("AutomationProperties.Name=\"Filter large-file paths\"",xaml);
    }
}
