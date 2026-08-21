using System.Text;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace PathSpace.App;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();
    }

    private void BrowseButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.OpenFolderDialog { Title = "Choose a local folder to analyze", Multiselect = false };
        if (dialog.ShowDialog(this) == true && DataContext is MainViewModel viewModel) viewModel.TargetPath = dialog.FolderName;
    }

    private void ExportJsonButton_Click(object sender, RoutedEventArgs e) => Export("json", false);
    private void ExportRedactedButton_Click(object sender, RoutedEventArgs e) => Export("json", true);
    private void ExportCsvButton_Click(object sender, RoutedEventArgs e) => Export("csv", false);

    private void Export(string format, bool redacted)
    {
        if (DataContext is not MainViewModel { Snapshot: { } snapshot })
        {
            MessageBox.Show(this, "Complete an analysis before exporting.", "PathSpace", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Title = "Export PathSpace report",
            Filter = format == "csv" ? "CSV report (*.csv)|*.csv" : "JSON report (*.json)|*.json",
            FileName = redacted ? "pathspace-report-redacted.json" : $"pathspace-report.{format}"
        };
        if (dialog.ShowDialog(this) != true) return;
        var content = format == "csv" ? ReportExporter.ExportCsv(snapshot) : redacted
            ? ReportExporter.ExportRedactedJson(snapshot, Environment.GetFolderPath(Environment.SpecialFolder.UserProfile))
            : ReportExporter.ExportJson(snapshot);
        File.WriteAllText(dialog.FileName, content);
    }
}
